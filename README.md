# CloudNativePG AI Ready Image

[![Build](https://github.com/osventuresllc/cnpg-ai/actions/workflows/build.yaml/badge.svg)](https://github.com/osventuresllc/cnpg-ai/actions/workflows/build.yaml)
<!--renovate datasource=docker repo=ghcr.io/cloudnative-pg/postgresql -->
[![Version-17.1-1-blue](https://img.shields.io/badge/Version-17.1--1-blue)](https://github.com/cloudnative-pg/cloudnative-pg)
<!--renovate datasource=github-releases repo=timescale/timescaledb -->
[![TimescaleDB-2.17.2-blue](https://img.shields.io/badge/TimescaleDB-2.17.2-blue)](https://github.com/timescale/timescaledb)
<!--renovate datasource=github-releases repo=pgvector/pgvector -->
[![pgvector-0.8.0-blue](https://img.shields.io/badge/pgvector-0.8.0-blue)](https://github.com/pgvector/pgvector)
<!--renovate datasource=github-releases repo=timescale/pgvectorscale -->
[![pgvectorscale-0.5.1-blue](https://img.shields.io/badge/pgvectorscale-0.5.1-blue)](https://github.com/timescale/pgvectorscale)

This repo builds Docker images for [CloudNativePG](https://cloudnative-pg.io/) with the following extensions installed:

- [TimescaleDB](https://timescale.com) for time-series data
- [pgvector](https://github.com/pgvector/pgvector) for vector similarity search
- [pgvectorscale](https://github.com/timescale/pgvectorscale) for scalable vector operations

## Usage

### Docker Compose

```yaml
services:
  postgresql:
    image: ghcr.io/osventuresllc/cnpg-ai:16
    user: root
    command: >
      postgres -c shared_preload_libraries='timescaledb'
    environment:
      POSTGRES_USER: cnpg
      POSTGRES_PASSWORD: cnpg
      POSTGRES_DB: cnpg
    ports:
      - 5432:5432
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

### CloudNativePG Cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: example
spec:
  instances: 3
  imageName: ghcr.io/osventuresllc/cnpg-ai:16
  postgresql:
    shared_preload_libraries:
      - timescaledb
    bootstrap:
      initdb:
        postInitTemplateSQL:
          - CREATE EXTENSION IF NOT EXISTS timescaledb;
          - CREATE EXTENSION IF NOT EXISTS vector;
          - CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;
```

## Acknowledgements

- [CloudNativePG](https://cloudnative-pg.io/)
- [TimescaleDB](https://timescale.com)
- [pgvector](https://github.com/pgvector/pgvector)
- [pgvectorscale](https://github.com/timescale/pgvectorscale)
- [Original work](https://github.com/clevyr/docker-cloudnativepg-timescale) done by @clevyr to create the CloudNativePG TimescaleDB image and Renovate config
