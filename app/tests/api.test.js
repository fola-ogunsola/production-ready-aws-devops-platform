import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, describe, it } from 'node:test';
import argon2 from 'argon2';
import { SignJWT } from 'jose';
import pino from 'pino';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config/env.js';
import { createLogger } from '../src/config/logger.js';
import { requireRole } from '../src/middleware/require-role.js';
import { startServer } from '../src/server.js';

const logger = pino({ level: 'silent' });
const userId = 'c840d8e6-41ef-4efb-9617-8585faebbb31';
const otherUserId = '09fc359b-472f-4bfc-a817-c898d220aee5';
const adminId = 'f604f496-a842-45ae-8252-48b5467fc539';
const password = 'Test-Only-Passphrase-123!Change';

function testConfig(overrides = {}) {
  return loadConfig({
    NODE_ENV: 'test',
    LOG_LEVEL: 'silent',
    CORS_ORIGINS: 'https://allowed.example',
    DATABASE_HOST: '127.0.0.1',
    DATABASE_NAME: 'api_test',
    DATABASE_USER: 'api_test',
    DATABASE_PASSWORD: 'unit-test-only-database-password',
    JWT_SECRET_BASE64: Buffer.alloc(32, 7).toString('base64'),
    JWT_ISSUER: 'https://api.test.invalid',
    JWT_AUDIENCE: 'api-test',
    ...overrides,
  });
}

let config;
let users;
let userRepository;
let authService;
let userToken;
let otherUserToken;
let adminToken;

function createTaskRepository() {
  const tasks = new Map();
  const toResponse = ({ userId: _userId, ...task }) => task;
  return {
    async list(ownerId) {
      return [...tasks.values()]
        .filter((task) => task.userId === ownerId)
        .map(toResponse);
    },
    async findById(id, ownerId) {
      const task = tasks.get(id);
      return task?.userId === ownerId ? toResponse(task) : null;
    },
    async create(ownerId, input) {
      const now = new Date().toISOString();
      const task = {
        id: randomUUID(),
        userId: ownerId,
        ...input,
        createdAt: now,
        updatedAt: now,
      };
      tasks.set(task.id, task);
      return toResponse(task);
    },
    async update(id, ownerId, input) {
      const task = tasks.get(id);
      if (!task || task.userId !== ownerId) return null;
      const updated = { ...task, ...input, updatedAt: new Date().toISOString() };
      tasks.set(id, updated);
      return toResponse(updated);
    },
    async delete(id, ownerId) {
      const task = tasks.get(id);
      return task?.userId === ownerId ? tasks.delete(id) : false;
    },
  };
}

function testApp(options = {}) {
  return createApp({
    config,
    taskRepository: createTaskRepository(),
    userRepository,
    authService,
    logger,
    ...options,
  });
}

before(async () => {
  config = testConfig();
  const passwordHash = await argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 8192,
    timeCost: 1,
    parallelism: 1,
  });
  users = new Map([
    [userId, { id: userId, email: 'user@example.invalid', role: 'user', passwordHash }],
    [otherUserId, { id: otherUserId, email: 'other@example.invalid', role: 'user', passwordHash }],
    [adminId, { id: adminId, email: 'admin@example.invalid', role: 'admin', passwordHash }],
  ]);
  userRepository = {
    async findByEmail(email) {
      return [...users.values()].find((user) => user.email === email) ?? null;
    },
    async findById(id) {
      const user = users.get(id);
      if (!user) return null;
      const { passwordHash: _passwordHash, ...publicUser } = user;
      return publicUser;
    },
    async create(input) {
      const user = { id: randomUUID(), ...input, createdAt: new Date().toISOString() };
      users.set(user.id, user);
      return user;
    },
  };
  const { createAuthService } = await import('../src/services/auth.service.js');
  authService = await createAuthService({ userRepository, jwt: config.jwt });
  userToken = (await authService.login('user@example.invalid', password)).accessToken;
  otherUserToken = (await authService.login('other@example.invalid', password)).accessToken;
  adminToken = (await authService.login('admin@example.invalid', password)).accessToken;
});

after(() => {
  logger.flush();
});

