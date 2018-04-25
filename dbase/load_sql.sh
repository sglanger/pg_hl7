#!/bin/bash

#mv rsnadb.sql /docker-entrypoint-initdb.d/
psql -U edge -d rsnadb < /rsnadb.sql

