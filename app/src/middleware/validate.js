import { AppError } from '../utils/errors.js';

export function validate(schema, property = 'body') {
  return (request, _response, next) => {
    const propertyPath = property.split('.');
    const value = propertyPath.reduce((current, key) => current?.[key], request);
    const result = schema.safeParse(value);
    if (!result.success) {
      const details = result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
      }));
      next(new AppError(400, 'validation_error', 'Request validation failed', details));
      return;
    }

    const parent = propertyPath.slice(0, -1).reduce((current, key) => current[key], request);
    parent[propertyPath.at(-1)] = result.data;
    next();
  };
}
