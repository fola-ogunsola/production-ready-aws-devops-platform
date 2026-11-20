import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { createAuthController } from '../controllers/auth.controller.js';
import { createAuthenticationMiddleware } from '../middleware/authenticate.js';
import { methodNotAllowed } from '../middleware/method-not-allowed.js';
import { validate } from '../middleware/validate.js';
import { loginSchema } from '../validators/auth.validator.js';
import { sendError } from '../utils/errors.js';

export function createAuthRouter({ config, authService, userRepository }) {
  const router = Router();
  const controller = createAuthController({ authService });
  const authenticate = createAuthenticationMiddleware({
    jwt: config.jwt,
    userRepository,
  });
  const loginRateLimit = rateLimit({
    windowMs: config.loginRateLimitWindowMs,
    limit: config.loginRateLimitMax,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler(request, response) {
      response.setHeader(
        'Retry-After',
        String(Math.ceil(config.loginRateLimitWindowMs / 1000)),
      );
      sendError(response, request.id, {
        status: 429,
        code: 'login_rate_limit_exceeded',
        message: 'Too many login attempts; try again later',
      });
    },
  });

  router
    .route('/login')
    .post(loginRateLimit, validate(loginSchema), controller.login)
    .all(methodNotAllowed(['POST']));
  router
    .route('/me')
    .get(authenticate, controller.me)
    .all(methodNotAllowed(['GET']));

  return router;
}
