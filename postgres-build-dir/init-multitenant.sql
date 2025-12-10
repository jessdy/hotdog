-- =====================================================
-- 多租户架构扩展：支持多系统使用，数据隔离，独立配置
-- =====================================================
-- 
-- 功能说明：
-- 1. 支持多个独立的系统/租户，每个系统有独立的配置和热点事件
-- 2. 文章可以属于特定系统，也可以共享给多个系统
-- 3. 每个系统可以独立配置聚类参数、定时任务等
-- 4. 提供数据迁移函数，将旧数据迁移到默认系统
-- 5. 提供辅助函数和视图，方便查询和管理
--
-- 使用说明：
-- 1. 此脚本需要在 init.sql 执行后运行，或者确保基础表已存在
-- 2. 如果基础表不存在，脚本会自动创建它们（向后兼容）
-- 3. 首次运行后，会自动创建默认系统（system_code='default'）
-- 4. 如果需要迁移旧数据，可以执行：SELECT hotd_migrate_to_default_system();
-- 5. 如果需要设置定时任务，可以执行：SELECT hotd_setup_system_cron_jobs();
--
-- 主要表结构：
-- - hotd_systems: 系统/租户表
-- - hotd_system_configs: 系统配置表（聚类参数、定时任务等）
-- - hotd_articles: 文章表（添加了 system_id 和 is_shared 字段）
-- - hotd_article_systems: 文章共享关联表（支持文章被多个系统使用）
-- - hotd_event_snapshot: 热点事件快照表（添加了 system_id 字段）
-- - hotd_event_articles: 热点事件-文章关联表（添加了 system_id 字段）
--
-- 主要函数：
-- - hotd_event_clusters_by_system(): 按系统聚类函数
-- - hotd_refresh_snapshot_by_system(): 按系统刷新快照函数
-- - hotd_embed_articles_batch_by_system(): 按系统向量化函数
-- - hotd_get_system_id(): 根据系统代码获取系统ID
-- - hotd_system_exists(): 检查系统是否存在
-- - hotd_migrate_to_default_system(): 数据迁移函数
-- - hotd_setup_system_cron_jobs(): 设置定时任务函数
--
-- 主要视图：
-- - hotd_system_hot_events_view: 系统热点事件概览
-- - hotd_system_article_stats_view: 系统文章统计
--
-- =====================================================

