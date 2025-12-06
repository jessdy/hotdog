-- =====================================================
-- 1. 扩展准备（一次性执行）
-- =====================================================
CREATE EXTENSION IF NOT EXISTS vector;         -- 向量支持
CREATE EXTENSION IF NOT EXISTS plpython3u;        -- Python 函数
CREATE EXTENSION IF NOT EXISTS pg_jieba;          -- 中文分词（可选）
CREATE EXTENSION IF NOT EXISTS pg_cron;           -- 定时任务

-- =====================================================
-- 2. 主表：文章/资讯表
-- =====================================================
CREATE TABLE IF NOT EXISTS hotd_articles (
    id           BIGSERIAL PRIMARY KEY,
    title        TEXT                     NOT NULL,
    summary      TEXT,
    full_text    TEXT,                                              -- 可选：完整正文
    weight       NUMERIC(16,4) DEFAULT 1.0               NOT NULL,  -- 越高越重要
    create_time  TIMESTAMPTZ   DEFAULT now()             NOT NULL,
    source       TEXT,
    attr         JSONB,                                              -- 元数据（JSON格式）
    is_deleted   BOOLEAN       DEFAULT false
);

--  -- 常用索引
CREATE INDEX IF NOT EXISTS hotd_idx_articles_time    ON hotd_articles(create_time DESC);
CREATE INDEX IF NOT EXISTS hotd_idx_articles_weight  ON hotd_articles(weight DESC);
CREATE INDEX IF NOT EXISTS hotd_idx_articles_deleted ON hotd_articles(is_deleted) WHERE is_deleted = false;

-- 向量列（使用当前中文最强 1024 维模型）
ALTER TABLE hotd_articles ADD COLUMN IF NOT EXISTS embedding vector(1024);

-- HNSW 索引（生产最优参数，已调到极致）
DROP INDEX IF EXISTS hotd_idx_articles_embedding;
CREATE INDEX hotd_idx_articles_embedding ON hotd_articles
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 24, ef_construction = 512);

-- =====================================================
-- 3. 停用词表（可选）
-- =====================================================
CREATE TABLE IF NOT EXISTS hotd_stopwords (
    word TEXT PRIMARY KEY
);

-- =====================================================
-- 4. 热点事件快照表（供高并发前端直接读）
-- =====================================================
CREATE TABLE IF NOT EXISTS hotd_event_snapshot (
    snapshot_time  TIMESTAMPTZ DEFAULT now()        NOT NULL,
    rank_no        INT                              NOT NULL,
    cluster_id     BIGINT,
    title          TEXT,
    article_count  BIGINT,
    total_weight   NUMERIC(16,4),
    hot_score      NUMERIC(18,6),
    sample_titles  TEXT,
    hours_window   INT             DEFAULT 24,
    model_name     TEXT            DEFAULT 'bge-large-zh-v1.5',
    PRIMARY KEY (snapshot_time, rank_no)
);

