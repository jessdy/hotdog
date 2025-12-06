# Docker 配置目录

本目录包含所有 Docker 相关的配置文件。

## 文件说明

- **docker-compose.yml**：主 Docker Compose 配置文件，定义所有服务
- **Dockerfile**：Java 应用生产环境镜像构建文件
- **Dockerfile.dev**：Java 应用开发环境镜像构建文件（支持热重载）
- **docker-compose.override.yml.example**：开发环境覆盖配置示例
- **.dockerignore**：Docker 构建忽略文件

## 使用方法

### 从项目根目录使用

```bash
# 启动所有服务
cd docker && docker-compose up -d

# 或使用 Makefile（推荐）
make up
```

### 从 docker 目录使用

```bash
cd docker

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 注意事项

- 所有路径都是相对于项目根目录的
- 数据目录 `postgres-data` 位于项目根目录
- 源代码目录 `src` 位于项目根目录
