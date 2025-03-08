-- Create SQL version of the squashed migration for direct execution

-- Drop tables if they exist
DROP TABLE IF EXISTS team_members CASCADE;
DROP TABLE IF EXISTS game_rounds CASCADE;
DROP TABLE IF EXISTS games CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS game_configs CASCADE;
DROP TABLE IF EXISTS game_roles CASCADE;
DROP TABLE IF EXISTS player_stats CASCADE;
DROP TABLE IF EXISTS round_stats CASCADE;
DROP TABLE IF EXISTS team_invitations CASCADE;

-- Create teams table
CREATE TABLE teams (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  guild_id VARCHAR(255) NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  score INTEGER DEFAULT 0,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX teams_guild_id_idx ON teams (guild_id);

-- Create users table
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  discord_id VARCHAR(255) NOT NULL,
  guild_id VARCHAR(255) NOT NULL,
  username VARCHAR(255),
  active BOOLEAN DEFAULT TRUE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX users_discord_id_idx ON users (discord_id);
CREATE INDEX users_guild_id_idx ON users (guild_id);

-- Create team members table
CREATE TABLE team_members (
  id BIGSERIAL PRIMARY KEY,
  team_id BIGINT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  active BOOLEAN DEFAULT TRUE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX team_members_team_id_idx ON team_members (team_id);
CREATE INDEX team_members_user_id_idx ON team_members (user_id);
CREATE UNIQUE INDEX team_members_team_id_user_id_idx ON team_members (team_id, user_id);

-- Create games table
CREATE TABLE games (
  id BIGSERIAL PRIMARY KEY,
  game_id VARCHAR(255) NOT NULL,
  guild_id VARCHAR(255) NOT NULL,
  mode VARCHAR(255) NOT NULL,
  status VARCHAR(255) DEFAULT 'created',
  created_by VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE,
  started_at TIMESTAMP WITH TIME ZONE,
  finished_at TIMESTAMP WITH TIME ZONE,
  winner_team_id BIGINT REFERENCES teams(id) ON DELETE SET NULL,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX games_game_id_idx ON games (game_id);
CREATE INDEX games_guild_id_idx ON games (guild_id);
CREATE INDEX games_status_idx ON games (status);

-- Create game rounds table
CREATE TABLE game_rounds (
  id BIGSERIAL PRIMARY KEY,
  game_id BIGINT NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  guild_id VARCHAR(255) NOT NULL,
  round_number INTEGER NOT NULL,
  status VARCHAR(255) DEFAULT 'active',
  started_at TIMESTAMP WITH TIME ZONE,
  finished_at TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX game_rounds_game_id_idx ON game_rounds (game_id);
CREATE INDEX game_rounds_guild_id_idx ON game_rounds (guild_id);
CREATE UNIQUE INDEX game_rounds_game_id_round_number_idx ON game_rounds (game_id, round_number);

-- Create game configs table
CREATE TABLE game_configs (
  id BIGSERIAL PRIMARY KEY,
  guild_id VARCHAR(255) NOT NULL,
  mode VARCHAR(255) NOT NULL,
  config JSONB NOT NULL,
  created_by VARCHAR(255),
  active BOOLEAN DEFAULT TRUE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX game_configs_guild_id_idx ON game_configs (guild_id);
CREATE UNIQUE INDEX game_configs_guild_id_mode_idx ON game_configs (guild_id, mode);

-- Create game roles table
CREATE TABLE game_roles (
  id BIGSERIAL PRIMARY KEY,
  guild_id VARCHAR(255) NOT NULL,
  role_id VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  permissions TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_by VARCHAR(255),
  active BOOLEAN DEFAULT TRUE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX game_roles_guild_id_idx ON game_roles (guild_id);
CREATE UNIQUE INDEX game_roles_guild_id_role_id_idx ON game_roles (guild_id, role_id);

-- Create player stats table
CREATE TABLE player_stats (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  guild_id VARCHAR(255) NOT NULL,
  games_played INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  total_score INTEGER DEFAULT 0,
  average_score FLOAT DEFAULT 0.0,
  best_score INTEGER DEFAULT 0,
  total_guesses INTEGER DEFAULT 0,
  correct_guesses INTEGER DEFAULT 0,
  guess_accuracy FLOAT DEFAULT 0.0,
  total_matches INTEGER DEFAULT 0,
  best_match_score INTEGER DEFAULT 0,
  match_percentage FLOAT DEFAULT 0.0,
  last_played_at TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX player_stats_user_id_idx ON player_stats (user_id);
CREATE INDEX player_stats_guild_id_idx ON player_stats (guild_id);
CREATE UNIQUE INDEX player_stats_user_id_guild_id_idx ON player_stats (user_id, guild_id);

-- Create round stats table
CREATE TABLE round_stats (
  id BIGSERIAL PRIMARY KEY,
  game_id BIGINT NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  guild_id VARCHAR(255) NOT NULL,
  round_number INTEGER NOT NULL,
  team_id BIGINT REFERENCES teams(id) ON DELETE SET NULL,
  total_guesses INTEGER DEFAULT 0,
  correct_guesses INTEGER DEFAULT 0,
  guess_accuracy FLOAT DEFAULT 0.0,
  best_match_score INTEGER DEFAULT 0,
  average_match_score FLOAT DEFAULT 0.0,
  round_duration INTEGER,
  started_at TIMESTAMP WITH TIME ZONE,
  finished_at TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX round_stats_game_id_idx ON round_stats (game_id);
CREATE INDEX round_stats_guild_id_idx ON round_stats (guild_id);
CREATE INDEX round_stats_team_id_idx ON round_stats (team_id);
CREATE UNIQUE INDEX round_stats_game_id_round_number_team_id_idx ON round_stats (game_id, round_number, team_id);

-- Create team invitations table
CREATE TABLE team_invitations (
  id BIGSERIAL PRIMARY KEY,
  team_id BIGINT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  guild_id VARCHAR(255) NOT NULL,
  invited_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invited_by_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  status VARCHAR(255) DEFAULT 'pending',
  expires_at TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX team_invitations_team_id_idx ON team_invitations (team_id);
CREATE INDEX team_invitations_guild_id_idx ON team_invitations (guild_id);
CREATE INDEX team_invitations_invited_user_id_idx ON team_invitations (invited_user_id);
CREATE UNIQUE INDEX team_invitations_team_id_invited_user_id_idx ON team_invitations (team_id, invited_user_id); 