describe('application startup and health checks', () => {
  it('starts, serves health checks, and closes the database pool on shutdown', async () => {
    let poolClosed = false;
    const pool = {
      on() {},
      async query() {
        return { rows: [{ '?column?': 1 }] };
      },
      async end() {
        poolClosed = true;
      },
    };
    const { server, app, shutdown } = await startServer({
      config: { ...config, host: '127.0.0.1', port: 0, shutdownTimeoutMs: 1000 },
      logger,
      pool,
      userRepository,
      taskRepository: createTaskRepository(),
      authService,
      registerSignalHandlers: false,
    });
    const address = server.address();
    assert.equal(server.listening, true);
    assert.equal((await fetch(`http://127.0.0.1:${address.port}/health/live`)).status, 200);
    assert.equal((await fetch(`http://127.0.0.1:${address.port}/health/ready`)).status, 200);

    await shutdown();
    assert.equal(server.listening, false);
    assert.equal(poolClosed, true);
    await request(app).get('/health/ready').expect(503, { status: 'not_ready' });
  });

  it('liveness does not depend on database availability', async () => {
    const app = testApp({ isReady: async () => false });
    await request(app).get('/health/live').expect(200, { status: 'ok' });
    await request(app).get('/health/ready').expect(503, { status: 'not_ready' });
  });

  it('returns 503 without leaking errors when the readiness query fails', async () => {
    let logOutput = '';
    const app = testApp({
      logger: pino(
        { level: 'warn' },
        {
          write(line) {
            logOutput += line;
          },
        },
      ),
      isReady: async () => {
        throw new Error('database connection details');
      },
    });
    const response = await request(app).get('/health/ready').expect(503);
    assert.deepEqual(response.body, { status: 'not_ready' });
    assert.equal(JSON.stringify(response.body).includes('database connection'), false);
    assert.equal(logOutput.includes('Readiness check failed'), true);
    assert.equal(logOutput.includes('"errorName":"Error"'), true);
    assert.equal(logOutput.includes('database connection details'), false);
  });
});

describe('authentication', () => {
  it('authenticates a provisioned account and returns a short-lived access token', async () => {
    const response = await request(testApp())
      .post('/api/v1/auth/login')
      .send({ email: 'USER@example.invalid', password })
      .expect(200);
    assert.equal(response.body.data.tokenType, 'Bearer');
    assert.equal(response.body.data.expiresIn, 900);
    assert.equal(typeof response.body.data.accessToken, 'string');

    const [, payload] = response.body.data.accessToken.split('.');
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString());
    assert.equal(claims.sub, userId);
    assert.equal(claims.email, undefined);
    assert.equal(claims.password, undefined);
  });

  it('returns indistinguishable errors for unknown users and incorrect passwords', async () => {
    const app = testApp();
    const unknownUser = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'missing@example.invalid', password })
      .expect(401);
    const incorrectPassword = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'user@example.invalid', password: 'incorrect-password' })
      .expect(401);
    assert.equal(unknownUser.body.error.code, 'authentication_failed');
    assert.equal(unknownUser.body.error.message, incorrectPassword.body.error.message);
    assert.equal(JSON.stringify(unknownUser.body).includes('missing@example'), false);
  });

  it('rejects invalid login input', async () => {
    const response = await request(testApp())
      .post('/api/v1/auth/login')
      .send({ email: 'not-an-email', password: 'x', admin: true })
      .expect(400);
    assert.equal(response.body.error.code, 'validation_error');
  });

  it('rejects missing and malformed bearer tokens', async () => {
    await request(testApp()).get('/api/v1/auth/me').expect(401);
    await request(testApp())
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer not-a-jwt')
      .expect(401);
  });

  it('rejects expired, wrong issuer, and wrong audience tokens', async () => {
    const expiredToken = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer(config.jwt.issuer)
      .setAudience(config.jwt.audience)
      .setExpirationTime('1 second ago')
      .sign(config.jwt.secret);
    const wrongIssuer = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer('https://wrong.test.invalid')
      .setAudience(config.jwt.audience)
      .setExpirationTime('5 minutes')
      .sign(config.jwt.secret);
    const wrongAudience = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer(config.jwt.issuer)
      .setAudience('wrong-audience')
      .setExpirationTime('5 minutes')
      .sign(config.jwt.secret);

    for (const token of [expiredToken, wrongIssuer, wrongAudience]) {
      await request(testApp())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
    }
  });

  it('returns authenticated user information without password data', async () => {
    const response = await request(testApp())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);
    assert.equal(response.body.data.id, userId);
    assert.equal(response.body.data.email, 'user@example.invalid');
    assert.equal(response.body.data.role, 'user');
    assert.equal('passwordHash' in response.body.data, false);
  });

  it('rate limits repeated login attempts', async () => {
    const app = testApp({
      config: testConfig({
        LOGIN_RATE_LIMIT_MAX: '2',
        LOGIN_RATE_LIMIT_WINDOW_MS: '60000',
      }),
    });
    await request(app).post('/api/v1/auth/login').send({ email: 'nobody@example.invalid', password }).expect(401);
    await request(app).post('/api/v1/auth/login').send({ email: 'nobody@example.invalid', password }).expect(401);
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'nobody@example.invalid', password })
      .expect(429);
    assert.equal(response.body.error.code, 'login_rate_limit_exceeded');
  });
});

