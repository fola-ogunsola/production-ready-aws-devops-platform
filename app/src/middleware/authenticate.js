import { jwtVerify } from 'jose';
import { sendError } from '../utils/errors.js';

function unauthorized(response, requestId) {
  response.setHeader('WWW-Authenticate', 'Bearer');
  sendError(response, requestId, {
    status: 401,
    code: 'unauthorized',
    message: 'A valid access token is required',
  });
}

export function createAuthenticationMiddleware({ jwt, userRepository }) {
  return async (request, response, next) => {
    const authorization = request.get('authorization');
    const match = typeof authorization === 'string'
      ? /^Bearer ([^\s]+)$/i.exec(authorization)
      : null;
    if (!match) {
      unauthorized(response, request.id);
      return;
    }

    let subject;
    try {
      const { payload } = await jwtVerify(match[1], jwt.secret, {
        algorithms: ['HS256'],
        issuer: jwt.issuer,
        audience: jwt.audience,
      });
      subject = payload.sub;
      if (typeof subject !== 'string') {
        unauthorized(response, request.id);
        return;
      }
    } catch {
      unauthorized(response, request.id);
      return;
    }

    const user = await userRepository.findById(subject);
    if (!user) {
      unauthorized(response, request.id);
      return;
    }

    request.auth = { id: user.id, role: user.role };
    request.user = user;
    next();
  };
}
