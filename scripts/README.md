# 测试数据生成脚本

## 文件说明

### 1. `generate-test-data.sh`
批量生成测试文章数据的脚本，包含15条模拟热点新闻数据。

**使用方法：**
```bash
# 使用默认配置（localhost:8080, default系统）
./scripts/generate-test-data.sh

# 自定义API地址和系统代码
API_BASE_URL=http://10.10.10.252:8080 SYSTEM_CODE=news-system ./scripts/generate-test-data.sh
```

**功能：**
- 批量创建15条测试文章
- 包含科技、汽车、财经等不同类别
- 模拟真实热点新闻场景
- 自动统计成功/失败数量

### 2. `test-api-examples.sh`
包含常用API调用的示例脚本。

**使用方法：**
```bash
./scripts/test-api-examples.sh
```

**包含的API示例：**
- 创建单个文章
- 批量创建文章
- 查询文章列表
- 手动触发向量化
- 获取实时热点事件
- 获取热点事件快照
- 刷新热点快照

## 快速开始

### 1. 生成测试数据
```bash
cd /Users/jessdy/codes/hotdog
./scripts/generate-test-data.sh
```

### 2. 手动触发向量化（可选）
```bash
curl -X POST http://localhost:8080/api/embedding/trigger \
  -H "X-System-Code: default"
```

### 3. 查看热点事件（等待向量化完成后）
```bash
# 实时查询（调用聚类函数）
curl http://localhost:8080/api/hot-events/realtime?systemId=1&hours=24&limit=10

# 快照查询（高性能）
curl http://localhost:8080/api/hot-events/snapshot?systemId=1&limit=10
```

## 注意事项

1. **向量化时间**：文章创建后需要等待约8分钟才能完成向量化（定时任务自动执行）
2. **手动触发**：可以使用 `/api/embedding/trigger` 接口手动触发向量化
3. **热点事件**：向量化完成后才能进行聚类和生成热点事件
4. **系统代码**：如果使用多租户功能，需要指定正确的 `X-System-Code` 请求头

## 测试数据说明

生成的测试数据包含以下主题：
- 华为Mate 70系列手机（2条相关文章）
- 苹果iPhone 16（2条相关文章）
- 小米汽车SU7（2条相关文章）
- OpenAI GPT-5（2条相关文章）
- 房地产政策（2条相关文章）
- 其他热点新闻（5条）

这些数据设计用于测试聚类功能，相同主题的文章应该被聚合成热点事件。
