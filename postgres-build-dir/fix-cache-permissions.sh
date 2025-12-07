#!/bin/bash

# 修复 PostgreSQL 容器中的缓存目录权限问题
# 用于解决 sentence-transformers 模型下载时的权限错误

CONTAINER_NAME="${CONTAINER_NAME:-hotdog-postgres}"

echo "修复 PostgreSQL 容器中的缓存目录权限..."
echo "容器名称: ${CONTAINER_NAME}"

# 检查容器是否存在
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "错误: 容器 ${CONTAINER_NAME} 不存在"
    exit 1
fi

# 检查容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "容器未运行，正在启动..."
    docker start ${CONTAINER_NAME}
    sleep 3
fi

# 在容器中执行修复命令
echo "正在修复缓存目录权限..."
docker exec -u root ${CONTAINER_NAME} bash -c "
    # 创建缓存目录
    mkdir -p /tmp/.cache /var/lib/postgresql/.cache
    
    # 设置所有者和权限
    chown -R postgres:postgres /tmp/.cache /var/lib/postgresql/.cache
    chmod -R 755 /tmp/.cache /var/lib/postgresql/.cache
    
    # 验证权限
    echo '缓存目录权限已修复:'
    ls -la /tmp/.cache 2>/dev/null || echo '/tmp/.cache 不存在'
    ls -la /var/lib/postgresql/.cache 2>/dev/null || echo '/var/lib/postgresql/.cache 不存在'
    
    echo '修复完成！'
"

if [ $? -eq 0 ]; then
    echo "✓ 缓存目录权限修复成功"
    echo ""
    echo "现在可以重新尝试向量化操作"
else
    echo "✗ 修复失败，请检查容器状态"
    exit 1
fi
