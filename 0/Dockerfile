# 指定基础镜像
FROM alpine:edge

# 工作目录
WORKDIR /app

# 复制脚本到容器中
COPY setup.sh /app/setup.sh
COPY launch.sh /app/launch.sh

# 赋予脚本执行权限
RUN chmod +x /app/setup.sh /app/launch.sh

# 容器启动时运行 setup.sh
CMD ["/app/setup.sh"]