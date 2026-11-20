import { z } from 'zod';

const databaseSchema = z.object({
  DATABASE_HOST: z.string().min(1),
  DATABASE_PORT: z.coerce.number().int().min(1).max(65535).default(5432),
  DATABASE_NAME: z.string().regex(/^[A-Za-z0-9_]+$/),
  DATABASE_USER: z.string().min(1),
  DATABASE_PASSWORD: z.string().min(16),
  DATABASE_POOL_MAX: z.coerce.number().int().min(1).max(50).default(10),
  DATABASE_IDLE_TIMEOUT_MS: z.coerce.number().int().min(1000).max(300000).default(30000),
  DATABASE_CONNECTION_TIMEOUT_MS: z.coerce.number().int().min(100).max(30000).default(3000),
  DATABASE_QUERY_TIMEOUT_MS: z.coerce.number().int().min(100).max(30000).default(5000),
});

const applicationSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().min(1).default('0.0.0.0'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
    .default('info'),
  CORS_ORIGINS: z
    .string()
    .default('')
    .transform((value) => value.split(',').map((origin) => origin.trim()).filter(Boolean))
    .refine(
      (origins) =>
        origins.every((origin) => {
          try {
            const parsed = new URL(origin);
            return (
              ['http:', 'https:'].includes(parsed.protocol) &&
              parsed.origin === origin &&
              !parsed.username &&
              !parsed.password
            );
          } catch {
            return false;
          }
        }),
      { message: 'must be a comma-separated list of HTTP or HTTPS origins' },
    ),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().int().min(1).max(3600000).default(60000),
  RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(100000).default(100),
  LOGIN_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().min(1000).max(3600000).default(900000),
  LOGIN_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(20).default(5),
  TRUST_PROXY_HOPS: z.coerce.number().int().min(0).max(10).default(0),
  SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().min(1).max(120000).default(10000),
  JWT_SECRET_BASE64: z
    .string()
    .min(1)
    .refine((value) => {
      const decoded = Buffer.from(value, 'base64');
      return decoded.length >= 32 && decoded.toString('base64') === value;
    }, 'must be canonical base64 encoding of at least 32 random bytes'),
  JWT_ISSUER: z.string().url(),
  JWT_AUDIENCE: z.string().min(1).max(255),
  JWT_EXPIRES_IN_SECONDS: z.coerce.number().int().min(60).max(3600).default(900),
});

function mapDatabaseConfig(parsed) {
  return {
    host: parsed.DATABASE_HOST,
    port: parsed.DATABASE_PORT,
    database: parsed.DATABASE_NAME,
    user: parsed.DATABASE_USER,
    password: parsed.DATABASE_PASSWORD,
    max: parsed.DATABASE_POOL_MAX,
    idleTimeoutMillis: parsed.DATABASE_IDLE_TIMEOUT_MS,
    connectionTimeoutMillis: parsed.DATABASE_CONNECTION_TIMEOUT_MS,
    queryTimeoutMillis: parsed.DATABASE_QUERY_TIMEOUT_MS,
  };
}

export function loadDatabaseConfig(environment = process.env) {
  return mapDatabaseConfig(databaseSchema.parse(environment));
}

export function loadConfig(environment = process.env) {
  const parsed = applicationSchema.merge(databaseSchema).parse(environment);
  return {
    nodeEnv: parsed.NODE_ENV,
    host: parsed.HOST,
    port: parsed.PORT,
    logLevel: parsed.LOG_LEVEL,
    corsOrigins: parsed.CORS_ORIGINS,
    rateLimitWindowMs: parsed.RATE_LIMIT_WINDOW_MS,
    rateLimitMax: parsed.RATE_LIMIT_MAX,
    loginRateLimitWindowMs: parsed.LOGIN_RATE_LIMIT_WINDOW_MS,
    loginRateLimitMax: parsed.LOGIN_RATE_LIMIT_MAX,
    trustProxyHops: parsed.TRUST_PROXY_HOPS,
    shutdownTimeoutMs: parsed.SHUTDOWN_TIMEOUT_MS,
    database: mapDatabaseConfig(parsed),
    jwt: {
      secret: Buffer.from(parsed.JWT_SECRET_BASE64, 'base64'),
      issuer: parsed.JWT_ISSUER,
      audience: parsed.JWT_AUDIENCE,
      expiresInSeconds: parsed.JWT_EXPIRES_IN_SECONDS,
    },
  };
}
