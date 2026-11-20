import 'dotenv/config';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { ZodError } from 'zod';
import { loadDatabaseConfig } from '../config/env.js';
import { createLogger } from '../config/logger.js';
import { createDatabasePool } from './pool.js';
import { runMigrations } from '../migrations/migrate.js';

async function main() {
  let pool;
  try {
    const databaseConfig = loadDatabaseConfig();
    const logger = createLogger({ logLevel: process.env.LOG_LEVEL ?? 'info' });
    pool = createDatabasePool(databaseConfig);
    await runMigrations(pool, logger);
    logger.info('Database migrations are up to date');
  } catch (error) {
    const issues =
      error instanceof ZodError
        ? error.issues.map((issue) => ({
            path: issue.path.join('.'),
            message: issue.message,
          }))
        : undefined;
    console.error(
      JSON.stringify({
        level: 'error',
        message: 'Database migration failed',
        issues,
        errorName: error instanceof Error ? error.name : 'UnknownError',
      }),
    );
    process.exitCode = 1;
  } finally {
    await pool?.end();
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  await main();
}
