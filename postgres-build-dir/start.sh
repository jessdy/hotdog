#!/bin/bash

# PostgreSQL 启动脚本
# 端口: 5433
# 镜像: hotdog-postgres-with-plugins:18.0

# 配置参数
CONTAINER_NAME="hotdog-postgres"
IMAGE_NAME="hotdog-postgres-with-plugins:18.0"
PORT="5433"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
DATA_DIR="${DATA_DIR:-./postgres-data}"

# 检查容器是否已存在
if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
    echo "容器 ${CONTAINER_NAME} 已存在"
    read -p "是否删除现有容器并重新创建? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "停止并删除现有容器..."
        docker stop ${CONTAINER_NAME} 2>/dev/null
        docker rm ${CONTAINER_NAME} 2>/dev/null
    else
        echo "启动现有容器..."
        docker start ${CONTAINER_NAME}
        exit 0
    fi
fi

# 创建数据目录
mkdir -p ${DATA_DIR}

# 启动容器
echo "启动 PostgreSQL 容器..."
echo "端口: ${PORT}"
echo "用户: ${POSTGRES_USER}"
echo "数据库: ${POSTGRES_DB}"
echo "数据目录: ${DATA_DIR}"

docker run -d \
    --name ${CONTAINER_NAME} \
    -p ${PORT}:5432 \
    -e POSTGRES_USER=${POSTGRES_USER} \
    -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    -e POSTGRES_DB=${POSTGRES_DB} \
    -v $(pwd)/${DATA_DIR}:/var/lib/postgresql/data \
    ${IMAGE_NAME}

# 等待容器启动
echo "等待 PostgreSQL 启动..."
sleep 5

# 检查容器状态
if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
    echo "✓ PostgreSQL 容器已启动"
    echo "连接信息:"
    echo "  主机: localhost"
    echo "  端口: ${PORT}"
    echo "  用户: ${POSTGRES_USER}"
    echo "  密码: ${POSTGRES_PASSWORD}"
    echo "  数据库: ${POSTGRES_DB}"
    echo ""
    echo "连接命令:"
    echo "  psql -h localhost -p ${PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
    echo ""
    echo "查看日志:"
    echo "  docker logs -f ${CONTAINER_NAME}"
    echo ""
    echo "停止容器:"
    echo "  docker stop ${CONTAINER_NAME}"
else
    echo "✗ 容器启动失败，查看日志:"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

