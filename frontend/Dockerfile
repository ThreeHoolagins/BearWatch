# React SPA (Vite). Requires frontend/ scaffolded (Phase 1).
FROM node:22-alpine AS dev
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

FROM dev AS build
RUN npm run build

# Final stage just holds the static build; Caddy serves it.
FROM alpine:3.20 AS dist
COPY --from=build /app/dist /dist
