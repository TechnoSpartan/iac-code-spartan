# Multi-stage build for static React/Vue/Vite application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the application
# This works for React (CRA), Vite, Next.js static export
RUN npm run build

# Production stage - Nginx to serve static files
FROM nginx:alpine

# Copy built files from builder stage
# Adjust the source path based on your build output:
# - React (CRA): /app/build
# - Vite/Vue: /app/dist
# - Next.js: /app/out
COPY --from=builder /app/build /usr/share/nginx/html

# Copy custom nginx configuration if needed
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
