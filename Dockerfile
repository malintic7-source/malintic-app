FROM node:22-alpine
WORKDIR /app
COPY server/package.json server/package.json
RUN cd server && npm install
COPY server/ server/
EXPOSE 5001
CMD ["node", "server/server.js"]
