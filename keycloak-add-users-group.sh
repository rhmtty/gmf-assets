#!/bin/bash

CONTAINER={container-name}
REALM={realm-name}
GROUP_ID={group-id}

while read USER
do
 USER_ID=$(docker exec $CONTAINER /opt/keycloak/bin/kcadm.sh get users -r $REALM -q username=$USER --fields id | jq -r '.[0].id')

 if [ ! -z "$USER_ID" ]; then
   docker exec $CONTAINER /opt/keycloak/bin/kcadm.sh update users/$USER_ID/groups/$GROUP_ID -r $REALM -n

   echo "Added $USER"
 else
   echo "User $USER not found"
 fi

done < users.csv
