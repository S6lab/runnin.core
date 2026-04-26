FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
# Instala todas as deps (incluindo dev) para compilar
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npx tsc && npx tsc-alias

FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
# Instala apenas deps de produção
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
EXPOSE 8080
CMD ["node", "dist/main.js"]
