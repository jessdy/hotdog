#!/bin/bash

# 构建 PostgreSQL 镜像（包含所有扩展）
# 用法: ./build.sh

set -e

IMAGE_NAME="hotdog-postgres-with-plugins:18.0"
DOCKERFILE="Dockerfile.postgres"

echo "开始构建 PostgreSQL 镜像: ${IMAGE_NAME}..."
echo "这可能需要几分钟时间，请耐心等待..."

docker build -t ${IMAGE_NAME} -f ${DOCKERFILE} .

echo ""
echo "✓ 镜像构建完成: ${IMAGE_NAME}"
echo ""
echo "可以使用以下命令启动容器:"
echo "  docker-compose up -d postgres"
echo "  或"
echo "  ./start.sh"