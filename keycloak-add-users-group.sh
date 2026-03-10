#!/bin/bash

CONTAINER=$1
REALM=$2
GROUP_ID=$3
USER_FILE=$4

if [ -z "$CONTAINER" ] || [ -z "$REALM" ] || [ -z "$GROUP_ID" ] || [ -z "$USER_FILE" ]; then
  echo "Usage: $0 <container> <realm> <group_id> <user_file>"
  exit 1
fi

while read USER
do
  USER_ID=$(docker exec $CONTAINER \
  /opt/keycloak/bin/kcadm.sh get users -r $REALM -q username=$USER --fields id \
  | jq -r '.[0].id')

  if [ "$USER_ID" != "null" ] && [ ! -z "$USER_ID" ]; then
    docker exec $CONTAINER \
    /opt/keycloak/bin/kcadm.sh update users/$USER_ID/groups/$GROUP_ID -r $REALM -n

    echo "Added $USER to group"
  else
    echo "User $USER not found"
  fi

done < "$USER_FILE"
