CREATE TABLE users (
    id serial,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    age INTEGER,
    address VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);