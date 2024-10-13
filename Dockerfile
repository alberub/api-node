FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm install pm2 -g
EXPOSE 3000
CMD ["pm2-runtime", "start", "app.js"]
