# Rails API image. Stages:
#   dev   - used by compose.yaml; code is bind-mounted, gems live in a volume
#   prod  - used by compose.prod.yaml; self-contained, runs as a non-root user
# Builds for amd64 and arm64 (Raspberry Pi 4).

FROM ruby:3.3-slim AS base
WORKDIR /rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libvips42 && \
    rm -rf /var/lib/apt/lists/*
ENV BUNDLE_PATH=/usr/local/bundle

FROM base AS buildtools
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config libyaml-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# ---------- development ----------
FROM buildtools AS dev
ENV RAILS_ENV=development
EXPOSE 3000
CMD ["bash", "-c", "bundle check || bundle install; rm -f tmp/pids/server.pid; bin/rails db:prepare && bin/rails server -b 0.0.0.0"]

# ---------- production build ----------
FROM buildtools AS build
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT="development:test"
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache
COPY . .
RUN bundle exec bootsnap precompile app/ lib/

# ---------- production runtime ----------
FROM base AS prod
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT="development:test"
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN useradd --create-home --shell /bin/bash rails && \
    mkdir -p storage tmp log && chown -R rails:rails storage tmp log db
USER rails
EXPOSE 3000
CMD ["bash", "-c", "bin/rails db:prepare && bin/rails server -b 0.0.0.0"]