-- =====================================================
-- 0. 检查并创建基础表（如果不存在）
-- =====================================================
DO $$
BEGIN
    -- 检查 hotd_articles 表是否存在，如果不存在则创建
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hotd_articles') THEN
        RAISE NOTICE '基础表不存在，正在创建基础表结构...';
        
        -- 创建文章表
        CREATE TABLE hotd_articles (
            id           BIGSERIAL PRIMARY KEY,
            title        TEXT                     NOT NULL,
            summary      TEXT,
            full_text    TEXT,
            weight       NUMERIC(16,4) DEFAULT 1.0               NOT NULL,
            create_time  TIMESTAMPTZ   DEFAULT now()             NOT NULL,
            source       TEXT,
            attr         JSONB,
            is_deleted   BOOLEAN       DEFAULT false,
            embedding    vector(1024)
        );
        
        CREATE INDEX IF NOT EXISTS hotd_idx_articles_time    ON hotd_articles(create_time DESC);
        CREATE INDEX IF NOT EXISTS hotd_idx_articles_weight  ON hotd_articles(weight DESC);
        CREATE INDEX IF NOT EXISTS hotd_idx_articles_deleted ON hotd_articles(is_deleted) WHERE is_deleted = false;
        CREATE INDEX IF NOT EXISTS hotd_idx_articles_embedding ON hotd_articles USING hnsw (embedding vector_cosine_ops) WITH (m = 24, ef_construction = 512);
        
        -- 创建快照表
        CREATE TABLE hotd_event_snapshot (
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
        
        -- 创建文章关联表
        CREATE TABLE hotd_event_articles (
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
        
        RAISE NOTICE '基础表创建完成';
    ELSE
        RAISE NOTICE '基础表已存在，继续执行多租户扩展...';
    END IF;
END $$;

-- =====================================================
-- 1. 系统/租户表
-- =====================================================
CREATE TABLE IF NOT EXISTS hotd_systems (
    id            BIGSERIAL PRIMARY KEY,
    system_code   VARCHAR(64)  NOT NULL UNIQUE,        -- 系统代码（唯一标识）
    system_name   VARCHAR(128) NOT NULL,               -- 系统名称
    description   TEXT,                                -- 系统描述
    is_active     BOOLEAN      DEFAULT true,           -- 是否启用
    create_time   TIMESTAMPTZ  DEFAULT now() NOT NULL,
    update_time   TIMESTAMPTZ  DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS hotd_idx_systems_code ON hotd_systems(system_code);
CREATE INDEX IF NOT EXISTS hotd_idx_systems_active ON hotd_systems(is_active) WHERE is_active = true;

-- =====================================================
-- 2. 系统配置表（每个系统独立的聚类参数和定时规则）
-- =====================================================
CREATE TABLE IF NOT EXISTS hotd_system_configs (
    system_id          BIGINT       NOT NULL PRIMARY KEY,
    -- 聚类参数
    default_hours      INT          DEFAULT 24,        -- 默认时间窗口（小时）
    default_eps        FLOAT        DEFAULT 0.38,      -- 默认 eps 参数
    default_min_samples INT         DEFAULT 3,          -- 默认最小样本数
    -- 定时任务配置
    embedding_cron     VARCHAR(64)  DEFAULT '*/8 * * * *',  -- 向量化任务 cron 表达式
    clustering_cron    VARCHAR(64)  DEFAULT '*/12 * * * *', -- 聚类任务 cron 表达式
    -- 其他配置
    max_articles_limit  INT          DEFAULT 80000,     -- 聚类时最大文章数限制
    snapshot_limit      INT          DEFAULT 100,       -- 快照保留数量
    -- 元数据
    create_time         TIMESTAMPTZ DEFAULT now() NOT NULL,
    update_time         TIMESTAMPTZ DEFAULT now() NOT NULL,
    FOREIGN KEY (system_id) REFERENCES hotd_systems(id) ON DELETE CASCADE
);

-- =====================================================
-- 3. 修改文章表，添加系统ID字段
-- =====================================================
ALTER TABLE hotd_articles ADD COLUMN IF NOT EXISTS system_id BIGINT;
ALTER TABLE hotd_articles ADD COLUMN IF NOT EXISTS is_shared BOOLEAN DEFAULT false;  -- 是否共享给其他系统

-- 添加外键约束
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'hotd_articles_system_id_fkey'
    ) THEN
        ALTER TABLE hotd_articles 
        ADD CONSTRAINT hotd_articles_system_id_fkey 
        FOREIGN KEY (system_id) REFERENCES hotd_systems(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 添加索引
CREATE INDEX IF NOT EXISTS hotd_idx_articles_system ON hotd_articles(system_id);
CREATE INDEX IF NOT EXISTS hotd_idx_articles_shared ON hotd_articles(is_shared) WHERE is_shared = true;
CREATE INDEX IF NOT EXISTS hotd_idx_articles_system_time ON hotd_articles(system_id, create_time DESC);

-- =====================================================
-- 4. 文章共享关联表（支持数据源重叠，文章可被多个系统使用）
-- =====================================================
CREATE TABLE IF NOT EXISTS hotd_article_systems (
    article_id    BIGINT NOT NULL,
    system_id     BIGINT NOT NULL,
    create_time   TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (article_id, system_id),
    FOREIGN KEY (article_id) REFERENCES hotd_articles(id) ON DELETE CASCADE,
    FOREIGN KEY (system_id) REFERENCES hotd_systems(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS hotd_idx_article_systems_system ON hotd_article_systems(system_id);
CREATE INDEX IF NOT EXISTS hotd_idx_article_systems_article ON hotd_article_systems(article_id);

-- =====================================================
-- 5. 修改热点事件快照表，添加系统ID
-- =====================================================
ALTER TABLE hotd_event_snapshot ADD COLUMN IF NOT EXISTS system_id BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'hotd_event_snapshot_system_id_fkey'
    ) THEN
        ALTER TABLE hotd_event_snapshot 
        ADD CONSTRAINT hotd_event_snapshot_system_id_fkey 
        FOREIGN KEY (system_id) REFERENCES hotd_systems(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 修改主键（添加 system_id）
-- 注意：需要先删除所有依赖的外键约束
DO $$
DECLARE
    fk_constraint RECORD;
BEGIN
    -- 查找并删除所有依赖 hotd_event_snapshot 主键的外键约束
    FOR fk_constraint IN
        SELECT conname, conrelid::regclass AS table_name
        FROM pg_constraint
        WHERE confrelid = 'hotd_event_snapshot'::regclass
          AND contype = 'f'
    LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', 
                       fk_constraint.table_name, 
                       fk_constraint.conname);
    END LOOP;
    
    -- 删除旧的主键约束（如果存在且还没有被删除）
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'hotd_event_snapshot_pkey'
          AND conrelid = 'hotd_event_snapshot'::regclass
    ) THEN
        ALTER TABLE hotd_event_snapshot 
        DROP CONSTRAINT hotd_event_snapshot_pkey;
    END IF;
END $$;

-- 创建新的主键（包含 system_id）
ALTER TABLE hotd_event_snapshot ADD PRIMARY KEY (snapshot_time, rank_no, system_id);

CREATE INDEX IF NOT EXISTS hotd_idx_event_snapshot_system ON hotd_event_snapshot(system_id);
CREATE INDEX IF NOT EXISTS hotd_idx_event_snapshot_system_time ON hotd_event_snapshot(system_id, snapshot_time DESC);

-- =====================================================
-- 6. 修改热点事件-文章关联表，添加系统ID
-- =====================================================
ALTER TABLE hotd_event_articles ADD COLUMN IF NOT EXISTS system_id BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'hotd_event_articles_system_id_fkey'
    ) THEN
        ALTER TABLE hotd_event_articles 
        ADD CONSTRAINT hotd_event_articles_system_id_fkey 
        FOREIGN KEY (system_id) REFERENCES hotd_systems(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 修改主键（添加 system_id）
DO $$
BEGIN
    -- 删除旧的主键约束
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'hotd_event_articles_pkey'
    ) THEN
        ALTER TABLE hotd_event_articles 
        DROP CONSTRAINT hotd_event_articles_pkey;
    END IF;
END $$;

ALTER TABLE hotd_event_articles ADD PRIMARY KEY (snapshot_time, rank_no, article_id, system_id);

-- 重新创建外键约束（包含 system_id）
DO $$
BEGIN
    -- 删除旧的外键约束（如果还存在）
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'hotd_event_articles_snapshot_time_rank_no_fkey'
    ) THEN
        ALTER TABLE hotd_event_articles 
        DROP CONSTRAINT hotd_event_articles_snapshot_time_rank_no_fkey;
    END IF;
    
    -- 创建新的外键约束（包含 system_id）
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'hotd_event_articles_snapshot_fkey'
    ) THEN
        ALTER TABLE hotd_event_articles 
        ADD CONSTRAINT hotd_event_articles_snapshot_fkey 
        FOREIGN KEY (snapshot_time, rank_no, system_id) 
        REFERENCES hotd_event_snapshot(snapshot_time, rank_no, system_id) 
        ON DELETE CASCADE;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS hotd_idx_event_articles_system ON hotd_event_articles(system_id);

