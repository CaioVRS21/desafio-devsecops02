FROM node:24-alpine

WORKDIR /app/src

COPY app/package*.json ./

RUN npm ci --omit=dev

COPY app/src/server.js .

EXPOSE 3000

CMD ["node", "server.js"]