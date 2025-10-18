FROM alpine:edge

WORKDIR /app

COPY setup.sh /app/setup.sh
COPY launch.sh /app/launch.sh

RUN chmod +x /app/setup.sh /app/launch.sh

CMD ["/app/setup.sh"]