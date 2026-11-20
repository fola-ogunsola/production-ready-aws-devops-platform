CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(254) NOT NULL,
  password_hash varchar(255) NOT NULL,
  role varchar(16) NOT NULL DEFAULT 'user',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT users_email_normalized CHECK (email = lower(btrim(email))),
  CONSTRAINT users_email_shape CHECK (position('@' IN email) > 1),
  CONSTRAINT users_role_allowed CHECK (role IN ('user', 'admin')),
  CONSTRAINT users_password_hash_not_empty CHECK (length(password_hash) > 0)
);

CREATE UNIQUE INDEX users_email_unique_idx ON users (email);

CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  title varchar(200) NOT NULL,
  description varchar(2000) NOT NULL DEFAULT '',
  status varchar(16) NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT tasks_title_not_blank CHECK (length(btrim(title)) > 0),
  CONSTRAINT tasks_status_allowed CHECK (status IN ('pending', 'in_progress', 'completed'))
);

CREATE INDEX tasks_user_created_idx ON tasks (user_id, created_at DESC, id);
