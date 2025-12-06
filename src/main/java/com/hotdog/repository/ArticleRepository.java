package com.hotdog.repository;

import com.hotdog.model.Article;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

/**
 * 文章数据访问接口
 */
@Repository
public interface ArticleRepository extends JpaRepository<Article, Long> {
    
    /**
     * 根据来源查询文章
     */
    Page<Article> findBySourceAndIsDeletedFalse(String source, Pageable pageable);
    
    /**
     * 根据权重范围查询文章
     */
    @Query("SELECT a FROM Article a WHERE a.weight >= :minWeight AND a.isDeleted = false")
    Page<Article> findByMinWeight(@Param("minWeight") BigDecimal minWeight, Pageable pageable);
    
    /**
     * 根据来源和权重查询文章
     */
    @Query("SELECT a FROM Article a WHERE " +
           "(:source IS NULL OR a.source = :source) AND " +
           "(:minWeight IS NULL OR a.weight >= :minWeight) AND " +
           "a.isDeleted = false")
    Page<Article> findBySourceAndMinWeight(
        @Param("source") String source,
        @Param("minWeight") BigDecimal minWeight,
        Pageable pageable
    );
    
    /**
     * 更新文章权重
     */
    @Modifying
    @Query("UPDATE Article a SET a.weight = :weight WHERE a.id = :id")
    void updateWeight(@Param("id") Long id, @Param("weight") BigDecimal weight);
    
    /**
     * 查询待向量化的文章数量
     */
    @Query(value = "SELECT COUNT(*) FROM hotd_articles " +
           "WHERE (embedding IS NULL OR embedding = '[0]'::vector) " +
           "AND create_time > now() - INTERVAL '60 days'", nativeQuery = true)
    Long countPendingEmbedding();
    
    /**
     * 根据ID列表查询文章
     */
    List<Article> findByIdIn(List<Long> ids);
    
    /**
     * 按系统ID和筛选条件查询文章（包括共享文章）
     */
    @Query("SELECT DISTINCT a FROM Article a " +
           "LEFT JOIN ArticleSystem as_rel ON a.id = as_rel.articleId " +
           "WHERE a.isDeleted = false " +
           "AND (a.systemId = :systemId OR as_rel.systemId = :systemId OR (a.isShared = true AND a.systemId IS NOT NULL)) " +
           "AND (:source IS NULL OR a.source = :source) " +
           "AND (:minWeight IS NULL OR a.weight >= :minWeight)")
    Page<Article> findBySystemIdAndFilters(
        @Param("systemId") Long systemId,
        @Param("source") String source,
        @Param("minWeight") BigDecimal minWeight,
        Pageable pageable
    );
}
