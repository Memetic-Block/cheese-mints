# Stage 1: Build
FROM node:24-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy source files
COPY tsconfig.json ./
COPY scripts/ ./scripts/
COPY src/ ./src/

# Bundle Lua contracts
RUN npm run bundle

# Stage 2: Runtime
FROM node:24-alpine AS runtime

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Install tsx for script execution
RUN npm install tsx

# Copy bundled output from builder
COPY --from=builder /app/dist/ ./dist/

# Copy scripts for runtime execution
COPY --from=builder /app/scripts/ ./scripts/
COPY --from=builder /app/tsconfig.json ./

# Set default command (can be overridden)
CMD ["npx", "tsx"]
