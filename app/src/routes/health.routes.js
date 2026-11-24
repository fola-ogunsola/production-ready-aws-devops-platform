import { Router } from 'express';
import { methodNotAllowed } from '../middleware/method-not-allowed.js';

export function createHealthRouter(isReady) {
  const router = Router();

  router
    .route('/live')
    .get((_request, response) => {
      response.json({ status: 'ok' });
    })
    .all(methodNotAllowed(['GET']));

  router
    .route('/ready')
    .get(async (request, response) => {
      let ready = false;
      try {
        ready = await isReady();
      } catch (error) {
        request.log?.warn(
          {
            requestId: request.id,
            errorName: error instanceof Error ? error.name : 'UnknownError',
          },
          'Readiness check failed',
        );
        ready = false;
      }
      if (!ready) {
        response.status(503).json({ status: 'not_ready' });
        return;
      }
      response.json({ status: 'ready' });
    })
    .all(methodNotAllowed(['GET']));

  return router;
}
