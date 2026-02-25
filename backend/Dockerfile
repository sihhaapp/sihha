FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY scripts ./scripts
COPY .env.example ./.env.example

RUN mkdir -p /app/uploads

EXPOSE 3000

CMD ["node", "src/server.js"]
