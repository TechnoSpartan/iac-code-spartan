# Multi-stage build for Storybook
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies for Storybook)
RUN npm ci

# Copy source code
COPY . .

# Build Storybook static site
# This generates static files in storybook-static/
RUN npm run build-storybook

# Production stage - Nginx to serve Storybook
FROM nginx:alpine

# Copy Storybook build from builder stage
COPY --from=builder /app/storybook-static /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
