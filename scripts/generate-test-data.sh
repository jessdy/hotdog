#!/bin/bash

# 测试数据生成脚本
# 用于批量创建测试文章数据

API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
SYSTEM_CODE="${SYSTEM_CODE:-default}"

echo "开始生成测试数据..."
echo "API地址: $API_BASE_URL"
echo "系统代码: $SYSTEM_CODE"
echo ""

# 测试文章数据（模拟热点新闻）
articles=(
  '{"title":"华为发布Mate 70系列手机 搭载麒麟芯片","summary":"华为今日正式发布Mate 70系列手机，搭载全新麒麟芯片，支持5G网络","fullText":"华为Mate 70系列手机今日正式发布，该系列搭载了全新的麒麟芯片，支持5G网络，拍照功能大幅提升。","weight":1.5,"source":"新浪科技","metadata":{"author":"科技记者","tags":["科技","手机"],"category":"科技新闻"}}'
  '{"title":"华为Mate 70 Pro开售 首日销量破百万","summary":"华为Mate 70 Pro今日正式开售，首日销量突破百万台，创历史新高","fullText":"华为Mate 70 Pro今日正式开售，消费者热情高涨，首日销量突破百万台，创下华为手机销售历史新高。","weight":1.8,"source":"腾讯科技","metadata":{"author":"财经记者","tags":["科技","手机","销售"],"category":"科技新闻"}}'
  '{"title":"苹果iPhone 16发布 新增AI功能","summary":"苹果公司发布iPhone 16系列，新增多项AI功能，价格保持不变","fullText":"苹果公司今日发布iPhone 16系列手机，新增多项AI功能，包括智能拍照、语音助手等，价格与上代保持一致。","weight":1.6,"source":"网易科技","metadata":{"author":"科技编辑","tags":["科技","手机","AI"],"category":"科技新闻"}}'
  '{"title":"iPhone 16预售开启 预约人数超500万","summary":"iPhone 16今日开启预售，预约人数已超过500万，预计供不应求","fullText":"iPhone 16今日正式开启预售，消费者预约热情高涨，预约人数已超过500万，预计将出现供不应求的情况。","weight":1.7,"source":"36氪","metadata":{"author":"科技记者","tags":["科技","手机","预售"],"category":"科技新闻"}}'
  '{"title":"小米汽车SU7正式发布 售价21.59万起","summary":"小米汽车SU7今日正式发布，售价21.59万元起，续航里程700公里","fullText":"小米汽车SU7今日正式发布，这是小米首款电动汽车，售价21.59万元起，续航里程达到700公里，支持快充功能。","weight":2.0,"source":"汽车之家","metadata":{"author":"汽车编辑","tags":["汽车","新能源","小米"],"category":"汽车新闻"}}'
  '{"title":"小米SU7订单量突破10万台 创行业记录","summary":"小米SU7发布后订单量迅速突破10万台，创下新能源汽车行业新记录","fullText":"小米SU7发布后，消费者订单量迅速突破10万台，创下新能源汽车行业的新记录，预计交付时间将延长。","weight":2.2,"source":"第一财经","metadata":{"author":"财经记者","tags":["汽车","新能源","订单"],"category":"汽车新闻"}}'
  '{"title":"特斯拉Model Y降价 最低价降至25.99万","summary":"特斯拉Model Y宣布降价，最低价降至25.99万元，引发市场关注","fullText":"特斯拉Model Y今日宣布降价，最低价降至25.99万元，这是特斯拉今年首次大幅降价，引发市场广泛关注。","weight":1.9,"source":"澎湃新闻","metadata":{"author":"汽车记者","tags":["汽车","新能源","降价"],"category":"汽车新闻"}}'
  '{"title":"OpenAI发布GPT-5模型 性能大幅提升","summary":"OpenAI发布最新GPT-5模型，在多项测试中性能大幅提升，支持多模态输入","fullText":"OpenAI今日发布最新GPT-5模型，在语言理解、代码生成、数学推理等多项测试中性能大幅提升，支持文本、图像、音频等多模态输入。","weight":2.5,"source":"科技日报","metadata":{"author":"科技记者","tags":["AI","GPT","科技"],"category":"科技新闻"}}'
  '{"title":"GPT-5开放API接口 开发者可申请使用","summary":"OpenAI开放GPT-5的API接口，开发者可申请使用，价格较GPT-4降低30%","fullText":"OpenAI今日宣布开放GPT-5的API接口，开发者可申请使用，API调用价格较GPT-4降低30%，预计将推动AI应用快速发展。","weight":2.3,"source":"TechCrunch","metadata":{"author":"技术编辑","tags":["AI","API","开发"],"category":"科技新闻"}}'
  '{"title":"字节跳动发布豆包大模型 对标GPT-4","summary":"字节跳动发布豆包大模型，性能对标GPT-4，支持中文场景优化","fullText":"字节跳动今日发布豆包大模型，该模型在多项测试中性能对标GPT-4，特别针对中文场景进行了优化，支持长文本处理。","weight":2.1,"source":"界面新闻","metadata":{"author":"科技记者","tags":["AI","大模型","中文"],"category":"科技新闻"}}'
  '{"title":"北京发布楼市新政 取消限购政策","summary":"北京市发布楼市新政，取消限购政策，降低首付比例至20%","fullText":"北京市今日发布楼市新政，取消限购政策，降低首付比例至20%，同时放宽购房资格，预计将刺激房地产市场回暖。","weight":2.4,"source":"财新网","metadata":{"author":"财经记者","tags":["房地产","政策","北京"],"category":"财经新闻"}}'
  '{"title":"上海楼市成交量环比增长50% 市场回暖","summary":"上海楼市成交量环比增长50%，市场出现明显回暖迹象","fullText":"上海楼市成交量环比增长50%，市场出现明显回暖迹象，专家认为这与政策调整和需求释放有关。","weight":2.0,"source":"21世纪经济报道","metadata":{"author":"财经记者","tags":["房地产","市场","上海"],"category":"财经新闻"}}'
  '{"title":"A股三大指数集体上涨 科技股领涨","summary":"A股三大指数今日集体上涨，科技股领涨，成交量放大","fullText":"A股三大指数今日集体上涨，科技股领涨，成交量明显放大，市场情绪回暖，投资者信心增强。","weight":1.8,"source":"证券时报","metadata":{"author":"财经记者","tags":["股市","科技股","A股"],"category":"财经新闻"}}'
  '{"title":"新能源汽车销量创新高 同比增长80%","summary":"新能源汽车销量创新高，同比增长80%，市场渗透率持续提升","fullText":"新能源汽车销量创新高，同比增长80%，市场渗透率持续提升，预计全年销量将突破1000万辆。","weight":2.2,"source":"中国汽车报","metadata":{"author":"汽车记者","tags":["汽车","新能源","销量"],"category":"汽车新闻"}}'
  '{"title":"人工智能助力医疗诊断 准确率提升至95%","summary":"人工智能技术在医疗诊断领域取得突破，准确率提升至95%","fullText":"人工智能技术在医疗诊断领域取得重大突破，通过深度学习算法，诊断准确率提升至95%，有望改善医疗服务质量。","weight":2.3,"source":"健康时报","metadata":{"author":"医疗记者","tags":["AI","医疗","诊断"],"category":"医疗新闻"}}'
)

# 计数器
success_count=0
fail_count=0

# 批量创建文章
echo "正在批量创建文章..."
for article in "${articles[@]}"; do
  response=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE_URL/api/articles" \
    -H "Content-Type: application/json" \
    -H "X-System-Code: $SYSTEM_CODE" \
    -d "$article")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
    title=$(echo "$body" | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "✓ 创建成功: $title"
    ((success_count++))
  else
    echo "✗ 创建失败 (HTTP $http_code): $body"
    ((fail_count++))
  fi
  
  # 避免请求过快
  sleep 0.1
done

echo ""
echo "========================================="
echo "测试数据生成完成！"
echo "成功: $success_count 条"
echo "失败: $fail_count 条"
echo "========================================="
echo ""
echo "提示："
echo "1. 文章创建后需要等待向量化（约8分钟）"
echo "2. 可以手动触发向量化: POST $API_BASE_URL/api/embedding/trigger"
echo "3. 查看热点事件: GET $API_BASE_URL/api/hot-events/realtime?systemId=1"
echo "4. 查看文章列表: GET $API_BASE_URL/api/articles?systemId=1"
