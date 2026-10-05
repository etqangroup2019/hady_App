CREATE TABLE IF NOT EXISTS subs (
  endpoint  TEXT PRIMARY KEY,
  created   INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS due (
  endpoint TEXT    NOT NULL,
  t        INTEGER NOT NULL,
  PRIMARY KEY (endpoint, t)
);

CREATE INDEX IF NOT EXISTS due_t ON due (t);
