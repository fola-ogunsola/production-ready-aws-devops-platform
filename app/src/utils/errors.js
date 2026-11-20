export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export function sendError(response, requestId, { status, code, message, details }) {
  const error = { code, message, requestId };
  if (details) {
    error.details = details;
  }

  response.status(status).json({ error });
}
