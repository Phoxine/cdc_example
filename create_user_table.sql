create table users(
  id UUID PRIMARY key,
  name VARCHAR(32) NOT NULL,
  created_data timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_active bool NOT NULL DEFAULT false
)