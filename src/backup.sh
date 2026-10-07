#! /bin/sh

set -eu
set -o pipefail

source ./env.sh

conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE"

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
s3_uri="s3://${S3_BUCKET}/${S3_PREFIX}/${POSTGRES_DATABASE}_${timestamp}.dump"
if [ -n "$PASSPHRASE" ]; then
  s3_uri="${s3_uri}.gpg"
fi
partial_uri="${s3_uri}.partial"

encrypt() {
  if [ -n "$PASSPHRASE" ]; then
    gpg --symmetric --batch --passphrase "$PASSPHRASE" --compress-algo none
  else
    cat
  fi
}

uploaded=no
cleanup() {
  if [ "$uploaded" != "yes" ]; then
    echo "Backup failed, removing partial upload..."
    aws $aws_args s3 rm "$partial_uri" || true
  fi
}
trap cleanup EXIT

# Streamed, so nothing touches the container disk. The database size is an
# upper bound for the compressed dump; aws needs it to size multipart chunks
# once the stream exceeds 50GB.
expected_size=$(psql $conn_opts -Atc "select pg_database_size(current_database())")

echo "Streaming backup of $POSTGRES_DATABASE database to $S3_BUCKET..."
pg_dump --format=custom $conn_opts $PGDUMP_EXTRA_OPTS \
  | encrypt \
  | aws $aws_args s3 cp --expected-size "$expected_size" - "$partial_uri"

aws $aws_args s3 mv "$partial_uri" "$s3_uri"
uploaded=yes

echo "Backup complete."

if [ -n "$BACKUP_KEEP_DAYS" ]; then
  sec=$((86400*BACKUP_KEEP_DAYS))
  date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET..."
  aws $aws_args s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}" \
    --query "${backups_query}" \
    --output text \
    | xargs -n1 -t -I 'KEY' aws $aws_args s3 rm s3://"${S3_BUCKET}"/'KEY'
  echo "Removal complete."
fi
