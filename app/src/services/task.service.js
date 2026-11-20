import { AppError } from '../utils/errors.js';

export function createTaskService(repository) {
  return {
    listTasks(userId) {
      return repository.list(userId);
    },

    async getTask(id, userId) {
      const task = await repository.findById(id, userId);
      if (!task) {
        throw new AppError(404, 'task_not_found', 'Task not found');
      }
      return task;
    },

    createTask(userId, input) {
      return repository.create(userId, {
        title: input.title,
        description: input.description ?? '',
        status: input.status ?? 'pending',
      });
    },

    async updateTask(id, userId, input) {
      const task = await repository.update(id, userId, input);
      if (!task) {
        throw new AppError(404, 'task_not_found', 'Task not found');
      }
      return task;
    },

    async deleteTask(id, userId) {
      const deleted = await repository.delete(id, userId);
      if (!deleted) {
        throw new AppError(404, 'task_not_found', 'Task not found');
      }
    },
  };
}