-- =====================================================
-- 7. 多系统支持的聚类函数（按系统ID聚类）
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_event_clusters_by_system(
    p_system_id   BIGINT,
    hours         INT   DEFAULT NULL,      -- NULL 时使用系统配置
    eps           FLOAT DEFAULT NULL,       -- NULL 时使用系统配置
    min_samples   INT   DEFAULT NULL        -- NULL 时使用系统配置
)
RETURNS TABLE(
    cluster_id     BIGINT,
    title          TEXT,
    article_count  BIGINT,
    total_weight   NUMERIC,
    hot_score      NUMERIC,
    sample_titles  TEXT,
    article_ids    BIGINT[]
)
LANGUAGE plpython3u AS $$
    import numpy as np
    from sklearn.cluster import DBSCAN

    # 获取系统配置
    config_query = f"""
        SELECT default_hours, default_eps, default_min_samples, max_articles_limit
        FROM hotd_system_configs
        WHERE system_id = {p_system_id}
    """
    config_rows = plpy.execute(config_query)
    
    if not config_rows:
        plpy.error(f"系统配置不存在: system_id={p_system_id}")
    
    config = config_rows[0]
    actual_hours = hours if hours is not None else config['default_hours']
    actual_eps = eps if eps is not None else config['default_eps']
    actual_min_samples = min_samples if min_samples is not None else config['default_min_samples']
    max_limit = config['max_articles_limit'] or 80000

    # 查询该系统的文章（包括共享文章）
    # 注意：使用 DISTINCT 时，ORDER BY 中的列必须出现在 SELECT 列表中
    query = f"""
        SELECT DISTINCT a.id, a.title, a.weight, a.embedding, a.create_time
        FROM hotd_articles a
        LEFT JOIN hotd_article_systems as_rel ON a.id = as_rel.article_id
        WHERE a.embedding IS NOT NULL
          AND a.create_time >= now() - INTERVAL '{actual_hours} hours'
          AND a.is_deleted = false
          AND (
            a.system_id = {p_system_id} 
            OR as_rel.system_id = {p_system_id}
            OR (a.is_shared = true AND a.system_id IS NOT NULL)
          )
        ORDER BY a.create_time DESC
        LIMIT {max_limit}
    """
    rows = plpy.execute(query)
    if len(rows) < actual_min_samples:
        return []  # 返回空列表而不是 None

    ids      = [r['id'] for r in rows]
    # PostgreSQL vector 类型在 PL/Python 中可能被转换为字符串，需要解析
    # 处理格式：'[0.1,0.2,0.3]' 或 '{0.1,0.2,0.3}' 或已经是列表
    vectors_list = []
    for r in rows:
        emb = r['embedding']
        if isinstance(emb, str):
            # 解析字符串格式的向量
            emb_clean = emb.strip('[]{}')
            vectors_list.append([float(x.strip()) for x in emb_clean.split(',') if x.strip()])
        elif hasattr(emb, '__iter__') and not isinstance(emb, str):
            # 如果已经是可迭代对象（列表、数组等），直接转换
            vectors_list.append(list(emb))
        else:
            # 单个值（不应该发生，但以防万一）
            vectors_list.append([float(emb)])
    vectors = np.array(vectors_list, dtype=np.float32)
    titles  = [r['title'] for r in rows]
    weights = [float(r['weight'] or 1) for r in rows]

    # DBSCAN 聚类
    db = DBSCAN(
        eps=actual_eps,
        min_samples=actual_min_samples,
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

        # 热度公式
        score = total_w * (np.log2(1 + count) ** 1.8)

        cluster_titles = [t for t, m in zip(titles, mask) if m]
        cluster_ids = [i for i, m in zip(ids, mask) if m]
        sample = " | ".join(cluster_titles[:4])

        # PL/Python set-returning 函数需要返回元组列表，每个元组对应 RETURNS TABLE 中的列
        result.append((
            int(cid),                    # cluster_id
            cluster_titles[0],           # title
            count,                       # article_count
            round(float(total_w), 4),    # total_weight
            round(float(score), 6),      # hot_score
            sample,                      # sample_titles
            cluster_ids                  # article_ids
        ))

    result.sort(key=lambda x: x[4], reverse=True)  # 按 hot_score (索引4) 排序
    return result
$$;

-- =====================================================
-- 8. 按系统刷新热点快照的函数
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_refresh_snapshot_by_system(p_system_id BIGINT)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_snapshot_ts TIMESTAMPTZ := now();
    v_config RECORD;
BEGIN
    -- 获取系统配置
    SELECT default_hours, default_eps, default_min_samples, snapshot_limit
    INTO v_config
    FROM hotd_system_configs
    WHERE system_id = p_system_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION '系统配置不存在: system_id=%', p_system_id;
    END IF;
    
    -- 删除该系统的旧快照
    DELETE FROM hotd_event_articles WHERE system_id = p_system_id;
    DELETE FROM hotd_event_snapshot WHERE system_id = p_system_id;
    
    -- 插入新快照
    WITH ranked_events AS (
        SELECT 
            row_number() OVER (ORDER BY hot_score DESC) AS rn,
            cluster_id, title, article_count, total_weight, hot_score, sample_titles, article_ids
        FROM hotd_event_clusters_by_system(
            p_system_id,
            v_config.default_hours,
            v_config.default_eps,
            v_config.default_min_samples
        )
        LIMIT v_config.snapshot_limit
    )
    INSERT INTO hotd_event_snapshot (
        snapshot_time, rank_no, system_id, cluster_id, title, 
        article_count, total_weight, hot_score, sample_titles
    )
    SELECT 
        v_snapshot_ts, rn, p_system_id, cluster_id, title,
        article_count, total_weight, hot_score, sample_titles
    FROM ranked_events;
    
    -- 插入文章关联关系
    WITH ranked_events AS (
        SELECT 
            row_number() OVER (ORDER BY hot_score DESC) AS rn,
            cluster_id, article_ids
        FROM hotd_event_clusters_by_system(
            p_system_id,
            v_config.default_hours,
            v_config.default_eps,
            v_config.default_min_samples
        )
        LIMIT v_config.snapshot_limit
    )
    INSERT INTO hotd_event_articles (
        snapshot_time, rank_no, system_id, cluster_id, article_id, article_weight
    )
    SELECT 
        v_snapshot_ts,
        re.rn,
        p_system_id,
        re.cluster_id,
        unnested.article_id,
        COALESCE(a.weight, 1.0) AS article_weight
    FROM ranked_events re
    CROSS JOIN LATERAL unnest(re.article_ids) AS unnested(article_id)
    LEFT JOIN hotd_articles a ON a.id = unnested.article_id;
END;
$$;

-- =====================================================
-- 9. 为每个系统创建独立的定时任务（动态创建）
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_setup_system_cron_jobs()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sys_rec RECORD;
    job_name TEXT;
BEGIN
    -- 为每个活跃系统创建定时任务
    FOR sys_rec IN 
        SELECT s.id, s.system_code, sc.embedding_cron, sc.clustering_cron
        FROM hotd_systems s
        JOIN hotd_system_configs sc ON s.id = sc.system_id
        WHERE s.is_active = true
    LOOP
        -- 向量化任务（所有系统共享，但可以按系统过滤）
        job_name := 'hotd-embed-' || sys_rec.system_code;
        PERFORM cron.unschedule(job_name);
        -- 注意：向量化是全局的，不需要按系统执行
        
        -- 聚类任务（每个系统独立）
        job_name := 'hotd-cluster-' || sys_rec.system_code;
        PERFORM cron.unschedule(job_name);
        PERFORM cron.schedule(
            job_name,
            sys_rec.clustering_cron,
            format('SELECT hotd_refresh_snapshot_by_system(%s)', sys_rec.id)
        );
    END LOOP;
END;
$$;

-- =====================================================
-- 10. 按系统批量向量化函数（支持多系统隔离）
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_embed_articles_batch_by_system(p_system_id BIGINT DEFAULT NULL)
RETURNS void LANGUAGE plpython3u AS $$
    from sentence_transformers import SentenceTransformer
    import numpy as np
    import os

    # 设置模型缓存目录（确保有写权限）
    cache_dir = '/tmp/.cache'
    if not os.path.exists(cache_dir):
        try:
            os.makedirs(cache_dir, mode=0o755, exist_ok=True)
        except:
            cache_dir = '/var/lib/postgresql/.cache'
            try:
                os.makedirs(cache_dir, mode=0o755, exist_ok=True)
            except:
                pass
    
    # 设置环境变量
    os.environ['TRANSFORMERS_CACHE'] = cache_dir
    os.environ['HF_HOME'] = cache_dir

    # 加载模型（全局缓存）
    if 'model' not in SD:
        SD['model'] = SentenceTransformer(
            'BAAI/bge-large-zh-v1.5',
            device='cpu',
            trust_remote_code=True,
            cache_folder=cache_dir
        )

    model = SD['model']

    # 构建查询（如果指定了系统ID，只处理该系统的文章）
    if p_system_id is not None:
        query = """
            SELECT DISTINCT a.id, 
                   a.title || '。' || COALESCE(a.summary, '') || '。' || COALESCE(a.full_text, '') AS text
            FROM hotd_articles a
            LEFT JOIN hotd_article_systems as_rel ON a.id = as_rel.article_id
            WHERE (a.embedding IS NULL OR a.embedding = '[0]'::vector)
              AND a.create_time > now() - INTERVAL '60 days'
              AND a.is_deleted = false
              AND (
                a.system_id = %s 
                OR as_rel.system_id = %s
                OR (a.is_shared = true AND a.system_id IS NOT NULL)
              )
            LIMIT 1500
        """ % (p_system_id, p_system_id)
    else:
        query = """
            SELECT id, 
                   title || '。' || COALESCE(summary, '') || '。' || COALESCE(full_text, '') AS text
            FROM hotd_articles
            WHERE (embedding IS NULL OR embedding = '[0]'::vector)
              AND create_time > now() - INTERVAL '60 days'
            LIMIT 1500
        """

    plan = plpy.prepare(query)
    rows = plpy.execute(plan)

    if not rows:
        return

    texts = [r['text'] for r in rows]
    ids   = [r['id']   for r in rows]

    # 批量编码 + 归一化
    embeddings = model.encode(
        texts,
        batch_size=32,
        normalize_embeddings=True,
        show_progress_bar=False
    )

    update_plan = plpy.prepare(
        "UPDATE hotd_articles SET embedding = $2 WHERE id = $1",
        ["bigint", "vector"]
    )
    for iid, vec in zip(ids, embeddings):
        plpy.execute(update_plan, [iid, list(vec.astype('float32'))])

    system_info = f"system_id={p_system_id}" if p_system_id is not None else "all systems"
    plpy.notice(f"[HotD] 本次成功向量化 {len(rows)} 条（{system_info}），使用模型：bge-large-zh-v1.5")
$$;

-- =====================================================
-- 按系统通过 HTTP API 批量向量化函数（多租户版本）
-- =====================================================
-- 功能：通过 HTTP API 调用外部 embedding 服务，支持按系统过滤
-- 参数说明：
--   p_system_id: 系统ID（可选，NULL 表示处理所有系统）
--   p_api_url: Embedding API 地址
--   p_api_key: API 密钥（可选）
--   p_model_name: 模型名称（可选）
--   p_batch_size: 每次 API 调用处理的文本数量（默认 50）
--
-- 调用示例：
--   SELECT hotd_embed_articles_batch_by_system_via_api(
--     1,  -- 系统ID
--     'http://localhost:8000/api/embedding',
--     'your-api-key',
--     'bge-large-zh-v1.5',
--     50
--   );
CREATE OR REPLACE FUNCTION hotd_embed_articles_batch_by_system_via_api(
    p_system_id  BIGINT DEFAULT NULL,
    p_api_url    TEXT DEFAULT 'http://localhost:8000/api/embedding',
    p_api_key    TEXT DEFAULT NULL,
    p_model_name TEXT DEFAULT NULL,
    p_batch_size INT  DEFAULT 50
)
RETURNS void LANGUAGE plpython3u AS $$
    import json
    import urllib.request
    import urllib.error
    import urllib.parse

    # 构建查询（如果指定了系统ID，只处理该系统的文章）
    if p_system_id is not None:
        query = """
            SELECT DISTINCT a.id, 
                   a.title || '。' || COALESCE(a.summary, '') || '。' || COALESCE(a.full_text, '') AS text
            FROM hotd_articles a
            LEFT JOIN hotd_article_systems as_rel ON a.id = as_rel.article_id
            WHERE (a.embedding IS NULL OR a.embedding = '[0]'::vector)
              AND a.create_time > now() - INTERVAL '60 days'
              AND a.is_deleted = false
              AND (
                a.system_id = %s 
                OR as_rel.system_id = %s
                OR (a.is_shared = true AND a.system_id IS NOT NULL)
              )
            LIMIT 1500
        """ % (p_system_id, p_system_id)
    else:
        query = """
            SELECT id, 
                   title || '。' || COALESCE(summary, '') || '。' || COALESCE(full_text, '') AS text
            FROM hotd_articles
            WHERE (embedding IS NULL OR embedding = '[0]'::vector)
              AND create_time > now() - INTERVAL '60 days'
            LIMIT 1500
        """

    plan = plpy.prepare(query)
    rows = plpy.execute(plan)

    if not rows:
        plpy.notice(f"[HotD] 没有待向量化的文章，系统ID: {p_system_id if p_system_id else 'ALL'}")
        return

    texts = [r['text'] for r in rows]
    ids   = [r['id']   for r in rows]
    total = len(texts)
    
    plpy.notice(f"[HotD] 开始通过 HTTP API 向量化 {total} 条文章，系统ID: {p_system_id if p_system_id else 'ALL'}，API: {p_api_url}")

    # 准备请求头
    headers = {
        'Content-Type': 'application/json'
    }
    if p_api_key:
        headers['Authorization'] = f'Bearer {p_api_key}'

    # 批量调用 API
    all_embeddings = []
    processed = 0
    
    for i in range(0, total, p_batch_size):
        batch_texts = texts[i:i + p_batch_size]
        batch_ids = ids[i:i + p_batch_size]
        
        # 构建请求体
        request_body = {
            'texts': batch_texts
        }
        if p_model_name:
            request_body['model'] = p_model_name
        
        try:
            # 发送 HTTP 请求
            req = urllib.request.Request(
                p_api_url,
                data=json.dumps(request_body).encode('utf-8'),
                headers=headers,
                method='POST'
            )
            
            with urllib.request.urlopen(req, timeout=300) as response:
                response_data = json.loads(response.read().decode('utf-8'))
            
            # 解析响应（支持多种格式）
            batch_embeddings = None
            if 'embeddings' in response_data:
                batch_embeddings = response_data['embeddings']
            elif 'data' in response_data:
                batch_embeddings = [item['embedding'] for item in response_data['data']]
            elif isinstance(response_data, list):
                if len(response_data) > 0 and isinstance(response_data[0], dict):
                    batch_embeddings = [item.get('embedding', item) for item in response_data]
                else:
                    batch_embeddings = response_data
            else:
                raise ValueError(f"无法解析 API 响应格式: {response_data.keys() if isinstance(response_data, dict) else type(response_data)}")
            
            if len(batch_embeddings) != len(batch_texts):
                raise ValueError(f"API 返回的向量数量 ({len(batch_embeddings)}) 与请求的文本数量 ({len(batch_texts)}) 不匹配")
            
            all_embeddings.extend(batch_embeddings)
            processed += len(batch_texts)
            
            plpy.notice(f"[HotD] 已处理 {processed}/{total} 条文章")
            
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8') if hasattr(e, 'read') else str(e)
            plpy.error(f"HTTP API 调用失败 (状态码 {e.code}): {error_body}")
        except urllib.error.URLError as e:
            plpy.error(f"无法连接到 API 服务器 {p_api_url}: {str(e)}")
        except json.JSONDecodeError as e:
            plpy.error(f"API 响应不是有效的 JSON: {str(e)}")
        except Exception as e:
            plpy.error(f"处理 API 响应时出错: {str(e)}")

    if len(all_embeddings) != total:
        plpy.error(f"向量化数量不匹配: 期望 {total}，实际 {len(all_embeddings)}")

    # 更新数据库
    update_plan = plpy.prepare(
        "UPDATE hotd_articles SET embedding = $2 WHERE id = $1",
        ["bigint", "vector"]
    )
    
    for iid, vec in zip(ids, all_embeddings):
        # 确保向量是列表格式，并转换为 float32
        if not isinstance(vec, list):
            vec = list(vec)
        vec_float32 = [float(x) for x in vec]
        plpy.execute(update_plan, [iid, vec_float32])

    plpy.notice(f"[HotD] 本次成功通过 HTTP API 向量化 {total} 条文章，系统ID: {p_system_id if p_system_id else 'ALL'}，API: {p_api_url}")
$$;

-- =====================================================
-- 11. 辅助函数：根据系统代码获取系统ID
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_get_system_id(p_system_code VARCHAR)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_system_id BIGINT;
BEGIN
    SELECT id INTO v_system_id
    FROM hotd_systems
    WHERE system_code = p_system_code AND is_active = true;
    
    IF v_system_id IS NULL THEN
        RAISE EXCEPTION '系统不存在或已禁用: system_code=%', p_system_code;
    END IF;
    
    RETURN v_system_id;
END;
$$;

-- =====================================================
-- 12. 辅助函数：检查系统是否存在
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_system_exists(p_system_code VARCHAR)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM hotd_systems 
        WHERE system_code = p_system_code AND is_active = true
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$;

-- =====================================================
-- 13. 数据迁移函数：将旧数据迁移到默认系统
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_migrate_to_default_system()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_default_system_id BIGINT;
    v_migrated_count BIGINT;
BEGIN
    -- 获取默认系统ID
    SELECT id INTO v_default_system_id
    FROM hotd_systems
    WHERE system_code = 'default';
    
    IF v_default_system_id IS NULL THEN
        RAISE EXCEPTION '默认系统不存在，请先运行初始化脚本';
    END IF;
    
    -- 迁移没有 system_id 的文章到默认系统
    UPDATE hotd_articles
    SET system_id = v_default_system_id
    WHERE system_id IS NULL;
    
    GET DIAGNOSTICS v_migrated_count = ROW_COUNT;
    
    RAISE NOTICE '已迁移 % 条文章到默认系统', v_migrated_count;
    
    -- 迁移没有 system_id 的快照到默认系统
    UPDATE hotd_event_snapshot
    SET system_id = v_default_system_id
    WHERE system_id IS NULL;
    
    GET DIAGNOSTICS v_migrated_count = ROW_COUNT;
    
    RAISE NOTICE '已迁移 % 条快照到默认系统', v_migrated_count;
    
    -- 迁移没有 system_id 的文章关联到默认系统
    UPDATE hotd_event_articles
    SET system_id = v_default_system_id
    WHERE system_id IS NULL;
    
    GET DIAGNOSTICS v_migrated_count = ROW_COUNT;
    
    RAISE NOTICE '已迁移 % 条文章关联到默认系统', v_migrated_count;
END;
$$;

-- =====================================================
-- 14. 视图：系统热点事件概览（方便查询）
-- =====================================================
CREATE OR REPLACE VIEW hotd_system_hot_events_view AS
SELECT 
    s.id AS system_id,
    s.system_code,
    s.system_name,
    es.snapshot_time,
    es.rank_no,
    es.cluster_id,
    es.title,
    es.article_count,
    es.total_weight,
    es.hot_score,
    es.sample_titles
FROM hotd_systems s
JOIN hotd_event_snapshot es ON s.id = es.system_id
WHERE s.is_active = true
ORDER BY s.system_code, es.snapshot_time DESC, es.rank_no;

-- =====================================================
-- 15. 视图：系统文章统计（方便查询）
-- =====================================================
CREATE OR REPLACE VIEW hotd_system_article_stats_view AS
SELECT 
    s.id AS system_id,
    s.system_code,
    s.system_name,
    COUNT(DISTINCT a.id) AS total_articles,
    COUNT(DISTINCT CASE WHEN a.embedding IS NOT NULL THEN a.id END) AS embedded_articles,
    COUNT(DISTINCT CASE WHEN a.is_shared = true THEN a.id END) AS shared_articles,
    COUNT(DISTINCT CASE WHEN a.is_deleted = false THEN a.id END) AS active_articles,
    MAX(a.create_time) AS latest_article_time
FROM hotd_systems s
LEFT JOIN hotd_articles a ON s.id = a.system_id
LEFT JOIN hotd_article_systems as_rel ON a.id = as_rel.article_id AND as_rel.system_id = s.id
WHERE s.is_active = true
GROUP BY s.id, s.system_code, s.system_name;

-- =====================================================
-- 16. 改进定时任务设置函数（支持向量化任务）
-- =====================================================
CREATE OR REPLACE FUNCTION hotd_setup_system_cron_jobs()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sys_rec RECORD;
    job_name TEXT;
BEGIN
    -- 为每个活跃系统创建定时任务
    FOR sys_rec IN 
        SELECT s.id, s.system_code, sc.embedding_cron, sc.clustering_cron
        FROM hotd_systems s
        JOIN hotd_system_configs sc ON s.id = sc.system_id
        WHERE s.is_active = true
    LOOP
        -- 向量化任务（按系统执行，支持隔离）
        job_name := 'hotd-embed-' || sys_rec.system_code;
        BEGIN
            PERFORM cron.unschedule(job_name);
        EXCEPTION
            WHEN OTHERS THEN
                NULL;  -- 忽略错误（任务可能不存在）
        END;
        
        PERFORM cron.schedule(
            job_name,
            sys_rec.embedding_cron,
            format('SELECT hotd_embed_articles_batch_by_system(%s)', sys_rec.id)
        );
        
        -- 聚类任务（每个系统独立）
        job_name := 'hotd-cluster-' || sys_rec.system_code;
        BEGIN
            PERFORM cron.unschedule(job_name);
        EXCEPTION
            WHEN OTHERS THEN
                NULL;  -- 忽略错误（任务可能不存在）
        END;
        
        PERFORM cron.schedule(
            job_name,
            sys_rec.clustering_cron,
            format('SELECT hotd_refresh_snapshot_by_system(%s)', sys_rec.id)
        );
    END LOOP;
    
    RAISE NOTICE '定时任务设置完成';
END;
$$;

-- =====================================================
-- 17. 初始化默认系统（可选）
-- =====================================================
INSERT INTO hotd_systems (system_code, system_name, description) 
VALUES ('default', '默认系统', '系统默认租户')
ON CONFLICT (system_code) DO NOTHING;

INSERT INTO hotd_system_configs (system_id, default_hours, default_eps, default_min_samples)
SELECT id, 24, 0.38, 3
FROM hotd_systems
WHERE system_code = 'default'
ON CONFLICT (system_id) DO NOTHING;

-- =====================================================
-- 18. 自动迁移旧数据到默认系统（可选，首次运行时执行）
-- =====================================================
-- 注意：如果这是首次运行多租户扩展，可以取消下面的注释来自动迁移数据
-- SELECT hotd_migrate_to_default_system();

-- =====================================================
-- 19. 设置定时任务（可选，首次运行时执行）
-- =====================================================
-- 注意：如果 pg_cron 扩展已加载，可以取消下面的注释来自动设置定时任务
-- SELECT hotd_setup_system_cron_jobs();
