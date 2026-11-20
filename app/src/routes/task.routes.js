import { Router } from 'express';
import { createTaskController } from '../controllers/task.controller.js';
import { methodNotAllowed } from '../middleware/method-not-allowed.js';
import { validate } from '../middleware/validate.js';
import {
  createTaskSchema,
  taskIdSchema,
  updateTaskSchema,
} from '../validators/task.validator.js';

export function createTaskRouter({ service, authenticate }) {
  const router = Router();
  const controller = createTaskController(service);

  router
    .route('/')
    .get(authenticate, controller.list)
    .post(authenticate, validate(createTaskSchema), controller.create)
    .all(methodNotAllowed(['GET', 'POST']));

  router
    .route('/:id')
    .get(authenticate, validate(taskIdSchema, 'params.id'), controller.get)
    .patch(
      authenticate,
      validate(taskIdSchema, 'params.id'),
      validate(updateTaskSchema),
      controller.update,
    )
    .delete(authenticate, validate(taskIdSchema, 'params.id'), controller.delete)
    .all(methodNotAllowed(['GET', 'PATCH', 'DELETE']));

  return router;
}
