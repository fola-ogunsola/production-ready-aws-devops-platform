import pg from 'pg';

const { Pool } = pg;

export function createDatabasePool(config) {
  return new Pool({
    host: config.host,
    port: config.port,
    database: config.database,
    user: config.user,
    password: config.password,
    max: config.max,
    idleTimeoutMillis: config.idleTimeoutMillis,
    connectionTimeoutMillis: config.connectionTimeoutMillis,
    query_timeout: config.queryTimeoutMillis,
    statement_timeout: config.queryTimeoutMillis,
    application_name: 'production-ready-aws-devops-platform-api',
    ssl: config.ssl,
  });
}
