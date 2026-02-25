#!/bin/bash

set -e

echo "===== Remove dangling (<none>) images ====="
docker image prune -f

echo ""
echo "===== Keep latest 3 images per repository ====="

# Get unique repositories (exclude <none>)
repos=$(docker images --format "{{.Repository}}" | grep -v "<none>" | sort -u)

for repo in $repos; do
  echo ""
  echo "Processing repository: $repo"

  # Collect image IDs with creation time
  mapfile -t images < <(
    docker images "$repo" --format "{{.ID}}" | while read id; do
      echo "$(docker inspect -f '{{.Created}}' $id) $id"
    done | sort -r | awk '{print $2}'
  )

  # Remove images older than latest 3
  for ((i=3; i<${#images[@]}; i++)); do
    img=${images[$i]}
    echo "Removing old image: $img"
    echo docker rmi "$img" || true
  done

done

echo ""
echo "===== Cleanup completed ====="
