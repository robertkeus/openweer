# syntax=docker/dockerfile:1.7

# ---------- deps & build ----------
FROM node:26-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

FROM node:26-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build && npm prune --omit=dev

# ---------- runtime ----------
FROM node:26-alpine AS runtime
WORKDIR /app
RUN addgroup -g 1001 openweer && adduser -D -u 1001 -G openweer openweer

COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/build ./build

USER openweer
EXPOSE 3000

# react-router-serve listens on $PORT (default 3000).
ENV PORT=3000
CMD ["npm", "run", "start"]
