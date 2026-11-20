const taskColumns = `
  id,
  title,
  description,
  status,
  created_at AS "createdAt",
  updated_at AS "updatedAt"
`;

export function createPostgresTaskRepository(pool) {
  return {
    async list(userId) {
      const result = await pool.query(
        `SELECT ${taskColumns}
         FROM tasks
         WHERE user_id = $1
         ORDER BY created_at DESC, id`,
        [userId],
      );
      return result.rows;
    },

    async findById(id, userId) {
      const result = await pool.query(
        `SELECT ${taskColumns}
         FROM tasks
         WHERE id = $1 AND user_id = $2`,
        [id, userId],
      );
      return result.rows[0] ?? null;
    },

    async create(userId, task) {
      const result = await pool.query(
        `INSERT INTO tasks (user_id, title, description, status)
         VALUES ($1, $2, $3, $4)
         RETURNING ${taskColumns}`,
        [userId, task.title, task.description, task.status],
      );
      return result.rows[0];
    },

    async update(id, userId, task) {
      const fields = {
        title: ['title', task.title],
        description: ['description', task.description],
        status: ['status', task.status],
      };
      const updates = Object.entries(fields).filter(([, [, value]]) => value !== undefined);
      const values = updates.map(([, [, value]]) => value);
      const setClauses = updates.map(([key, [column]], index) => `${column} = $${index + 3}`);
      setClauses.push('updated_at = NOW()');

      const result = await pool.query(
        `UPDATE tasks
         SET ${setClauses.join(', ')}
         WHERE id = $1 AND user_id = $2
         RETURNING ${taskColumns}`,
        [id, userId, ...values],
      );
      return result.rows[0] ?? null;
    },

    async delete(id, userId) {
      const result = await pool.query(
        'DELETE FROM tasks WHERE id = $1 AND user_id = $2 RETURNING id',
        [id, userId],
      );
      return result.rowCount > 0;
    },
  };
}