describe('per-user task authorization', () => {
  it('requires a valid JWT for all task endpoints', async () => {
    const app = testApp();
    await request(app).get('/api/v1/tasks').expect(401);
    await request(app)
      .post('/api/v1/tasks')
      .send({ title: 'No auth' })
      .expect(401);
    await request(app)
      .get(`/api/v1/tasks/${randomUUID()}`)
      .set('Authorization', 'Bearer invalid')
      .expect(401);
  });

  it('creates, lists, reads, updates, and deletes tasks for their owner', async () => {
    const app = testApp();
    const createdResponse = await request(app)
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ title: 'Rotate credentials', description: 'Rotate staging secret' })
      .expect(201);
    const task = createdResponse.body.data;

    assert.equal('userId' in task, false);
    assert.equal(task.status, 'pending');
    assert.equal(typeof task.createdAt, 'string');
    assert.equal(createdResponse.headers.location, `/api/v1/tasks/${task.id}`);
    await request(app)
      .get('/api/v1/tasks')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200)
      .expect(({ body }) => assert.deepEqual(body.data, [task]));
    await request(app)
      .get(`/api/v1/tasks/${task.id}`)
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);
    await request(app)
      .patch(`/api/v1/tasks/${task.id}`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({ status: 'in_progress' })
      .expect(200)
      .expect(({ body }) => assert.equal(body.data.status, 'in_progress'));
    await request(app)
      .delete(`/api/v1/tasks/${task.id}`)
      .set('Authorization', `Bearer ${userToken}`)
      .expect(204);
    await request(app)
      .get(`/api/v1/tasks/${task.id}`)
      .set('Authorization', `Bearer ${userToken}`)
      .expect(404);
  });

  it('does not allow a user to list or access another user task', async () => {
    const app = testApp();
    const task = (await request(app)
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ title: 'Owner only' })
      .expect(201)).body.data;

    await request(app)
      .get('/api/v1/tasks')
      .set('Authorization', `Bearer ${otherUserToken}`)
      .expect(200)
      .expect(({ body }) => assert.deepEqual(body.data, []));
    for (const operation of [
      () => request(app).get(`/api/v1/tasks/${task.id}`),
      () => request(app).patch(`/api/v1/tasks/${task.id}`).send({ title: 'Tampered' }),
      () => request(app).delete(`/api/v1/tasks/${task.id}`),
    ]) {
      await operation()
        .set('Authorization', `Bearer ${otherUserToken}`)
        .expect(404)
        .expect(({ body }) => assert.equal(body.error.code, 'task_not_found'));
    }
    await request(app)
      .get(`/api/v1/tasks/${task.id}`)
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200)
      .expect(({ body }) => assert.equal(body.data.title, 'Owner only'));
  });

  it('does not trust client-supplied owner IDs', async () => {
    const response = await request(testApp())
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ title: 'Owned by token', userId: otherUserId })
      .expect(400);
    assert.equal(response.body.error.code, 'validation_error');
  });

  it('validates fields and reports unsupported task methods', async () => {
    const app = testApp();
    await request(app)
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ title: '  ' })
      .expect(400);
    const response = await request(app)
      .put('/api/v1/tasks')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(405);
    assert.equal(response.headers.allow, 'GET, POST');
  });
});

describe('authorization helpers and error responses', () => {
  it('provides a role-checking middleware for future administrative operations', async () => {
    const invoke = (role) =>
      new Promise((resolve) => {
        const middleware = requireRole('admin');
        const response = {
          status(status) {
            this.statusCode = status;
            return this;
          },
          json(body) {
            resolve({ status: this.statusCode, body });
          },
        };
        middleware({ auth: { role }, id: 'role-check' }, response, () => resolve({ status: 200 }));
      });

    assert.equal((await invoke('user')).status, 403);
    assert.equal((await invoke('admin')).status, 200);
  });

  it('does not expose internal database errors', async () => {
    const app = testApp({
      taskRepository: {
        async list() {
          throw new Error('postgres://secret:password@database.internal');
        },
      },
    });
    const response = await request(app)
      .get('/api/v1/tasks')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(500);
    assert.equal(response.body.error.message, 'An unexpected error occurred');
    assert.equal(JSON.stringify(response.body).includes('database.internal'), false);
  });

  it('validates database and signing-key configuration', () => {
    assert.throws(() => testConfig({ DATABASE_PASSWORD: '' }));
    assert.throws(() => testConfig({ JWT_SECRET_BASE64: 'short' }));
    assert.throws(() => testConfig({ JWT_ISSUER: 'not-a-url' }));
  });
});
