import { z } from 'zod';

const statusSchema = z.enum(['pending', 'in_progress', 'completed']);

export const createTaskSchema = z.strictObject({
  title: z.string().trim().min(1).max(200),
  description: z.string().max(2000).optional(),
  status: statusSchema.optional(),
});

export const updateTaskSchema = z
  .strictObject({
    title: z.string().trim().min(1).max(200).optional(),
    description: z.string().max(2000).optional(),
    status: statusSchema.optional(),
  })
  .refine((input) => Object.keys(input).length > 0, {
    message: 'At least one task field must be provided',
  });

export const taskIdSchema = z.uuid();
