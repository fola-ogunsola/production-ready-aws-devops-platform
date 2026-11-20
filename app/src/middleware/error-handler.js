import { AppError, sendError } from '../utils/errors.js';

export function notFoundHandler(request, response) {
  sendError(response, request.id, {
    status: 404,
    code: 'not_found',
    message: 'Route not found',
  });
}

export function errorHandler(error, request, response, next) {
  if (response.headersSent) {
    return next(error);
  }

  let appError = error;
  if (error?.type === 'entity.too.large') {
    appError = new AppError(413, 'payload_too_large', 'Request body exceeds the allowed size');
  } else if (error?.type === 'entity.parse.failed') {
    appError = new AppError(400, 'invalid_json', 'Request body contains invalid JSON');
  }

  if (appError instanceof AppError) {
    sendError(response, request.id, {
      status: appError.status,
      code: appError.code,
      message: appError.message,
      details: appError.details,
    });
    return;
  }

  request.log?.error(
    {
      requestId: request.id,
      errorName: error instanceof Error ? error.name : 'UnknownError',
    },
    'Unhandled request error',
  );
  sendError(response, request.id, {
    status: 500,
    code: 'internal_error',
    message: 'An unexpected error occurred',
  });
}
