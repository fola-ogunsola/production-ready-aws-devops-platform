import cors from 'cors';
import express from 'express';
import { rateLimit } from 'express-rate-limit';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import { createLogger } from './config/logger.js';
import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { requestId } from './middleware/request-id.js';
import { createHealthRouter } from './routes/health.routes.js';
import { getApplicationInfo } from './controllers/info.controller.js';
import { createTaskRouter } from './routes/task.routes.js';
import { createAuthenticationMiddleware } from './middleware/authenticate.js';
import { createAuthRouter } from './routes/auth.routes.js';
import { createTaskService } from './services/task.service.js';
import { AppError, sendError } from './utils/errors.js';

function createCorsOptions(allowedOrigins) {
  return {
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new AppError(403, 'origin_not_allowed', 'Origin is not allowed'));
    },
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'X-Request-Id'],
    exposedHeaders: ['X-Request-Id'],
    credentials: false,
    maxAge: 600,
  };
}

export function createApp(options = {}) {
  const {
    config,
    taskRepository,
    userRepository,
    authService,
    isReady = () => true,
  } = options;
  if (!config) {
    throw new TypeError('Application configuration is required');
  }
  if (!taskRepository || !userRepository || !authService) {
    throw new TypeError('Task repository, user repository, and authentication service are required');
  }
  const logger = options.logger ?? createLogger(config);

  const app = express();
  const taskService = createTaskService(taskRepository);
  const authenticate = createAuthenticationMiddleware({
    jwt: config.jwt,
    userRepository,
  });

  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxyHops);
  app.use(helmet());
  app.use(requestId);
  app.use(
    pinoHttp({
      logger,
      genReqId: (request) => request.id,
      customProps: (request) => ({ requestId: request.id }),
      customLogLevel(_request, response, error) {
        if (error || response.statusCode >= 500) {
          return 'error';
        }
        if (response.statusCode >= 400) {
          return 'warn';
        }
        return 'info';
      },
      wrapSerializers: false,
      serializers: {
        req(request) {
          return {
            id: request.id,
            method: request.method,
            path: request.path,
          };
        },
        res(response) {
          return { statusCode: response.statusCode };
        },
      },
    }),
  );
  app.use(cors(createCorsOptions(config.corsOrigins)));
  app.use(express.json({ limit: '16kb', strict: true }));

  app.use('/health', createHealthRouter(isReady));
  const apiRateLimiter = rateLimit({
    windowMs: config.rateLimitWindowMs,
    limit: config.rateLimitMax,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler(request, response) {
      response.setHeader('Retry-After', String(Math.ceil(config.rateLimitWindowMs / 1000)));
      sendError(response, request.id, {
        status: 429,
        code: 'rate_limit_exceeded',
        message: 'Too many requests; try again later',
      });
    },
  });
  app.use('/api/v1', apiRateLimiter);
  app.use('/api/v1/auth', createAuthRouter({ config, authService, userRepository }));
  app.get('/api/v1/info', getApplicationInfo);
  app.all('/api/v1/info', (_request, response, next) => {
    response.setHeader('Allow', 'GET');
    next(new AppError(405, 'method_not_allowed', 'Method not allowed'));
  });
  app.use('/api/v1/tasks', createTaskRouter({ service: taskService, authenticate }));
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
