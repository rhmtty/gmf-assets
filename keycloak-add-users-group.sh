#!/usr/bin/env bash

set -e

CONTAINER=""
REALM=""
GROUP_ID=""
USER_FILE=""
PARALLEL=5

usage() {
  echo "Usage:"
  echo "$0 --container <container> --realm <realm> --group <group_id> --file <user_file> [--parallel N]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --container)
      CONTAINER="$2"
      shift 2
      ;;
    --realm)
      REALM="$2"
      shift 2
      ;;
    --group)
      GROUP_ID="$2"
      shift 2
      ;;
    --file)
      USER_FILE="$2"
      shift 2
      ;;
    --parallel)
      PARALLEL="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$CONTAINER" || -z "$REALM" || -z "$GROUP_ID" || -z "$USER_FILE" ]]; then
  usage
fi

TOTAL=$(wc -l < "$USER_FILE")
COUNT=0

echo "----------------------------------------"
echo "Keycloak Batch Group Assignment"
echo "Container : $CONTAINER"
echo "Realm     : $REALM"
echo "Group ID  : $GROUP_ID"
echo "Users     : $TOTAL"
echo "Parallel  : $PARALLEL"
echo "----------------------------------------"

add_user() {

  USER=$1

  USER_ID=$(docker exec "$CONTAINER" \
  /opt/keycloak/bin/kcadm.sh get users -r "$REALM" -q username="$USER" --fields id \
  | jq -r '.[0].id')

  if [[ "$USER_ID" == "null" || -z "$USER_ID" ]]; then
    echo "[WARN] User not found: $USER"
    return
  fi

  EXISTS=$(docker exec "$CONTAINER" \
  /opt/keycloak/bin/kcadm.sh get users/$USER_ID/groups -r "$REALM" \
  | jq -r ".[] | select(.id==\"$GROUP_ID\") | .id")

  if [[ ! -z "$EXISTS" ]]; then
    echo "[SKIP] $USER already in group"
    return
  fi

  docker exec "$CONTAINER" \
  /opt/keycloak/bin/kcadm.sh update users/$USER_ID/groups/$GROUP_ID -r "$REALM" -n

  echo "[OK] Added $USER"
}

export -f add_user
export CONTAINER REALM GROUP_ID

cat "$USER_FILE" | xargs -I {} -P "$PARALLEL" bash -c 'add_user "$@"' _ {}

echo "Batch process completed"
