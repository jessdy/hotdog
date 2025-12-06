.PHONY: help build build-postgres build-app up down restart logs clean

# 默认目标
help:
	@echo "HotDog 项目 Docker 管理命令"
	@echo ""
	@echo "可用命令:"
	@echo "  make build-postgres  - 构建 PostgreSQL 镜像"
	@echo "  make build-app        - 构建 Java 应用镜像"
	@echo "  make build           - 构建所有镜像"
	@echo "  make up              - 启动所有服务"
	@echo "  make up-dev          - 启动开发环境（包含 app-dev）"
	@echo "  make down            - 停止所有服务"
	@echo "  make restart         - 重启所有服务"
	@echo "  make logs             - 查看所有服务日志"
	@echo "  make logs-postgres   - 查看 PostgreSQL 日志"
	@echo "  make logs-app         - 查看应用日志"
	@echo "  make clean            - 清理所有容器和镜像"
	@echo "  make clean-data       - 清理数据目录（危险！）"

# 构建 PostgreSQL 镜像
build-postgres:
	@echo "构建 PostgreSQL 镜像..."
	cd postgres-build-dir && ./build.sh

# 构建 Java 应用镜像
build-app:
	@echo "构建 Java 应用镜像..."
	docker build -t hotdog-app:latest -f docker/Dockerfile .

# 构建所有镜像
build: build-postgres build-app

# 启动所有服务
up:
	@echo "启动所有服务..."
	cd docker && docker-compose up -d
	@echo "等待服务启动..."
	@sleep 5
	@echo "服务状态:"
	cd docker && docker-compose ps

# 启动开发环境
up-dev:
	@echo "启动开发环境..."
	cd docker && docker-compose --profile dev up -d
	@echo "等待服务启动..."
	@sleep 5
	@echo "服务状态:"
	cd docker && docker-compose ps

# 停止所有服务
down:
	@echo "停止所有服务..."
	cd docker && docker-compose down

# 重启所有服务
restart: down up

# 查看所有服务日志
logs:
	cd docker && docker-compose logs -f

# 查看 PostgreSQL 日志
logs-postgres:
	cd docker && docker-compose logs -f postgres

# 查看应用日志
logs-app:
	cd docker && docker-compose logs -f app

# 清理所有容器和镜像
clean:
	@echo "清理容器和镜像..."
	cd docker && docker-compose down -v --rmi local
	@echo "✓ 清理完成"

# 清理数据目录（危险操作）
clean-data:
	@echo "警告: 这将删除所有数据库数据！"
	@read -p "确认删除? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@echo "删除数据目录..."
	rm -rf postgres-data
	@echo "✓ 数据目录已删除"
