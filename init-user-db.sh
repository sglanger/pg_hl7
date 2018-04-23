#!/bin/bash
set -e

# from https://hub.docker.com/_/postgres/    "How to Extend"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE USER mirth;
    CREATE DATABASE mirthdb;
    GRANT ALL PRIVILEGES ON DATABASE mirthdb TO mirth;

    CREATE USER edge;
    CREATE DATABASE rsnadb;
    GRANT ALL PRIVILEGES ON DATABASE rsnadb TO edge;
EOSQL
