import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const migrationsDirectory = fileURLToPath(new URL('../../migrations/', import.meta.url));
const migrationLockId = '7420916354201';

export async function runMigrations(pool, logger = console) {
  const client = await pool.connect();
  try {
    await client.query('SELECT pg_advisory_lock($1::bigint)', [migrationLockId]);
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version text PRIMARY KEY,
        checksum char(64) NOT NULL,
        applied_at timestamptz NOT NULL DEFAULT NOW()
      )
    `);

    const files = (await readdir(migrationsDirectory))
      .filter((file) => /^\d{3}_[a-z0-9_]+\.sql$/.test(file))
      .sort();

    for (const file of files) {
      const sql = await readFile(new URL(`../../migrations/${file}`, import.meta.url), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      const applied = await client.query(
        'SELECT checksum FROM schema_migrations WHERE version = $1',
        [file],
      );

      if (applied.rowCount > 0) {
        if (applied.rows[0].checksum.trim() !== checksum) {
          throw new Error(`Applied migration checksum mismatch: ${file}`);
        }
        continue;
      }

      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          'INSERT INTO schema_migrations (version, checksum) VALUES ($1, $2)',
          [file, checksum],
        );
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }

      logger.info({ migration: file }, 'Database migration applied');
    }
  } finally {
    try {
      await client.query('SELECT pg_advisory_unlock($1::bigint)', [migrationLockId]);
    } finally {
      client.release();
    }
  }
}
