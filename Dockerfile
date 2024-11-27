# syntax=docker/dockerfile:1.12
# This image builds an AI-ready PostgreSQL database with TimescaleDB, pgvector, and pgvectorscale extensions

# Global build arguments
ARG CLOUDNATIVEPG_VERSION=16.5-1
ARG POSTGRES_VERSION=16
ARG TIMESCALE_VERSION=2.17.2
ARG PGVECTOR_VERSION=0.8.0
ARG PGVECTORSCALE_VERSION=0.5.1

# Build stage for extensions
FROM ghcr.io/cloudnative-pg/postgresql:${CLOUDNATIVEPG_VERSION} AS builder

ARG CLOUDNATIVEPG_VERSION
ARG POSTGRES_VERSION
ARG TIMESCALE_VERSION
ARG PGVECTOR_VERSION
ARG PGVECTORSCALE_VERSION

USER root
WORKDIR /build

# Install build dependencies using a single layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  libssl-dev \
  openssl \
  pkg-config \
  postgresql-server-dev-${POSTGRES_VERSION}

# Install Timescale with verification
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  . /etc/os-release && \
  curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --batch --yes --dearmor -o /etc/apt/trusted.gpg.d/timescale.gpg && \
  echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/timescaledb.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
  "timescaledb-2-postgresql-${POSTGRES_VERSION}=${TIMESCALE_VERSION}~debian${VERSION_ID}" \
  && rm -rf /var/lib/apt/lists/*

# Build and install pgvector with optimizations
RUN --mount=type=cache,target=/root/.cargo,sharing=locked \
  cd /tmp && \
  git clone --depth 1 -b "v${PGVECTOR_VERSION}" https://github.com/pgvector/pgvector.git && \
  cd pgvector && \
  # Enable parallel compilation
  make -j$(nproc) OPTFLAGS="-march=native" && \
  make install

ENV PATH="/root/.cargo/bin:/root/.rustup/bin:${PATH}"

# Install Rust and cargo-pgrx with caching
RUN --mount=type=cache,target=/root/.cargo,sharing=locked \
  --mount=type=cache,target=/root/.rustup,sharing=locked \
  curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
  cargo install cargo-pgrx --version 0.12.5 --locked && \
  cargo pgrx init --pg${POSTGRES_VERSION} pg_config

# Build and install pgvectorscale with optimizations
RUN --mount=type=cache,target=/root/.cargo,sharing=locked \
  --mount=type=cache,target=/root/.rustup,sharing=locked \
  cd /tmp && \
  git clone --depth 1 -b "${PGVECTORSCALE_VERSION}" https://github.com/timescale/pgvectorscale.git && \
  cd pgvectorscale/pgvectorscale && \
  rustup default stable && \
  # Enable architecture-specific optimizations
  if [ "$(uname -m)" = "x86_64" ]; then \
  export RUSTFLAGS="-C target-feature=+avx2,+fma -C opt-level=3"; \
  elif [ "$(uname -m)" = "aarch64" ]; then \
  export RUSTFLAGS="-C target-feature=+neon -C opt-level=3"; \
  fi && \
  cargo pgrx install --release

# Final stage
FROM ghcr.io/cloudnative-pg/postgresql:${CLOUDNATIVEPG_VERSION}

# Copy version arguments for labels
ARG POSTGRES_VERSION
ARG TIMESCALE_VERSION
ARG PGVECTOR_VERSION 
ARG PGVECTORSCALE_VERSION

# Copy only necessary files from builder
COPY --from=builder /usr/lib/postgresql/${POSTGRES_VERSION}/ /usr/lib/postgresql/${POSTGRES_VERSION}/
COPY --from=builder /usr/share/postgresql/${POSTGRES_VERSION}/ /usr/share/postgresql/${POSTGRES_VERSION}/

# Set secure user
USER 26:26

# Add standardized OCI labels
LABEL org.opencontainers.image.title="AI-ready PostgreSQL Database" \
  org.opencontainers.image.description="AI ready PostgreSQL database image with Barman Cloud based on TimescaleDB, pgvector and pgvectorscale extensions for CloudNativePG" \
  org.opencontainers.image.source="https://github.com/osventuresllc/cnpg-ai" \
  org.opencontainers.image.version="${POSTGRES_VERSION}-ts${TIMESCALE_VERSION}-pgv${PGVECTOR_VERSION}-pgvs${PGVECTORSCALE_VERSION}" \
  org.opencontainers.image.vendor="O'Shaughnessy Ventures and The CloudNativePG Contributors" \
  org.opencontainers.image.licenses="PostgreSQL" \
  org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  org.opencontainers.image.documentation="https://github.com/osventuresllc/cnpg-ai/blob/main/README.md"
