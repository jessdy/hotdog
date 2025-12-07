package com.hotdog.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 向量化服务（调用 PostgreSQL 函数）
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EmbeddingService {
    
    private final JdbcTemplate jdbcTemplate;
    
    /**
     * 触发批量向量化（调用 PostgreSQL 函数）
     */
    @Transactional
    public void triggerBatchEmbedding() {
        log.info("触发批量向量化...");
        try {
            // 对于返回 void 的函数，使用 query 方法执行 SELECT 语句并忽略结果
            jdbcTemplate.query("SELECT hotd_embed_articles_batch()", rs -> {
                // 函数返回 void，忽略结果集
            });
            log.info("批量向量化完成");
        } catch (Exception e) {
            log.error("批量向量化失败", e);
            throw new RuntimeException("批量向量化失败: " + e.getMessage(), e);
        }
    }
    
    /**
     * 获取待向量化的文章数量
     */
    public Long getPendingEmbeddingCount() {
        String sql = """
            SELECT COUNT(*) 
            FROM hotd_articles 
            WHERE (embedding IS NULL OR embedding = '[0]'::vector)
              AND create_time > now() - INTERVAL '60 days'
        """;
        try {
            Long count = jdbcTemplate.queryForObject(sql, Long.class);
            return count != null ? count : 0L;
        } catch (Exception e) {
            log.error("查询待向量化文章数量失败", e);
            return 0L;
        }
    }
}
