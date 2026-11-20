import { AppError } from '../utils/errors.js';

export function methodNotAllowed(allowedMethods) {
  return (_request, response, next) => {
    response.setHeader('Allow', allowedMethods.join(', '));
    next(new AppError(405, 'method_not_allowed', 'Method not allowed'));
  };
}
