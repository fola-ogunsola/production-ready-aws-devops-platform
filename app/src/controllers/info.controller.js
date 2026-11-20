import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const packageMetadata = require('../../package.json');

export function getApplicationInfo(_request, response) {
  response.json({
    data: {
      name: packageMetadata.name,
      version: packageMetadata.version,
      apiVersion: 'v1',
    },
  });
}
