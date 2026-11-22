# Introduction

This project provides Docker images to periodically back up a PostgreSQL database to AWS S3, and to restore from the backup as needed.

# Usage

## Backup

```yaml
services:
  postgres:
    image: postgres:19-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password

  backup:
    image: ghcr.io/solectrus/postgres-s3-backup:19
    environment:
      SCHEDULE: '@weekly' # optional
      BACKUP_KEEP_DAYS: 7 # optional
      PASSPHRASE: passphrase # optional
      S3_REGION: region
      S3_ACCESS_KEY_ID: key
      S3_SECRET_ACCESS_KEY: secret
      S3_BUCKET: my-bucket
      S3_PREFIX: backup
      POSTGRES_HOST: postgres
      POSTGRES_DATABASE: dbname
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
```

- Images are tagged by the major PostgreSQL version supported: `15`, `16`, `17`, `18` or `19`.
- The `SCHEDULE` variable determines backup frequency. See go-cron schedules documentation [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules). Omit to run the backup immediately and then exit.
- If `PASSPHRASE` is provided, the backup will be encrypted using GPG.
- Run `docker exec <container name> sh backup.sh` to trigger a backup ad-hoc.
- If `BACKUP_KEEP_DAYS` is set, backups older than this many days will be deleted from S3.
- Set `S3_ENDPOINT` if you're using a non-AWS S3-compatible storage provider.

## Restore

> [!CAUTION]
> DATA LOSS! All database objects will be dropped and re-created.

### ... from latest backup

```sh
docker exec <container name> sh restore.sh
```

### ... from specific backup

```sh
docker exec <container name> sh restore.sh <timestamp>
```

# Development

## Build the image locally

`POSTGRES_VERSION` determines Postgres version.

```sh
DOCKER_BUILDKIT=1 docker build --build-arg POSTGRES_VERSION=19 .
```

## Run a simple test environment with Docker Compose

```sh
cp template.env .env
# fill out your secrets/params in .env
docker compose up -d
```

# Acknowledgements

This project is a fork of @eeshugerman's [postgres-backup-s3](https://github.com/eeshugerman/postgres-backup-s3) repository. Since the original project is no longer maintained, I decided to fork it and merge an important pull request ([#61](https://github.com/eeshugerman/postgres-backup-s3/pull/61)) to add support for PostgreSQL 17+.

The original repository itself is a fork and restructuring of @schickling's [postgres-backup-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-backup-s3) and [postgres-restore-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-restore-s3).
