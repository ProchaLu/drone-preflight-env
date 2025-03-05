#!/usr/bin/env bash

set -o errexit

echo "Setting up PostgreSQL on Alpine Linux..."

PGHOST=/postgres-volume/run/postgresql
PGDATA="$PGHOST/data"

echo "=== ENV_VARS_START ==="
echo "NEXTAUTH_URL=https://example.com"
echo "NEXTAUTH_SECRET=supersecret"
echo "CLOUDINARY_CLOUD_NAME=cloudname"
echo "CLOUDINARY_API_KEY=apikey"
echo "CLOUDINARY_API_SECRET=apisecret"
echo "=== ENV_VARS_END ==="

echo "Adding exclusive data directory permissions..."
chmod 0700 "$PGDATA"

echo "Initializing database cluster..."
initdb -D "$PGDATA"

echo "Prepending volume path to Unix Domain Socket path..."
sed -i "s/#unix_socket_directories = '\/run\/postgresql'/unix_socket_directories = '\/postgres-volume\/run\/postgresql'/g" "$PGDATA/postgresql.conf"

echo "Enabling connections on all available IP interfaces..."
echo "listen_addresses='*'" >> "$PGDATA/postgresql.conf"

echo "Starting PostgreSQL with pg_ctl..."
pg_ctl start -D "$PGDATA" > /dev/null

echo "Checking PostgreSQL status..."
pg_ctl status -D "$PGDATA"

echo "Creating database, user and schema..."
psql -U postgres postgres << SQL
  CREATE DATABASE $PGDATABASE;
  CREATE USER $PGUSERNAME WITH ENCRYPTED PASSWORD '$PGPASSWORD';
  GRANT ALL PRIVILEGES ON DATABASE $PGDATABASE TO $PGUSERNAME;
  \\connect $PGDATABASE
  CREATE SCHEMA $PGUSERNAME AUTHORIZATION $PGUSERNAME;
SQL

echo "PostgreSQL setup complete."
