# Multi-stage build for WhereWeAre Phoenix application
# Runtime base: Debian Bookworm Slim (stable, secure, compatible)

# --- Build Stage ---
FROM elixir:1.19-slim AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Prepare build directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Copy dependency files first for better layer caching
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/runtime.exs ./config/

# Fetch and compile dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY lib ./lib
COPY priv ./priv
COPY assets ./assets

# Build assets
RUN mix assets.deploy

# Compile application
RUN mix compile

# Build release
RUN mix release

# --- Runtime Stage ---
FROM elixir:1.19-slim

# Install runtime dependencies only
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -r -s /bin/false -d /app -M appuser

WORKDIR /app

# Copy release from builder stage
COPY --from=builder --chown=appuser:appuser /app/_build/prod/rel/where_we_are ./

USER appuser

ENV HOME=/app
ENV MIX_ENV=prod

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD bin/where_we_are ping || exit 1

CMD ["bin/where_we_are", "start"]
