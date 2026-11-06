FROM node:24-alpine

WORKDIR /app

COPY app/package*.json ./

RUN npm ci --omit=dev

COPY --chown=node:node app/src ./src

ENV NODE_ENV=production

USER node

EXPOSE 3000

CMD ["node", "src/server.js"]