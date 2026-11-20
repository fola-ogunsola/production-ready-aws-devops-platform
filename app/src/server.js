import 'dotenv/config';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { ZodError } from 'zod';
import { createApp } from './app.js';
import { loadConfig } from './config/env.js';
import { createLogger } from './config/logger.js';
import { createDatabasePool } from './db/pool.js';
import { createPostgresTaskRepository } from './repositories/postgres-task.repository.js';
import { createPostgresUserRepository } from './repositories/postgres-user.repository.js';
import { createAuthService } from './services/auth.service.js';

export async function startServer({
  config = loadConfig(),
  logger,
  registerSignalHandlers = true,
  pool: suppliedPool,
  taskRepository: suppliedTaskRepository,
  userRepository: suppliedUserRepository,
  authService: suppliedAuthService,
} = {}) {
  const activeLogger = logger ?? createLogger(config);
  const pool = suppliedPool ?? createDatabasePool(config.database);
  pool.on?.('error', (error) => {
    activeLogger.error(
      { errorName: error instanceof Error ? error.name : 'UnknownError' },
      'Idle database client error',
    );
  });

  let userRepository;
  let taskRepository;
  let authService;
  try {
    userRepository = suppliedUserRepository ?? createPostgresUserRepository(pool);
    taskRepository = suppliedTaskRepository ?? createPostgresTaskRepository(pool);
    authService =
      suppliedAuthService ?? (await createAuthService({ userRepository, jwt: config.jwt }));
  } catch (error) {
    await pool.end();
    throw error;
  }
  let shuttingDown = false;
  const app = createApp({
    config,
    logger: activeLogger,
    userRepository,
    taskRepository,
    authService,
    isReady: async () => {
      if (shuttingDown) {
        return false;
      }
      await pool.query({
        text: 'SELECT 1',
        query_timeout: config.database.queryTimeoutMillis,
        statement_timeout: config.database.queryTimeoutMillis,
      });
      return true;
    },
  });
  const server = createServer(app);

  server.headersTimeout = 10_000;
  server.requestTimeout = 30_000;
  server.keepAliveTimeout = 5_000;
  server.timeout = 30_000;

  try {
    await new Promise((resolveListen, rejectListen) => {
      const onError = (error) => {
        server.off('listening', onListening);
        rejectListen(error);
      };
      const onListening = () => {
        server.off('error', onError);
        resolveListen();
      };

      server.once('error', onError);
      server.once('listening', onListening);
      server.listen(config.port, config.host);
    });
  } catch (error) {
    await pool.end();
    throw error;
  }

  const address = server.address();
  activeLogger.info(
    {
      host: config.host,
      port: typeof address === 'object' && address ? address.port : config.port,
      nodeEnv: config.nodeEnv,
    },
    'HTTP server listening',
  );

  let shutdownPromise;
  const signalHandlers = new Map();

  const shutdown = (signal = 'manual') => {
    if (shutdownPromise) {
      return shutdownPromise;
    }

    shuttingDown = true;
    activeLogger.info({ signal }, 'Graceful shutdown started');
    shutdownPromise = new Promise((resolveShutdown) => {
      const shutdownTimer = setTimeout(() => {
        activeLogger.error(
          { timeoutMs: config.shutdownTimeoutMs },
          'Graceful shutdown timed out; closing active connections',
        );
        server.closeAllConnections();
        void pool.end().catch((poolError) => {
          activeLogger.error(
            { errorName: poolError instanceof Error ? poolError.name : 'UnknownError' },
            'Database pool close failed after shutdown timeout',
          );
        });
        process.exit(1);
      }, config.shutdownTimeoutMs);
      shutdownTimer.unref();

      server.close(async (error) => {
        for (const [registeredSignal, handler] of signalHandlers) {
          process.off(registeredSignal, handler);
        }

        if (error) {
          process.exitCode = 1;
          activeLogger.error({ errorName: error.name }, 'HTTP server close failed');
        } else {
          activeLogger.info('HTTP server closed');
        }

        try {
          await pool.end();
        } catch (poolError) {
          process.exitCode = 1;
          activeLogger.error(
            { errorName: poolError instanceof Error ? poolError.name : 'UnknownError' },
            'Database pool close failed',
          );
        } finally {
          clearTimeout(shutdownTimer);
          resolveShutdown();
        }
      });
    });

    return shutdownPromise;
  };

  if (registerSignalHandlers) {
    for (const signal of ['SIGTERM', 'SIGINT']) {
      const handler = () => {
        void shutdown(signal);
      };
      signalHandlers.set(signal, handler);
      process.once(signal, handler);
    }
  }

  return { app, server, shutdown };
}

async function main() {
  let logger;
  try {
    const config = loadConfig();
    logger = createLogger(config);
    await startServer({ config, logger });
  } catch (error) {
    const issues =
      error instanceof ZodError
        ? error.issues.map((issue) => ({
            path: issue.path.join('.'),
            message: issue.message,
          }))
        : undefined;

    if (logger) {
      logger.fatal({ issues, errorName: error instanceof Error ? error.name : 'UnknownError' }, 'Application startup failed');
    } else {
      console.error(JSON.stringify({ level: 'fatal', message: 'Invalid application configuration', issues }));
    }
    process.exitCode = 1;
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  void main();
}
