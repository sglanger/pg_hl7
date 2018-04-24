#!/bin/bash

mv rsnadb.sql /docker-entrypoint-initdb.d/
psql -U edge -d rsnadb < /docker-entrypoint-initdb.d/rsnadb.sql

