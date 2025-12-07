#!/bin/bash

# API 测试示例脚本
# 包含常用的 API 调用示例

API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
SYSTEM_CODE="${SYSTEM_CODE:-default}"

echo "=== HotDog API 测试示例 ==="
echo "API地址: $API_BASE_URL"
echo "系统代码: $SYSTEM_CODE"
echo ""

# 1. 创建单个文章
echo "1. 创建单个文章:"
curl -X POST "$API_BASE_URL/api/articles" \
  -H "Content-Type: application/json" \
  -H "X-System-Code: $SYSTEM_CODE" \
  -d '{
    "title": "测试文章标题",
    "summary": "这是文章的摘要",
    "fullText": "这是文章的完整正文内容",
    "weight": 1.5,
    "source": "测试来源",
    "isShared": false,
    "metadata": {
      "author": "测试作者",
      "tags": ["测试", "示例"],
      "category": "测试分类"
    }
  }' | jq '.'

echo -e "\n"

# 2. 批量创建文章
echo "2. 批量创建文章:"
curl -X POST "$API_BASE_URL/api/articles/batch" \
  -H "Content-Type: application/json" \
  -H "X-System-Code: $SYSTEM_CODE" \
  -d '[
    {
      "title": "批量文章1",
      "summary": "摘要1",
      "weight": 1.0,
      "source": "来源1"
    },
    {
      "title": "批量文章2",
      "summary": "摘要2",
      "weight": 1.2,
      "source": "来源2"
    }
  ]' | jq '.'

echo -e "\n"

# 3. 查询文章列表
echo "3. 查询文章列表:"
curl -X GET "$API_BASE_URL/api/articles?systemId=1&page=0&size=10" \
  -H "X-System-Code: $SYSTEM_CODE" | jq '.'

echo -e "\n"

# 4. 手动触发向量化
echo "4. 手动触发向量化:"
curl -X POST "$API_BASE_URL/api/embedding/trigger" \
  -H "X-System-Code: $SYSTEM_CODE" | jq '.'

echo -e "\n"

# 5. 获取实时热点事件
echo "5. 获取实时热点事件:"
curl -X GET "$API_BASE_URL/api/hot-events/realtime?systemId=1&hours=24&limit=10" \
  -H "X-System-Code: $SYSTEM_CODE" | jq '.'

echo -e "\n"

# 6. 获取热点事件快照
echo "6. 获取热点事件快照:"
curl -X GET "$API_BASE_URL/api/hot-events/snapshot?systemId=1&limit=10" \
  -H "X-System-Code: $SYSTEM_CODE" | jq '.'

echo -e "\n"

# 7. 刷新热点快照
echo "7. 刷新热点快照:"
curl -X POST "$API_BASE_URL/api/hot-events/snapshot/refresh?systemId=1" \
  -H "X-System-Code: $SYSTEM_CODE" | jq '.'

echo -e "\n"

echo "=== 测试完成 ==="
