# Static site — nginx serves the configurator. No build step (it's plain HTML/JS/CSS).
FROM nginx:alpine
COPY index.html styles.css app.js zip.js /usr/share/nginx/html/
