import 'dotenv/config';
import { createInterface, emitKeypressEvents } from 'node:readline';
import { createDatabasePool } from '../db/pool.js';
import { loadDatabaseConfig } from '../config/env.js';
import { createPostgresUserRepository } from '../repositories/postgres-user.repository.js';
import { hashPassword } from '../services/auth.service.js';
import { emailSchema, provisionUserSchema } from '../validators/auth.validator.js';

function readHidden(prompt) {
  const input = process.stdin;
  const output = process.stdout;
  if (!input.isTTY || !output.isTTY || typeof input.setRawMode !== 'function') {
    throw new Error('Administrator provisioning requires an interactive terminal');
  }

  return new Promise((resolve, reject) => {
    emitKeypressEvents(input);
    input.setRawMode(true);
    input.resume();
    output.write(prompt);
    let value = '';

    const cleanup = () => {
      input.off('keypress', onKeypress);
      input.setRawMode(false);
      input.pause();
      output.write('\n');
    };
    const onKeypress = (character, key = {}) => {
      if (key.ctrl && key.name === 'c') {
        cleanup();
        reject(new Error('Administrator provisioning cancelled'));
        return;
      }
      if (key.name === 'return' || key.name === 'enter') {
        cleanup();
        resolve(value);
        return;
      }
      if (key.name === 'backspace') {
        value = value.slice(0, -1);
        return;
      }
      if (!key.ctrl && !key.meta && character) {
        value += character;
      }
    };

    input.on('keypress', onKeypress);
  });
}

async function main() {
  let pool;
  const emailPrompt = createInterface({ input: process.stdin, output: process.stdout });
  try {
    const role = process.argv[2];
    if (!['admin', 'user'].includes(role)) {
      throw new Error('Specify account role with the provision:admin or provision:user command');
    }

    const { email: rawEmail } = await new Promise((resolve, reject) => {
      emailPrompt.question('Administrator email: ', (email) => resolve({ email }));
      emailPrompt.on('SIGINT', () => reject(new Error('Administrator provisioning cancelled')));
    });
    emailPrompt.close();

    const email = emailSchema.parse(rawEmail);
    const password = await readHidden('Password (15-128 characters, hidden): ');
    const confirmation = await readHidden('Confirm password (hidden): ');
    const credentials = provisionUserSchema.parse({ email, password });
    if (credentials.password !== confirmation) {
      throw new Error('Password confirmation did not match');
    }

    const databaseConfig = loadDatabaseConfig();
    pool = createDatabasePool(databaseConfig);
    const users = createPostgresUserRepository(pool);
    await users.create({
      email: credentials.email,
      passwordHash: await hashPassword(credentials.password),
      role,
    });
    process.stdout.write(`${role === 'admin' ? 'Administrator' : 'User'} account created.\n`);
  } catch (error) {
    process.stderr.write(
      `${error instanceof Error ? error.message : 'Administrator provisioning failed'}\n`,
    );
    process.exitCode = 1;
  } finally {
    emailPrompt.close();
    await pool?.end();
  }
}

await main();
