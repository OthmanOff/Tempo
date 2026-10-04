FROM node:22-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:22-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/build ./
RUN npm ci --omit=dev && npm cache clean --force

EXPOSE 3333

CMD ["sh", "-c", "node ace migration:run --force && exec node bin/server.js"]
