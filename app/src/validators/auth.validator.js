import { z } from 'zod';

export const emailSchema = z
  .email()
  .max(254)
  .transform((email) => email.trim().toLowerCase());

export const loginSchema = z.strictObject({
  email: emailSchema,
  password: z.string().min(1).max(128),
});

export const provisionUserSchema = z.strictObject({
  email: emailSchema,
  password: z.string().min(15).max(128),
});
