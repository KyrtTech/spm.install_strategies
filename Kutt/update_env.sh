#!/bin/sh
CONFIG_FILE=".env"

declare -A env_vars=(
    ["DATABASE_PORT"]="DB_PORT"
    ["DATABASE_HOST"]="DB_HOST"
    ["DATABASE_PASSWORD"]="DB_PASSWORD"
    ["DATABASE_NAME"]="DB_NAME"
    ["DATABASE_USERNAME"]="DB_USER"
    ["REDIS_HOST"]="REDIS_HOST"
    ["REDIS_PORT"]="REDIS_PORT"
    ["REDIS_PASSWORD"]="REDIS_PASSWORD"
    ["PORT"]="PORT"
)

export PORT=8080

# Function to update the config file
update_config() {
    local key=$1
    local value=$2

    # Use sed to find and replace the key with the new value in the config file
    sed -i.bak "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
}

for key in "${!env_vars[@]}"; do
    value=$(eval echo \$$key)
    update_config "${env_vars[$key]}" "$value"
done
