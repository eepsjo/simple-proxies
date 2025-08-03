FROM alpine:edge

WORKDIR /app

EXPOSE 2777

COPY setup.sh /app/setup.sh
COPY launch.sh /app/launch.sh

RUN chmod +x /app/setup.sh /app/launch.sh

CMD ["/app/setup.sh"]