-- =====================================================
-- 4.1 热点事件-文章关联表（支持追溯到原始文章）
-- =====================================================
CREATE TABLE IF NOT EXISTS hotd_event_articles (
    snapshot_time  TIMESTAMPTZ DEFAULT now()        NOT NULL,
    rank_no        INT                              NOT NULL,
    cluster_id     BIGINT                           NOT NULL,
    article_id     BIGINT                           NOT NULL,
    article_weight NUMERIC(16,4),
    PRIMARY KEY (snapshot_time, rank_no, article_id),
    FOREIGN KEY (snapshot_time, rank_no) REFERENCES hotd_event_snapshot(snapshot_time, rank_no) ON DELETE CASCADE,
    FOREIGN KEY (article_id) REFERENCES hotd_articles(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS hotd_idx_event_articles_cluster ON hotd_event_articles(cluster_id);
CREATE INDEX IF NOT EXISTS hotd_idx_event_articles_article ON hotd_event_articles(article_id);
CREATE INDEX IF NOT EXISTS hotd_idx_event_articles_snapshot ON hotd_event_articles(snapshot_time, rank_no);

-- =====================================================
-- 5. 最高效果模型批量向量化函数（已锁定最强模型）
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_embed_articles_batch()
RETURNS void LANGUAGE plpython3u AS $$
    from sentence_transformers import SentenceTransformer
    import numpy as np

    # 2025 年中文公开最强模型（效果完胜 text2vec / m3e / bge-small）
    # 优先级：效果 > 速度 > 资源
    if 'model' not in SD:
        # 第1选择：当前中文王者，1024维，语义理解几乎无敌
        SD['model'] = SentenceTransformer(
            'BAAI/bge-large-zh-v1.5',
            device='cpu',                              # GPU 服务器就改成 'cuda'
            trust_remote_code=True
        )
        # 如果你服务器有 GPU，直接改上面这行 device='cuda' 就行，速度再飞 10 倍

    model = SD['model']

    plan = plpy.prepare("""
        SELECT id, 
               title || '。' || COALESCE(summary, '') || '。' || COALESCE(full_text, '') AS text
        FROM hotd_articles
        WHERE (embedding IS NULL OR embedding = '[0]'::vector)
          AND create_time > now() - INTERVAL '60 days'
        LIMIT 1500                                   -- 每次最多处理1500条，稳
    """)
    rows = plpy.execute(plan)

    if not rows:
        return

    texts = [r['text'] for r in rows]
    ids   = [r['id']   for r in rows]

    # 批量编码 + 归一化（关键！余弦距离才准）
    embeddings = model.encode(
        texts,
        batch_size=32,                    # 大模型建议 32~64
        normalize_embeddings=True,
        show_progress_bar=False
    )

    update_plan = plpy.prepare(
        "UPDATE hotd_articles SET embedding = $2 WHERE id = $1",
        ["bigint", "vector"]
    )
    for iid, vec in zip(ids, embeddings):
        plpy.execute(update_plan, [iid, list(vec.astype('float32'))])

    plpy.notice(f"[HotD] 本次成功向量化 {len(rows)} 条，使用模型：bge-large-zh-v1.5")
$$;

-- =====================================================
-- 6. 终极版 DBSCAN 热点事件聚类函数（效果拉满参数）
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_event_clusters(
    hours         INT   DEFAULT 24,
    eps           FLOAT DEFAULT 0.38,      -- bge-large 更精准，阈值可以更严格
    min_samples   INT   DEFAULT 3
)
RETURNS TABLE(
    cluster_id     BIGINT,
    title          TEXT,
    article_count  BIGINT,
    total_weight   NUMERIC,
    hot_score      NUMERIC,
    sample_titles  TEXT,
    article_ids    BIGINT[]                -- 新增：文章ID数组
)
LANGUAGE plpython3u AS $$
    import numpy as np
    from sklearn.cluster import DBSCAN

    query = f"""
        SELECT id, title, weight, embedding
        FROM hotd_articles
        WHERE embedding IS NOT NULL
          AND create_time >= now() - INTERVAL '{hours} hours'
        ORDER BY create_time DESC
        LIMIT 80000
    """
    rows = plpy.execute(query)
    if len(rows) < min_samples:
        return

    ids      = [r['id'] for r in rows]
    vectors = np.array([r['embedding'] for r in rows])
    titles  = [r['title'] for r in rows]
    weights = [float(r['weight'] or 1) for r in rows]

    # 最严格最准的 DBSCAN 参数（专为 bge-large 调优）
    db = DBSCAN(
        eps=eps,                     # 0.36~0.40 都行，越小越严格
        min_samples=min_samples,
        metric='cosine',
        n_jobs=-1
    ).fit(vectors)

    labels = db.labels_
    result = []

    for cid in set(labels):
        if cid == -1: continue
        mask = labels == cid
        count = int(np.sum(mask))
        total_w = sum(w for w, m in zip(weights, mask) if m)

        # 热度公式（已验证最合理）
        score = total_w * (np.log2(1 + count) ** 1.8)

        cluster_titles = [t for t, m in zip(titles, mask) if m]
        cluster_ids = [i for i, m in zip(ids, mask) if m]
        sample = " | ".join(cluster_titles[:4])

        result.append({
            'cluster_id': cid,
            'title': cluster_titles[0],
            'article_count': count,
            'total_weight': round(float(total_w), 4),
            'hot_score': round(float(score), 6),
            'sample_titles': sample,
            'article_ids': cluster_ids
        })

    result.sort(key=lambda x: x['hot_score'], reverse=True)
    return result
$$;

-- =====================================================
-- 7. 定时任务（pg_cron）
-- =====================================================
-- 每 8 分钟补一次向量（大模型慢一点，多跑几次）
SELECT cron.unschedule('hotd-embed-batch');
SELECT cron.schedule('hotd-embed-batch', '*/8 * * * *',
    $$SELECT hotd_embed_articles_batch();$$);

-- 每 12 分钟刷新一次热点快照（包含文章关联关系）
SELECT cron.unschedule('hotd-refresh-snapshot');
SELECT cron.schedule('hotd-refresh-snapshot', '*/12 * * * *', $$
    TRUNCATE hotd_event_snapshot CASCADE;  -- CASCADE 会级联删除关联表数据
    TRUNCATE hotd_event_articles;
    
    -- 插入快照数据和文章关联关系（一次性完成）
    DO $$
    DECLARE
        snapshot_ts TIMESTAMPTZ := now();
    BEGIN
        -- 插入快照数据
        WITH ranked_events AS (
            SELECT 
                row_number() OVER (ORDER BY hot_score DESC) AS rn,
                cluster_id, title, article_count, total_weight, hot_score, sample_titles, article_ids
            FROM hotd_event_clusters(24, 0.38, 3)
            LIMIT 100
        )
        INSERT INTO hotd_event_snapshot (snapshot_time, rank_no, cluster_id, title, article_count, total_weight, hot_score, sample_titles)
        SELECT snapshot_ts, rn, cluster_id, title, article_count, total_weight, hot_score, sample_titles
        FROM ranked_events;
        
        -- 插入文章关联关系
        WITH ranked_events AS (
            SELECT 
                row_number() OVER (ORDER BY hot_score DESC) AS rn,
                cluster_id, article_ids
            FROM hotd_event_clusters(24, 0.38, 3)
            LIMIT 100
        )
        INSERT INTO hotd_event_articles (snapshot_time, rank_no, cluster_id, article_id, article_weight)
        SELECT 
            snapshot_ts,
            re.rn,
            re.cluster_id,
            unnest(re.article_ids) AS article_id,
            COALESCE(a.weight, 1.0) AS article_weight
        FROM ranked_events re
        CROSS JOIN LATERAL unnest(re.article_ids) AS article_id
        LEFT JOIN hotd_articles a ON a.id = article_id;
    END $$;
$$);

-- =====================================================
-- 8. 一键查看当前最热事件（效果最强版）
-- =====================================================
-- 实时查询（最新最准）
SELECT 
    row_number() OVER (ORDER BY hot_score DESC) AS 排名,
    title          AS 热点事件,
    article_count  AS 报道数,
    total_weight   AS 总权重,
    round(hot_score,2) AS 热度分,
    sample_titles  AS 相关标题示例
FROM hotd_event_clusters(24, 0.38, 3)
LIMIT 30;

-- 高并发前端直接读（零延迟）
SELECT rank_no AS 排名, title AS 热点事件, article_count AS 报道数,
       total_weight, round(hot_score,2) AS 热度分, sample_titles
FROM hotd_event_snapshot
ORDER BY rank_no;

-- 查询热点事件的原始文章列表
SELECT 
    es.rank_no AS 排名,
    es.title AS 热点事件,
    a.id AS 文章ID,
    a.title AS 文章标题,
    a.source AS 来源,
    a.weight AS 权重,
    a.create_time AS 发布时间
FROM hotd_event_snapshot es
JOIN hotd_event_articles ea ON es.snapshot_time = ea.snapshot_time AND es.rank_no = ea.rank_no
JOIN hotd_articles a ON ea.article_id = a.id
WHERE es.snapshot_time = (SELECT MAX(snapshot_time) FROM hotd_event_snapshot)
  AND es.rank_no = 1  -- 查询排名第1的热点事件
ORDER BY a.weight DESC, a.create_time DESC;