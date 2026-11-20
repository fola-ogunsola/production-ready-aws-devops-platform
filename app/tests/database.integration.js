import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import pino from 'pino';
import request from 'supertest';
import { loadConfig } from '../src/config/env.js';
import { createDatabasePool } from '../src/db/pool.js';
import { runMigrations } from '../src/migrations/migrate.js';
import { createPostgresTaskRepository } from '../src/repositories/postgres-task.repository.js';
import { createPostgresUserRepository } from '../src/repositories/postgres-user.repository.js';
import { createApp } from '../src/app.js';
import { createAuthService, hashPassword } from '../src/services/auth.service.js';

test('isolated PostgreSQL persists tasks and enforces user ownership', async (context) => {
  const config = loadConfig();
  assert.equal(
    config.database.database,
    'task_api_test',
    'integration tests must only connect to the dedicated task_api_test database',
  );
  const logger = pino({ level: 'silent' });
  let pool = createDatabasePool(config.database);
  let poolClosed = false;
  const closePool = async () => {
    if (!poolClosed) {
      await pool.end();
      poolClosed = true;
    }
  };
  context.after(async () => {
    await closePool();
    logger.flush();
  });

  await runMigrations(pool, { info() {} });
  await runMigrations(pool, { info() {} });
  const users = createPostgresUserRepository(pool);
  const tasks = createPostgresTaskRepository(pool);
  const password = 'Integration-Test-Only-Password-123!';
  const passwordHash = await hashPassword(password);
  const owner = await users.create({
    email: `owner-${randomUUID()}@example.invalid`,
    passwordHash,
    role: 'user',
  });
  const other = await users.create({
    email: `other-${randomUUID()}@example.invalid`,
    passwordHash,
    role: 'user',
  });
  const authService = await createAuthService({ userRepository: users, jwt: config.jwt });
  const ownerToken = (await authService.login(owner.email, password)).accessToken;
  const otherToken = (await authService.login(other.email, password)).accessToken;
  const app = createApp({
    config,
    userRepository: users,
    taskRepository: tasks,
    authService,
    logger,
    isReady: async () => {
      try {
        await pool.query({
          text: 'SELECT 1',
          query_timeout: config.database.queryTimeoutMillis,
          statement_timeout: config.database.queryTimeoutMillis,
        });
        return true;
      } catch {
        return false;
      }
    },
  });

  await request(app).get('/health/live').expect(200, { status: 'ok' });
  await request(app).get('/health/ready').expect(200, { status: 'ready' });
  await request(app).get('/api/v1/tasks').expect(401);

  const created = await request(app)
    .post('/api/v1/tasks')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ title: 'Persist across API restart', description: 'Integration test' })
    .expect(201);
  const task = created.body.data;

  await request(app)
    .get(`/api/v1/tasks/${task.id}`)
    .set('Authorization', `Bearer ${otherToken}`)
    .expect(404);
  await request(app)
    .patch(`/api/v1/tasks/${task.id}`)
    .set('Authorization', `Bearer ${otherToken}`)
    .send({ title: 'Unauthorized update' })
    .expect(404);
  await request(app)
    .delete(`/api/v1/tasks/${task.id}`)
    .set('Authorization', `Bearer ${otherToken}`)
    .expect(404);
  await request(app)
    .patch(`/api/v1/tasks/${task.id}`)
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ status: 'in_progress' })
    .expect(200);

  await closePool();
  pool = createDatabasePool(config.database);
  poolClosed = false;
  const tasksAfterReconnect = createPostgresTaskRepository(pool);
  const persistedTask = await tasksAfterReconnect.findById(task.id, owner.id);
  assert.equal(persistedTask.status, 'in_progress');
  assert.equal(persistedTask.title, 'Persist across API restart');
  assert.equal(
    await tasksAfterReconnect.findById(task.id, other.id),
    null,
    'queries must scope task lookups to the requesting user',
  );

  await closePool();
  const unavailableApp = createApp({
    config,
    userRepository: users,
    taskRepository: tasksAfterReconnect,
    authService,
    logger,
    isReady: async () => {
      try {
        await pool.query('SELECT 1');
        return true;
      } catch {
        return false;
      }
    },
  });
  await request(unavailableApp)
    .get('/health/live')
    .expect(200, { status: 'ok' });
  await request(unavailableApp)
    .get('/health/ready')
    .expect(503, { status: 'not_ready' });
});
