import { sendError } from '../utils/errors.js';

export function requireRole(...allowedRoles) {
  return (request, response, next) => {
    if (!request.auth || !allowedRoles.includes(request.auth.role)) {
      sendError(response, request.id, {
        status: 403,
        code: 'forbidden',
        message: 'You do not have permission to perform this action',
      });
      return;
    }
    next();
  };
}
