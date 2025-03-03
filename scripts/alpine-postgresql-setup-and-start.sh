#!/usr/bin/env bash

# Exit if any command fails
set -o errexit

echo "Setting up PostgreSQL on Alpine Linux..."

export PGHOST="/postgres-volume/run/postgresql"
export PGDATA="$PGHOST/data"

# Ensure directory exists
mkdir -p /preflight/project-to-check || echo "Skipping mkdir"

# Change ownership only if possible
if chown "$(whoami)" /preflight/project-to-check 2>/dev/null; then
  echo "Ownership updated"
else
  echo "Skipping chown: Permission denied"
fi

# Change permissions only if possible
if chmod 777 /preflight/project-to-check 2>/dev/null; then
  echo "Permissions updated"
else
  echo "Skipping chmod: Permission denied"
fi

# Default values for required environment variables
declare -A required_env_vars=(
  [PGHOST]="/postgres-volume/run/postgresql"
  [PGDATABASE]="mycode"
  [PGUSERNAME]="mycode"
  [PGPASSWORD]="mycode"
  [NEXTAUTH_URL]="mycode"
  [NEXTAUTH_SECRET]="mycode"
  [CLOUDINARY_CLOUD_NAME]="mycode"
  [CLOUDINARY_API_KEY]="mycode"
  [CLOUDINARY_API_SECRET]="mycode"
)

# Check if an `.env.example` or `.env` file exists in the project
if [[ -f "/preflight/project-to-check/.env.example" ]]; then
  ENV_FILE="/preflight/project-to-check/.env.example"
elif [[ -f "/preflight/project-to-check/.env" ]]; then
  ENV_FILE="/preflight/project-to-check/.env"
else
  ENV_FILE=""
fi

# If an env file exists, read it and set missing variables
if [[ -n "$ENV_FILE" ]]; then
  echo "Loading environment variables from $ENV_FILE"
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Ignore empty lines and comments
    if [[ -n "$key" && "$key" != \#* ]]; then
      export "$key"="${value:-mycode}"
    fi
  done < "$ENV_FILE"
fi

# Ensure all required variables are set
for key in "${!required_env_vars[@]}"; do
  if [[ -z "${!key}" ]]; then
    export "$key"="${required_env_vars[$key]}"
  fi
done

# Create a .env file
TMP_ENV_FILE="/tmp/.env"
cat <<EOF > "$TMP_ENV_FILE"
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

# Attempt to move the file to /preflight/project-to-check/
if mv "$TMP_ENV_FILE" /preflight/project-to-check/.env 2>/dev/null; then
  echo ".env file created successfully"
else
  echo "Warning: Could not write to /preflight/project-to-check/.env, keeping in /tmp"
fi

echo "Database setup complete!"

# ✅ **Fix: Remove /etc/environment modification**
echo "Skipping /etc/environment modification due to permission issues"

# ✅ **Instead, print environment variables for debugging**
echo "Exported Environment Variables:"
printenv | grep -E "PGHOST|PGDATABASE|PGUSERNAME|PGPASSWORD|NEXTAUTH_URL|NEXTAUTH_SECRET|CLOUDINARY_CLOUD_NAME|CLOUDINARY_API_KEY|CLOUDINARY_API_SECRET"

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
