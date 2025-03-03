#!/usr/bin/env bash

# Exit if any command fails
set -o errexit

echo "Setting up PostgreSQL on Alpine Linux..."

export PGHOST="/postgres-volume/run/postgresql"
export PGDATA="$PGHOST/data"

# Ensure directory exists
mkdir -p /preflight/project-to-check

# Change ownership to the current user (avoid root-only access)
chown "$(whoami)" /preflight/project-to-check || echo "Skipping chown"

# Allow writing to the directory
chmod 777 /preflight/project-to-check || echo "Skipping chmod"

# Export environment variables globally so they persist
export PGDATABASE="mycode"
export PGUSERNAME="mycode"
export PGPASSWORD="mycode"
export NEXTAUTH_URL="mycode"
export NEXTAUTH_SECRET="mycode"
export CLOUDINARY_CLOUD_NAME="mycode"
export CLOUDINARY_API_KEY="mycode"
export CLOUDINARY_API_SECRET="mycode"

# Create a .env file to satisfy dotenv-safe
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

# Ensure .env is readable by the correct user
chmod 644 /preflight/project-to-check/.env || echo "Skipping chmod"

echo "Database setup complete!"

# Export variables to the shell so they are available in subsequent scripts
printenv | grep -E "PGHOST|PGDATABASE|PGUSERNAME|PGPASSWORD|NEXTAUTH_URL|NEXTAUTH_SECRET|CLOUDINARY_CLOUD_NAME|CLOUDINARY_API_KEY|CLOUDINARY_API_SECRET" >> /etc/environment
echo "Environment variables exported globally"

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
