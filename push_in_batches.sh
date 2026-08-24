#!/bin/bash
# Ajoute et pousse le contenu d'un dossier par lots de taille limitee, avec
# retries, pour contourner un push qui echoue au-dela d'une certaine taille.
set -u
TARGET_DIR="$1"
MAX_BATCH_BYTES=${2:-60000000}  # 60 Mo par lot par defaut
LABEL="$3"

cd "$(dirname "$0")" || exit 1

batch=()
batch_size=0
batch_num=0

push_batch() {
  if [ ${#batch[@]} -eq 0 ]; then return 0; fi
  batch_num=$((batch_num + 1))
  git add -- "${batch[@]}"
  git commit -q -m "Ajout ${LABEL} (lot ${batch_num}, $(( batch_size / 1000000 )) Mo)"
  if [ $? -ne 0 ]; then
    echo "=== Rien a committer pour le lot ${batch_num} (deja fait ?) ==="
    return 0
  fi
  attempt=1
  while [ $attempt -le 3 ]; do
    echo "=== Push lot ${batch_num} (tentative ${attempt}, ${#batch[@]} fichiers) ==="
    if git push origin main; then
      echo "=== Lot ${batch_num} OK ==="
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
  echo "=== ECHEC definitif lot ${batch_num} apres 3 tentatives ==="
  return 1
}

while IFS= read -r -d '' f; do
  sz=$(stat -f "%z" "$f")
  if [ $((batch_size + sz)) -gt "$MAX_BATCH_BYTES" ] && [ ${#batch[@]} -gt 0 ]; then
    push_batch || exit 1
    batch=()
    batch_size=0
  fi
  batch+=("$f")
  batch_size=$((batch_size + sz))
done < <(git ls-files -z --others --exclude-standard -- "$TARGET_DIR")

push_batch || exit 1

echo "=== TERMINE : $LABEL ==="
