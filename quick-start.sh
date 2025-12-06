#!/bin/bash

# HotDog 快速启动脚本
# 用法: ./quick-start.sh

set -e

echo "=========================================="
echo "  HotDog 热点事件提取系统 - 快速启动"
echo "=========================================="
echo ""

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "错误: Docker 未运行，请先启动 Docker"
    exit 1
fi

# 检查是否存在 .env 文件
if [ ! -f .env ]; then
    echo "提示: 未找到 .env 文件，使用默认配置"
    echo "如需自定义配置，请复制 env.example 为 .env 并修改"
    echo ""
fi

# 构建镜像（如果需要）
echo "步骤 1: 检查并构建镜像..."
if ! docker images | grep -q "hotdog-postgres-with-plugins.*18.0"; then
    echo "  构建 PostgreSQL 镜像（这可能需要几分钟）..."
    cd postgres-build-dir && ./build.sh && cd ..
else
    echo "  ✓ PostgreSQL 镜像已存在"
fi

if ! docker images | grep -q "hotdog-app.*latest"; then
    echo "  构建 Java 应用镜像..."
    docker build -t hotdog-app:latest -f docker/Dockerfile .
else
    echo "  ✓ Java 应用镜像已存在"
fi

echo ""

# 启动服务
echo "步骤 2: 启动服务..."
cd docker && docker-compose up -d && cd ..

echo ""
echo "等待服务启动..."
sleep 10

# 检查服务状态
echo ""
echo "步骤 3: 检查服务状态..."
cd docker && docker-compose ps && cd ..

echo ""
echo "=========================================="
echo "  服务启动完成！"
echo "=========================================="
echo ""
echo "访问地址:"
echo "  - API 文档: http://localhost:${APP_PORT:-8080}/swagger-ui.html (如果配置了)"
echo "  - 健康检查: http://localhost:${APP_PORT:-8080}/actuator/health"
echo ""
echo "数据库连接:"
echo "  - 主机: localhost"
echo "  - 端口: ${POSTGRES_PORT:-5433}"
echo "  - 数据库: ${POSTGRES_DB:-hotdog}"
echo "  - 用户: ${POSTGRES_USER:-postgres}"
echo ""
echo "常用命令:"
echo "  - 查看日志: cd docker && docker-compose logs -f"
echo "  - 停止服务: cd docker && docker-compose down"
echo "  - 重启服务: cd docker && docker-compose restart"
echo "  - 或使用 Makefile: make up, make down, make logs"
echo ""
echo "查看详细日志:"
echo "  cd docker && docker-compose logs -f app"
echo "  cd docker && docker-compose logs -f postgres"
echo ""
