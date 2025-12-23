#!/usr/bin/env bash
# Configure MinIO to make thumbnails publicly readable
set -e

cd "$(dirname "$0")/.."

if [ -f deploy/.env ]; then
    set -a
    source deploy/.env
    set +a
fi

BUCKET="${S3_BUCKET:-excalidraw}"

# Wait for MinIO to be ready
sleep 2

# Configure public access for thumbnails folder
docker exec deploy-minio-1 sh -c '
    ACCESS_KEY=$(cat /run/secrets/minio_access_key)
    SECRET_KEY=$(cat /run/secrets/minio_secret_key)
    mc alias set local http://localhost:9000 "$ACCESS_KEY" "$SECRET_KEY" 2>/dev/null || true
    mc anonymous set download local/'"$BUCKET"'/thumbnails 2>/dev/null || true
' > /dev/null 2>&1 && echo "   ✅ Thumbnails folder configured for public read" || echo "   ⚠️  Could not configure thumbnails (bucket may not exist yet)"

