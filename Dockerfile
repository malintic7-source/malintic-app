# Stage 1: Build Flutter app
FROM cirruslabs/flutter:3.24.0 AS builder

WORKDIR /app

# Copy source code
COPY . .

# Some legacy projects do not carry the generated platform metadata in the
# Docker build context. Generate the web runner inside the disposable builder.
RUN flutter create . --platforms=web

# Get dependencies after platform configuration has been generated.
RUN flutter pub get

# Build web app
RUN flutter build web --release --no-web-resources-cdn

# Stage 2: Runtime with nginx
FROM nginx:alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built web files from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
