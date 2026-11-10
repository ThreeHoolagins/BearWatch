# Builds the React SPA and bakes it into a Caddy image.
# Build context is the repo root (see compose.prod.yaml).
FROM node:22-alpine AS spa
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM caddy:2-alpine
COPY infra/caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=spa /app/dist /srv/app
