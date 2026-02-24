FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY .env.example ./.env.example

RUN mkdir -p /app/data /app/uploads

EXPOSE 3000

CMD ["node", "src/server.js"]
