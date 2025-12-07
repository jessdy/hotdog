package com.hotdog.service;

import com.hotdog.dto.HotEventResponseDTO;
import com.hotdog.config.SystemContext;
import com.hotdog.model.Article;
import com.hotdog.model.HotEvent;
import com.hotdog.repository.ArticleRepository;
import com.hotdog.repository.HotEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Array;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * 热点查询服务
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class HotEventService {
    
    private final HotEventRepository hotEventRepository;
    private final ArticleRepository articleRepository;
    private final JdbcTemplate jdbcTemplate;
    
    /**
     * 查询实时热点事件（调用聚类函数，支持多系统）
     */
    public List<HotEventResponseDTO> getRealTimeHotEvents(
            Long systemId, Integer hours, Float eps, Integer minSamples, Integer limit) {
        // 如果没有指定 systemId，从上下文获取
        if (systemId == null) {
            systemId = SystemContext.getSystemId();
        }
        
        // 如果指定了 systemId，使用多系统聚类函数
        if (systemId != null) {
            return getRealTimeHotEventsBySystem(systemId, hours, eps, minSamples, limit);
        }
        
        // 否则使用全局聚类函数（向后兼容）
        String sql = """
            SELECT 
                row_number() OVER (ORDER BY hot_score DESC) AS rank_no,
                cluster_id, title, article_count, 
                total_weight, hot_score, sample_titles, article_ids
            FROM hotd_event_clusters(?, ?, ?)
            LIMIT ?
        """;
        
        try {
            return jdbcTemplate.query(sql, 
                new Object[]{hours != null ? hours : 24, 
                           eps != null ? eps : 0.38f, 
                           minSamples != null ? minSamples : 3, 
                           limit},
                (rs, rowNum) -> {
                    HotEventResponseDTO dto = new HotEventResponseDTO();
                    dto.setRank(rs.getInt("rank_no"));
                    dto.setClusterId(rs.getLong("cluster_id"));
                    dto.setTitle(rs.getString("title"));
                    dto.setArticleCount(rs.getLong("article_count"));
                    dto.setTotalWeight(rs.getBigDecimal("total_weight"));
                    dto.setHotScore(rs.getBigDecimal("hot_score"));
                    dto.setSampleTitles(rs.getString("sample_titles"));
                    
                    Array articleIdsArray = rs.getArray("article_ids");
                    if (articleIdsArray != null) {
                        Long[] articleIds = (Long[]) articleIdsArray.getArray();
                        dto.setArticleIds(Arrays.asList(articleIds));
                    }
                    
                    return dto;
                });
        } catch (Exception e) {
            log.error("查询实时热点事件失败", e);
            throw new RuntimeException("查询实时热点事件失败: " + e.getMessage(), e);
        }
    }
    
    /**
     * 按系统查询实时热点事件
     */
    public List<HotEventResponseDTO> getRealTimeHotEventsBySystem(
            Long systemId, Integer hours, Float eps, Integer minSamples, Integer limit) {
        String sql = """
            SELECT 
                row_number() OVER (ORDER BY hot_score DESC) AS rank_no,
                cluster_id, title, article_count, 
                total_weight, hot_score, sample_titles, article_ids
            FROM hotd_event_clusters_by_system(?, ?, ?, ?)
            LIMIT ?
        """;
        
        try {
            return jdbcTemplate.query(sql, 
                new Object[]{systemId, hours, eps, minSamples, limit},
                (rs, rowNum) -> {
                    HotEventResponseDTO dto = new HotEventResponseDTO();
                    dto.setRank(rs.getInt("rank_no"));
                    dto.setClusterId(rs.getLong("cluster_id"));
                    dto.setTitle(rs.getString("title"));
                    dto.setArticleCount(rs.getLong("article_count"));
                    dto.setTotalWeight(rs.getBigDecimal("total_weight"));
                    dto.setHotScore(rs.getBigDecimal("hot_score"));
                    dto.setSampleTitles(rs.getString("sample_titles"));
                    
                    Array articleIdsArray = rs.getArray("article_ids");
                    if (articleIdsArray != null) {
                        Long[] articleIds = (Long[]) articleIdsArray.getArray();
                        dto.setArticleIds(Arrays.asList(articleIds));
                    }
                    
                    return dto;
                });
        } catch (Exception e) {
            log.error("查询系统实时热点事件失败: systemId={}", systemId, e);
            throw new RuntimeException("查询系统实时热点事件失败: " + e.getMessage(), e);
        }
    }
    
    /**
     * 从快照表查询热点事件（高性能，适合高并发，支持多系统）
     */
    public List<HotEvent> getHotEventsFromSnapshot(Long systemId, Integer limit) {
        // 如果没有指定 systemId，从上下文获取
        if (systemId == null) {
            systemId = SystemContext.getSystemId();
        }
        
        // 如果指定了 systemId，使用系统过滤查询
        if (systemId != null) {
            return getHotEventsFromSnapshotBySystem(systemId, limit);
        }
        
        // 否则使用全局查询（向后兼容）
        try {
            List<HotEvent> events = hotEventRepository.findLatestSnapshot();
            if (limit != null && limit > 0 && events.size() > limit) {
                return events.subList(0, limit);
            }
            return events;
        } catch (Exception e) {
            log.error("从快照表查询热点事件失败", e);
            return new ArrayList<>();
        }
    }
    
    /**
     * 按系统从快照表查询热点事件
     */
    public List<HotEvent> getHotEventsFromSnapshotBySystem(Long systemId, Integer limit) {
        try {
            List<HotEvent> events = hotEventRepository.findLatestSnapshotBySystem(systemId);
            if (limit != null && limit > 0 && events.size() > limit) {
                return events.subList(0, limit);
            }
            return events;
        } catch (Exception e) {
            log.error("从快照表查询系统热点事件失败: systemId={}", systemId, e);
            return new ArrayList<>();
        }
    }
    
    /**
     * 手动刷新热点快照（支持多系统）
     */
    @Transactional
    public void refreshHotEventSnapshot(Long systemId) {
        // 如果没有指定 systemId，从上下文获取
        if (systemId == null) {
            systemId = SystemContext.getSystemId();
        }
        
        if (systemId == null) {
            throw new RuntimeException("系统ID不能为空");
        }
        
        log.info("开始刷新系统热点快照: systemId={}", systemId);
        try {
            jdbcTemplate.execute("SELECT hotd_refresh_snapshot_by_system(" + systemId + ")");
            log.info("系统热点快照刷新完成: systemId={}", systemId);
        } catch (Exception e) {
            log.error("刷新系统热点快照失败: systemId={}", systemId, e);
            throw new RuntimeException("刷新系统热点快照失败: " + e.getMessage(), e);
        }
    }
    
    /**
     * 获取热点事件的原始文章列表（从快照表，支持多系统）
     */
    public List<Article> getHotEventArticles(Long systemId, Integer rankNo, Integer limit) {
        // 如果没有指定 systemId，从上下文获取
        if (systemId == null) {
            systemId = SystemContext.getSystemId();
        }
        
        if (systemId == null) {
            throw new RuntimeException("系统ID不能为空");
        }
        
        String sql = """
            SELECT a.id, a.title, a.summary, a.full_text, a.weight, 
                   a.create_time, a.source, a.attr
            FROM hotd_event_snapshot es
            JOIN hotd_event_articles ea ON es.snapshot_time = ea.snapshot_time 
                                        AND es.rank_no = ea.rank_no
                                        AND es.system_id = ea.system_id
            JOIN hotd_articles a ON ea.article_id = a.id
            WHERE es.snapshot_time = (SELECT MAX(snapshot_time) FROM hotd_event_snapshot WHERE system_id = ?)
              AND es.system_id = ?
              AND es.rank_no = ?
              AND a.is_deleted = false
            ORDER BY a.weight DESC, a.create_time DESC
            LIMIT ?
        """;
        
        try {
            return jdbcTemplate.query(sql, 
                new Object[]{systemId, systemId, rankNo, limit},
                (rs, rowNum) -> {
                    Article article = new Article();
                    article.setId(rs.getLong("id"));
                    article.setTitle(rs.getString("title"));
                    article.setSummary(rs.getString("summary"));
                    article.setFullText(rs.getString("full_text"));
                    article.setWeight(rs.getBigDecimal("weight"));
                    article.setCreateTime(rs.getTimestamp("create_time").toLocalDateTime());
                    article.setSource(rs.getString("source"));
                    return article;
                });
        } catch (Exception e) {
            log.error("获取系统热点事件文章列表失败: systemId={}, rankNo={}", systemId, rankNo, e);
            throw new RuntimeException("获取系统热点事件文章列表失败: " + e.getMessage(), e);
        }
    }
    
    /**
     * 根据聚类ID获取实时热点事件的原始文章列表（支持多系统）
     */
    public List<Article> getRealTimeHotEventArticles(Long systemId, Long clusterId, Integer hours, Integer limit) {
        // 如果没有指定 systemId，从上下文获取
        if (systemId == null) {
            systemId = SystemContext.getSystemId();
        }
        
        if (systemId == null) {
            throw new RuntimeException("系统ID不能为空");
        }
        
        String sql = """
            SELECT a.id, a.title, a.summary, a.full_text, a.weight, 
                   a.create_time, a.source, a.attr
            FROM hotd_event_clusters_by_system(?, ?, NULL, NULL) ec
            CROSS JOIN LATERAL unnest(ec.article_ids) AS article_id
            JOIN hotd_articles a ON a.id = article_id
            WHERE ec.cluster_id = ?
            ORDER BY a.weight DESC, a.create_time DESC
            LIMIT ?
        """;
        
        try {
            return jdbcTemplate.query(sql, 
                new Object[]{systemId, hours != null ? hours : 24, clusterId, limit},
                (rs, rowNum) -> {
                    Article article = new Article();
                    article.setId(rs.getLong("id"));
                    article.setTitle(rs.getString("title"));
                    article.setSummary(rs.getString("summary"));
                    article.setFullText(rs.getString("full_text"));
                    article.setWeight(rs.getBigDecimal("weight"));
                    article.setCreateTime(rs.getTimestamp("create_time").toLocalDateTime());
                    article.setSource(rs.getString("source"));
                    return article;
                });
        } catch (Exception e) {
            log.error("获取系统实时热点事件文章列表失败: systemId={}, clusterId={}", systemId, clusterId, e);
            throw new RuntimeException("获取系统实时热点事件文章列表失败: " + e.getMessage(), e);
        }
    }
}
