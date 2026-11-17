# Image dùng chung cho api và worker.
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY prisma ./prisma
COPY scripts ./scripts
COPY prisma.config.ts ./
RUN npm ci
COPY tsconfig*.json nest-cli.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:24-alpine
# ffmpeg cho worker xử lý video sẽ thêm ở M5
RUN apk add --no-cache openssl tini
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/dist/scripts ./dist/scripts
COPY --from=build /app/dist/prisma ./dist/prisma
COPY --from=build /app/prisma.config.ts ./
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/main.js"]
