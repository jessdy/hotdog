package com.hotdog.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 文章-系统关联实体（支持数据源重叠）
 */
@Entity
@Table(name = "hotd_article_systems", indexes = {
    @Index(name = "hotd_idx_article_systems_system", columnList = "system_id"),
    @Index(name = "hotd_idx_article_systems_article", columnList = "article_id")
})
@IdClass(ArticleSystemId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ArticleSystem {
    
    @Id
    @Column(name = "article_id")
    private Long articleId;
    
    @Id
    @Column(name = "system_id")
    private Long systemId;
    
    @Column(name = "create_time", nullable = false, updatable = false)
    private LocalDateTime createTime;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "article_id", insertable = false, updatable = false)
    private Article article;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "system_id", insertable = false, updatable = false)
    private System system;
    
    @PrePersist
    protected void onCreate() {
        if (createTime == null) {
            createTime = LocalDateTime.now();
        }
    }
}
