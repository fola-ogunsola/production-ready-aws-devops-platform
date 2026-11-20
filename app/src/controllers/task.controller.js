export function createTaskController(service) {
  return {
    async list(request, response) {
      const tasks = await service.listTasks(request.auth.id);
      response.json({ data: tasks });
    },

    async get(request, response) {
      const task = await service.getTask(request.params.id, request.auth.id);
      response.json({ data: task });
    },

    async create(request, response) {
      const task = await service.createTask(request.auth.id, request.body);
      response
        .location(`/api/v1/tasks/${task.id}`)
        .status(201)
        .json({ data: task });
    },

    async update(request, response) {
      const task = await service.updateTask(request.params.id, request.auth.id, request.body);
      response.json({ data: task });
    },

    async delete(request, response) {
      await service.deleteTask(request.params.id, request.auth.id);
      response.status(204).end();
    },
  };
}
