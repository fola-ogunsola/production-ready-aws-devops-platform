import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { createPostgresTaskRepository } from '../src/repositories/postgres-task.repository.js';
import { createPostgresUserRepository } from '../src/repositories/postgres-user.repository.js';

describe('PostgreSQL task repository queries', () => {
  it('scopes every task operation by the authenticated user ID', async () => {
    const calls = [];
    const pool = {
      async query(text, values) {
        calls.push({ text, values });
        return { rows: [], rowCount: 1 };
      },
    };
    const repository = createPostgresTaskRepository(pool);

    await repository.list('owner-1');
    await repository.findById('task-1', 'owner-1');
    await repository.create('owner-1', {
      title: 'Task',
      description: '',
      status: 'pending',
    });
    await repository.update('task-1', 'owner-1', { status: 'completed' });
    await repository.delete('task-1', 'owner-1');

    assert.deepEqual(calls.map(({ values }) => values[0]), [
      'owner-1',
      'task-1',
      'owner-1',
      'task-1',
      'task-1',
    ]);
    assert.deepEqual(calls[1].values, ['task-1', 'owner-1']);
    assert.deepEqual(calls[3].values, ['task-1', 'owner-1', 'completed']);
    assert.deepEqual(calls[4].values, ['task-1', 'owner-1']);
    assert.ok(calls.every(({ text }) => text.includes('$')));
  });

  it('uses only fixed column names when constructing partial updates', async () => {
    let query;
    const repository = createPostgresTaskRepository({
      async query(text, values) {
        query = { text, values };
        return { rows: [], rowCount: 0 };
      },
    });
    await repository.update('task-1', 'owner-1', { status: 'completed' });
    assert.match(query.text, /status = \$3/);
    assert.deepEqual(query.values, ['task-1', 'owner-1', 'completed']);
    assert.equal(await repository.findById('task-1', 'owner-1'), null);
  });
});

describe('PostgreSQL user repository queries', () => {
  it('uses parameterized queries and omits the password hash from public lookups', async () => {
    const calls = [];
    const pool = {
      async query(text, values) {
        calls.push({ text, values });
        return { rows: [{ id: 'user-1', email: 'user@example.invalid' }], rowCount: 1 };
      },
    };
    const repository = createPostgresUserRepository(pool);

    await repository.findByEmail('user@example.invalid');
    await repository.findById('user-1');
    await repository.create({
      email: 'user@example.invalid',
      passwordHash: '$argon2id$hash',
      role: 'admin',
    });

    assert.deepEqual(calls[0].values, ['user@example.invalid']);
    assert.deepEqual(calls[1].values, ['user-1']);
    assert.deepEqual(calls[2].values, ['user@example.invalid', '$argon2id$hash', 'admin']);
    assert.match(calls[0].text, /password_hash AS "passwordHash"/);
    assert.doesNotMatch(calls[1].text, /password_hash/);
  });
});
