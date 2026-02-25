#!/usr/bin/env bash

set -Eeuo pipefail

DIR_PATH="/home/gmfadm/DevOps/clean-up-image-logs"
FILE_PATH="${DIR_PATH}/$(date +%d-%m-%Y).log"
KEEP=3

# Create the directory (and any necessary parent directories)
# The -p flag prevents errors if the directory already exists
mkdir -p "${DIR_PATH}"

echo "===== ENTERPRISE DOCKER CLEANUP START ====="
echo "Keep latest $KEEP tags per repository"
echo ""

# ---------------------------------------
# Get image IDs used by containers
# ---------------------------------------
echo "Collecting images used by containers..."
USED_IMAGES=$(docker ps -a --format '{{.Image}}' | sort -u)

# ---------------------------------------
# Iterate repositories
# ---------------------------------------
repos=$(docker images --format '{{.Repository}}' | grep -v '<none>' | sort -u)

for repo in $repos; do
  echo ""
  echo ">>> Repository: $repo"

  # Build tag list with creation time
  mapfile -t tag_lines < <(
    docker images "$repo" --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
    | grep -v '<none>' \
    | while read tag id; do
        created=$(docker inspect -f '{{.Created}}' "$id")
        echo "$created $tag $id"
      done \
    | sort -r
  )

  total=${#tag_lines[@]}
  echo "Total tags: $total"

  if (( total <= KEEP )); then
    echo "Nothing to cleanup"
    continue
  fi

  # Process older tags
  for ((i=KEEP; i<total; i++)); do
    line="${tag_lines[$i]}"
    tag=$(echo "$line" | awk '{print $2}')
    id=$(echo "$line" | awk '{print $3}')

    # Skip if used by container
    if echo "$USED_IMAGES" | grep -q "$tag"; then
      echo "SKIP (used by container): $tag"
      continue
    fi

    echo "Removing tag: $tag"
    docker image rm "$tag" || true

    # ---------------------------------------
    # Create logs inside /home/gmfadm/DevOps/clean-up-image-logs
    # ---------------------------------------
    echo "$(date +'%Y-%m-%d %H:%M:%S') $tag DELETED" >> "$FILE_PATH"
    echo "[------- Text has been appended to $FILE_PATH -------]"
  done
done

# ---------------------------------------
# Remove dangling layers
# ---------------------------------------
echo ""
echo "Removing dangling images..."
docker image prune -f

# ---------------------------------------
# Create logs inside /home/gmfadm/DevOps/clean-up-image-logs
# ---------------------------------------
echo "$(date +'%Y-%m-%d %H:%M:%S') $tag DELETED" >> "$FILE_PATH"
echo "Text has been appended to $FILE_PATH"

echo ""
echo "===== CLEANUP FINISHED ====="
