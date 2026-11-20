import pino from 'pino';

const redactedFields = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["x-api-key"]',
  'req.body.password',
  'req.body.secret',
  'req.body.token',
  'password',
  'secret',
  'token',
];

export function createLogger(config, destination = process.stdout) {
  return pino({
    level: config.logLevel,
    redact: {
      paths: redactedFields,
      censor: '[REDACTED]',
    },
  }, destination);
}
