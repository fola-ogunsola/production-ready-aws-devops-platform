import { randomBytes } from 'node:crypto';
import argon2 from 'argon2';
import { SignJWT } from 'jose';
import { AppError } from '../utils/errors.js';

const passwordHashOptions = {
  type: argon2.argon2id,
  memoryCost: 19456,
  timeCost: 2,
  parallelism: 1,
  hashLength: 32,
};

export async function createAuthService({ userRepository, jwt, hasher = argon2 }) {
  const dummyPasswordHash = await hasher.hash(randomBytes(32), passwordHashOptions);

  return {
    async login(email, password) {
      const user = await userRepository.findByEmail(email);
      const hashToVerify = user?.passwordHash ?? dummyPasswordHash;
      const passwordMatches = await hasher
        .verify(hashToVerify, password)
        .catch(() => false);

      if (!user || !passwordMatches) {
        throw new AppError(401, 'authentication_failed', 'Invalid email or password');
      }

      const accessToken = await new SignJWT({})
        .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
        .setSubject(user.id)
        .setIssuer(jwt.issuer)
        .setAudience(jwt.audience)
        .setIssuedAt()
        .setExpirationTime(`${jwt.expiresInSeconds}s`)
        .sign(jwt.secret);

      return {
        accessToken,
        tokenType: 'Bearer',
        expiresIn: jwt.expiresInSeconds,
      };
    },
  };
}

export async function hashPassword(password, hasher = argon2) {
  return hasher.hash(password, passwordHashOptions);
}
