const publicUserColumns = `
  id,
  email,
  role,
  created_at AS "createdAt",
  updated_at AS "updatedAt"
`;

export function createPostgresUserRepository(pool) {
  return {
    async findByEmail(email) {
      const result = await pool.query(
        `SELECT ${publicUserColumns}, password_hash AS "passwordHash"
         FROM users
         WHERE email = $1`,
        [email],
      );
      return result.rows[0] ?? null;
    },

    async findById(id) {
      const result = await pool.query(
        `SELECT ${publicUserColumns} FROM users WHERE id = $1`,
        [id],
      );
      return result.rows[0] ?? null;
    },

    async create({ email, passwordHash, role = 'user' }) {
      const result = await pool.query(
        `INSERT INTO users (email, password_hash, role)
         VALUES ($1, $2, $3)
         RETURNING ${publicUserColumns}`,
        [email, passwordHash, role],
      );
      return result.rows[0];
    },
  };
}
