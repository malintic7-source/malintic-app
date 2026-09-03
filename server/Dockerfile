FROM node:22-alpine

WORKDIR /usr/src/app

ENV NODE_ENV=production

COPY package.json ./

RUN npm install --omit=dev --no-audit --no-fund && \
    npm cache clean --force

COPY server.js postgres.js initial_database.json* ./

RUN mkdir -p /data

EXPOSE 5001

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:5001/api/health || exit 1

CMD ["node", "server.js"]
