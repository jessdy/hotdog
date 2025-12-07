package com.hotdog.repository;

import com.hotdog.model.ArticleSystem;
import com.hotdog.model.ArticleSystemId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 文章-系统关联数据访问接口
 */
@Repository
public interface ArticleSystemRepository extends JpaRepository<ArticleSystem, ArticleSystemId> {
    
    /**
     * 根据系统ID查询关联的文章ID列表
     */
    @Query("SELECT as_rel.articleId FROM ArticleSystem as_rel WHERE as_rel.systemId = :systemId")
    List<Long> findArticleIdsBySystemId(@Param("systemId") Long systemId);
    
    /**
     * 根据文章ID查询关联的系统ID列表
     */
    @Query("SELECT as_rel.systemId FROM ArticleSystem as_rel WHERE as_rel.articleId = :articleId")
    List<Long> findSystemIdsByArticleId(@Param("articleId") Long articleId);
    
    /**
     * 删除文章与系统的关联
     */
    @Modifying
    @Query("DELETE FROM ArticleSystem as_rel WHERE as_rel.articleId = :articleId AND as_rel.systemId = :systemId")
    void deleteByArticleIdAndSystemId(@Param("articleId") Long articleId, @Param("systemId") Long systemId);
    
    /**
     * 删除文章的所有关联
     */
    @Modifying
    @Query("DELETE FROM ArticleSystem as_rel WHERE as_rel.articleId = :articleId")
    void deleteByArticleId(@Param("articleId") Long articleId);
}
