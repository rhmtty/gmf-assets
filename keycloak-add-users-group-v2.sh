#!/usr/bin/env bash

set -e

BASE_URL=""
REALM=""
GROUP_ID=""
USER_FILE=""
USERNAME=""
PASSWORD=""
PARALLEL=10

usage() {
  echo "Usage:"
  echo "$0 --url <base_url> --realm <realm> --group <group_id> --file <user_file> --user <admin> --pass <password> [--parallel N]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) BASE_URL="$2"; shift 2 ;;
    --realm) REALM="$2"; shift 2 ;;
    --group) GROUP_ID="$2"; shift 2 ;;
    --file) USER_FILE="$2"; shift 2 ;;
    --user) USERNAME="$2"; shift 2 ;;
    --pass) PASSWORD="$2"; shift 2 ;;
    --parallel) PARALLEL="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -z "$BASE_URL" || -z "$REALM" || -z "$GROUP_ID" || -z "$USER_FILE" || -z "$USERNAME" || -z "$PASSWORD" ]]; then
  usage
fi

echo "🔐 Getting admin token..."

TOKEN=$(curl -s \
  -d "client_id=admin-cli" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  -d "grant_type=password" \
  "$BASE_URL/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token')

if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
  echo "❌ Failed to get token"
  exit 1
fi

echo "✅ Token acquired"

add_user() {
  USER=$1

  USER_ID=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/admin/realms/$REALM/users?username=$USER" \
    | jq -r '.[0].id')

  if [[ "$USER_ID" == "null" || -z "$USER_ID" ]]; then
    echo "[WARN] User not found: $USER"
    return
  fi

  # Check if already in group
  EXISTS=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/admin/realms/$REALM/users/$USER_ID/groups" \
    | jq -r ".[] | select(.id==\"$GROUP_ID\") | .id")

  if [[ ! -z "$EXISTS" ]]; then
    echo "[SKIP] $USER already in group"
    return
  fi

  # Add to group
  curl -s -o /dev/null -w "%{http_code}" \
    -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/admin/realms/$REALM/users/$USER_ID/groups/$GROUP_ID" \
    > /dev/null

  echo "[OK] Added $USER"
}

export -f add_user
export BASE_URL REALM GROUP_ID TOKEN

cat "$USER_FILE" | xargs -I {} -P "$PARALLEL" bash -c 'add_user "$@"' _ {}

echo "🎉 Batch completed"
