FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
RUN npm install -g tsx nodemon
COPY . .
EXPOSE 4000
CMD ["nodemon", "--exec", "tsx", "src/index.ts"]
