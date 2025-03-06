#!/usr/bin/env bash

set -o errexit

echo "Setting up PostgreSQL on Alpine Linux..."

PGHOST=/postgres-volume/run/postgresql
PGDATA="$PGHOST/data"

# If the project has more env variables then PGHOST, PGDATABASE, PGUSERNAME and PGPASSWORD, add them here with fake values between the start and end echo statements
echo "Environment variables:"
echo '{ "NEXTAUTH_URL": "https://myapp.com", "APP_SECRET_KEY": "supersecretkey", "CLOUDINARY_CLOUD_NAME": "cloudname", "CLOUDINARY_API_KEY": "apikey", "CLOUDINARY_API_SECRET": "apisecret}'

echo "Adding exclusive data directory permissions..."
chmod 0700 "$PGDATA"

echo "Initializing database cluster..."
initdb -D "$PGDATA"

echo "Prepending volume path to Unix Domain Socket path..."
sed -i "s/#unix_socket_directories = '\/run\/postgresql'/unix_socket_directories = '\/postgres-volume\/run\/postgresql'/g" "$PGDATA/postgresql.conf"

echo "Enabling connections on all available IP interfaces..."
echo "listen_addresses='*'" >> "$PGDATA/postgresql.conf"

echo "Starting PostgreSQL with pg_ctl..."
pg_ctl start --pgdata="$PGDATA" > "/tmp/postgres_startup.log" 2>&1

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
