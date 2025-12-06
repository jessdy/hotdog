-- =====================================================
-- 多租户架构扩展：支持多系统使用，数据隔离，独立配置
-- =====================================================

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
DROP INDEX IF EXISTS hotd_event_snapshot_pkey;
ALTER TABLE hotd_event_snapshot DROP CONSTRAINT IF EXISTS hotd_event_snapshot_pkey;
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
DROP INDEX IF EXISTS hotd_event_articles_pkey;
ALTER TABLE hotd_event_articles DROP CONSTRAINT IF EXISTS hotd_event_articles_pkey;
ALTER TABLE hotd_event_articles ADD PRIMARY KEY (snapshot_time, rank_no, article_id, system_id);

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
    query = f"""
        SELECT DISTINCT a.id, a.title, a.weight, a.embedding
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
        return

    ids      = [r['id'] for r in rows]
    vectors = np.array([r['embedding'] for r in rows])
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
        unnest(re.article_ids) AS article_id,
        COALESCE(a.weight, 1.0) AS article_weight
    FROM ranked_events re
    CROSS JOIN LATERAL unnest(re.article_ids) AS article_id
    LEFT JOIN hotd_articles a ON a.id = article_id;
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
-- 10. 初始化默认系统（可选）
-- =====================================================
INSERT INTO hotd_systems (system_code, system_name, description) 
VALUES ('default', '默认系统', '系统默认租户')
ON CONFLICT (system_code) DO NOTHING;

INSERT INTO hotd_system_configs (system_id, default_hours, default_eps, default_min_samples)
SELECT id, 24, 0.38, 3
FROM hotd_systems
WHERE system_code = 'default'
ON CONFLICT (system_id) DO NOTHING;
