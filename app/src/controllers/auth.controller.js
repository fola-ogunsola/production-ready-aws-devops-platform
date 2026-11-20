export function createAuthController({ authService }) {
  return {
    async login(request, response) {
      const token = await authService.login(request.body.email, request.body.password);
      response.json({ data: token });
    },

    me(request, response) {
      const { id, email, role, createdAt, updatedAt } = request.user;
      response.json({
        data: { id, email, role, createdAt, updatedAt },
      });
    },
  };
}
