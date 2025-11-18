--liquibase formatted sql

--changeset baby-names:1
--comment: Create baby_names table with indexes

CREATE TABLE IF NOT EXISTS baby_names (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    rank INTEGER NOT NULL,
    count INTEGER NOT NULL,
    year INTEGER NOT NULL DEFAULT 2024
);

CREATE INDEX idx_name ON baby_names(name);
CREATE INDEX idx_rank ON baby_names(rank);

--rollback DROP TABLE IF EXISTS baby_names CASCADE;
