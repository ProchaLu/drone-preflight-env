#!/usr/bin/env bash

# Exit if any command fails
set -o errexit

echo "Setting up PostgreSQL on Alpine Linux..."

export PGHOST=${PGHOST:-"/postgres-volume/run/postgresql"}
export PGDATA="$PGHOST/data"

export PGDATABASE=${PGDATABASE:-"default_db"}
export PGUSERNAME=${PGUSERNAME:-"default_user"}
export PGPASSWORD=${PGPASSWORD:-"default_pass"}

export NEXTAUTH_URL=${NEXTAUTH_URL:-"default_url"}
export NEXTAUTH_SECRET=${NEXTAUTH_SECRET:-"default_secret"}
export CLOUDINARY_CLOUD_NAME=${CLOUDINARY_CLOUD_NAME:-"default_cloud"}
export CLOUDINARY_API_KEY=${CLOUDINARY_API_KEY:-"default_api_key"}
export CLOUDINARY_API_SECRET=${CLOUDINARY_API_SECRET:-"default_api_secret"}

# Ensure the directory exists
mkdir -p /preflight/project-to-check

# Create .env file for dotenv-safe
cat <<EOF > /preflight/project-to-check/.env
PGHOST=$PGHOST
PGDATABASE=$PGDATABASE
PGUSERNAME=$PGUSERNAME
PGPASSWORD=$PGPASSWORD
NEXTAUTH_URL=$NEXTAUTH_URL
NEXTAUTH_SECRET=$NEXTAUTH_SECRET
CLOUDINARY_CLOUD_NAME=$CLOUDINARY_CLOUD_NAME
CLOUDINARY_API_KEY=$CLOUDINARY_API_KEY
CLOUDINARY_API_SECRET=$CLOUDINARY_API_SECRET
EOF

chmod 600 /preflight/project-to-check/.env


echo "Adding exclusive data directory permissions for postgres user..."
chmod 0700 "$PGDATA"

echo "Initializing database cluster..."
initdb -D "$PGDATA"

echo "Prepending volume path to Unix Domain Socket path..."
sed -i "s/#unix_socket_directories = '\/run\/postgresql'/unix_socket_directories = '\/postgres-volume\/run\/postgresql'/g" "$PGDATA/postgresql.conf"

echo "Enabling connections on all available IP interfaces..."
echo "listen_addresses='*'" >> "$PGDATA/postgresql.conf"

echo "Starting PostgreSQL..."
pg_ctl start -D "$PGDATA"

echo "Creating database, user and schema..."
psql -U postgres postgres << SQL
  CREATE DATABASE $PGDATABASE;
  CREATE USER $PGUSERNAME WITH ENCRYPTED PASSWORD '$PGPASSWORD';
  GRANT ALL PRIVILEGES ON DATABASE $PGDATABASE TO $PGUSERNAME;
  \\connect $PGDATABASE
  CREATE SCHEMA $PGUSERNAME AUTHORIZATION $PGUSERNAME;
SQL
