# FROM nginx:alpine

# RUN rm -rf /usr/share/nginx/html/*

# COPY . /usr/share/nginx/html

# EXPOSE 80

# CMD ["nginx", "-g", "daemon off;"]
FROM nginx:alpine

RUN apk update && apk upgrade

RUN rm -rf /usr/share/nginx/html/*

COPY . /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]