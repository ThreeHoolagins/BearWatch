# Rails API + Solid Queue worker image (same image, different command).
# Requires the Rails app scaffolded into backend/ (Phase 1).
FROM ruby:3.3-slim AS base
WORKDIR /rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libvips42 default-mysql-client curl && \
    rm -rf /var/lib/apt/lists/*

FROM base AS build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential default-libmysqlclient-dev git pkg-config && \
    rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4
COPY . .

FROM base
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN useradd --create-home --shell /bin/bash rails && \
    mkdir -p storage/uploads storage/media tmp log && \
    chown -R rails:rails storage tmp log
USER rails
EXPOSE 3000
