#!/bin/bash

# 修复 postgresql.conf 中的 shared_preload_libraries 配置
# 如果 pg_jieba.so 不存在，则从配置中移除 pg_jieba

DATA_DIR="${DATA_DIR:-./postgres-data}"

if [ ! -d "${DATA_DIR}" ]; then
    echo "错误: 数据目录 ${DATA_DIR} 不存在"
    exit 1
fi

# 查找 postgresql.conf 文件
# PostgreSQL 18+ 的数据目录结构可能是 /var/lib/postgresql/18/docker
CONF_FILE=""
if [ -f "${DATA_DIR}/18/docker/postgresql.conf" ]; then
    CONF_FILE="${DATA_DIR}/18/docker/postgresql.conf"
elif [ -f "${DATA_DIR}/postgresql.conf" ]; then
    CONF_FILE="${DATA_DIR}/postgresql.conf"
else
    echo "错误: 找不到 postgresql.conf 文件"
    echo "搜索路径:"
    echo "  ${DATA_DIR}/18/docker/postgresql.conf"
    echo "  ${DATA_DIR}/postgresql.conf"
    exit 1
fi

echo "找到配置文件: ${CONF_FILE}"

# 检查 pg_jieba.so 是否存在（需要启动临时容器检查）
echo "检查 pg_jieba.so 是否存在..."
IMAGE_NAME="hotdog-postgres-with-plugins:18.0"
PG_LIBDIR=$(docker run --rm ${IMAGE_NAME} pg_config --pkglibdir 2>/dev/null)

if [ -z "${PG_LIBDIR}" ]; then
    echo "警告: 无法确定 PostgreSQL 库目录，假设 pg_jieba.so 不存在"
    HAS_PG_JIEBA=0
else
    # 检查文件是否存在
    if docker run --rm ${IMAGE_NAME} test -f "${PG_LIBDIR}/pg_jieba.so" 2>/dev/null; then
        echo "✓ pg_jieba.so 存在"
        HAS_PG_JIEBA=1
    else
        echo "✗ pg_jieba.so 不存在"
        HAS_PG_JIEBA=0
    fi
fi

# 备份原配置文件
cp "${CONF_FILE}" "${CONF_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "已备份配置文件到: ${CONF_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# 修复配置
if [ ${HAS_PG_JIEBA} -eq 1 ]; then
    # pg_jieba 存在，确保配置包含它
    if grep -q "shared_preload_libraries.*pg_jieba" "${CONF_FILE}"; then
        echo "配置已包含 pg_jieba，无需修改"
    else
        # 替换或添加配置
        if grep -q "^shared_preload_libraries" "${CONF_FILE}"; then
            sed -i.bak "s/^shared_preload_libraries.*/shared_preload_libraries = 'pg_cron,pg_jieba'/" "${CONF_FILE}"
            echo "已更新 shared_preload_libraries 配置"
        else
            echo "shared_preload_libraries = 'pg_cron,pg_jieba'" >> "${CONF_FILE}"
            echo "已添加 shared_preload_libraries 配置"
        fi
    fi
else
    # pg_jieba 不存在，从配置中移除
    if grep -q "shared_preload_libraries.*pg_jieba" "${CONF_FILE}"; then
        sed -i.bak "s/^shared_preload_libraries.*pg_jieba.*/shared_preload_libraries = 'pg_cron'/" "${CONF_FILE}"
        sed -i.bak "s/^shared_preload_libraries.*'pg_cron,pg_jieba'.*/shared_preload_libraries = 'pg_cron'/" "${CONF_FILE}"
        sed -i.bak "s/^shared_preload_libraries.*'pg_jieba,pg_cron'.*/shared_preload_libraries = 'pg_cron'/" "${CONF_FILE}"
        echo "已从 shared_preload_libraries 中移除 pg_jieba"
    else
        echo "配置中不包含 pg_jieba，无需修改"
    fi
fi

echo "修复完成！"
echo "请重启 PostgreSQL 容器以使配置生效"
