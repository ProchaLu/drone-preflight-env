#!/usr/bin/env bash

# Exit if any command fails
set -o errexit

echo "Setting up PostgreSQL on Alpine Linux..."

# ✅ Use environment variables set by the preflight script
export PGHOST="${PGHOST:-localhost}"
export PGDATABASE="${PGDATABASE:-project_to_check}"
export PGUSERNAME="${PGUSERNAME:-project_to_check}"
export PGPASSWORD="${PGPASSWORD:-project_to_check}"

# ✅ Ensure additional required environment variables are set
export NEXTAUTH_URL="${NEXTAUTH_URL:-mycode}"
export NEXTAUTH_SECRET="${NEXTAUTH_SECRET:-mycode}"
export CLOUDINARY_CLOUD_NAME="${CLOUDINARY_CLOUD_NAME:-mycode}"
export CLOUDINARY_API_KEY="${CLOUDINARY_API_KEY:-mycode}"
export CLOUDINARY_API_SECRET="${CLOUDINARY_API_SECRET:-mycode}"

echo "Adding exclusive data directory permissions for postgres user..."
chmod 0700 "/postgres-volume/run/postgresql/data"

echo "Initializing database cluster..."
initdb -D "/postgres-volume/run/postgresql/data"

echo "Prepending volume path to Unix Domain Socket path..."
sed -i "s|#unix_socket_directories = '/run/postgresql'|unix_socket_directories = '/postgres-volume/run/postgresql'|g" "/postgres-volume/run/postgresql/data/postgresql.conf"

echo "Enabling connections on all available IP interfaces..."
echo "listen_addresses='*'" >> "/postgres-volume/run/postgresql/data/postgresql.conf"

echo "Starting PostgreSQL..."
pg_ctl start -D "/postgres-volume/run/postgresql/data"

# ✅ Fix: Wait for PostgreSQL to be fully ready before creating the database
echo "Waiting for PostgreSQL to start accepting connections..."
until psql -U postgres -d postgres -c "SELECT 1" > /dev/null 2>&1; do
  echo "PostgreSQL is starting... waiting..."
  sleep 2
done

echo "PostgreSQL is ready!"

# ✅ Ensure the database is created BEFORE running the readiness check
echo "Creating database, user, and schema..."
psql -U postgres -d postgres <<SQL
  CREATE DATABASE $PGDATABASE;
  CREATE USER $PGUSERNAME WITH ENCRYPTED PASSWORD '$PGPASSWORD';
  GRANT ALL PRIVILEGES ON DATABASE $PGDATABASE TO $PGUSERNAME;
  \connect $PGDATABASE
  CREATE SCHEMA $PGUSERNAME AUTHORIZATION $PGUSERNAME;
SQL

echo "Database setup complete!"
