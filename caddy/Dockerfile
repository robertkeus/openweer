# Custom Caddy build with the rate-limit plugin baked in.
# Upstream `caddy:2.8-alpine` doesn't ship the rate-limit module; we use
# the official `caddy:builder` image to xcaddy-compile a binary that does.
FROM caddy:2.8-builder AS builder
RUN xcaddy build \
    --with github.com/mholt/caddy-ratelimit

FROM caddy:2.8-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
