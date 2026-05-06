FROM nginx:1.27-alpine

ARG APP_ENV=TEST
ENV APP_ENV=${APP_ENV}

COPY index.html /usr/share/nginx/html/index.template.html

RUN envsubst '${APP_ENV}' < /usr/share/nginx/html/index.template.html > /usr/share/nginx/html/index.html \
    && rm /usr/share/nginx/html/index.template.html

EXPOSE 80
