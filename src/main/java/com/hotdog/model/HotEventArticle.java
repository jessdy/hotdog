package com.hotdog.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 热点事件-文章关联实体
 */
@Entity
@Table(name = "hotd_event_articles", indexes = {
    @Index(name = "hotd_idx_event_articles_cluster", columnList = "cluster_id"),
    @Index(name = "hotd_idx_event_articles_article", columnList = "article_id"),
    @Index(name = "hotd_idx_event_articles_snapshot", columnList = "snapshot_time, rank_no")
})
@IdClass(HotEventArticleId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class HotEventArticle {
    
    @Id
    @Column(name = "snapshot_time")
    private LocalDateTime snapshotTime;
    
    @Id
    @Column(name = "rank_no")
    private Integer rankNo;
    
    @Id
    @Column(name = "article_id")
    private Long articleId;
    
    @Id
    @Column(name = "system_id")
    private Long systemId;
    
    @Column(name = "cluster_id")
    private Long clusterId;
    
    @Column(name = "article_weight", precision = 16, scale = 4)
    private BigDecimal articleWeight;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumns({
        @JoinColumn(name = "snapshot_time", insertable = false, updatable = false),
        @JoinColumn(name = "rank_no", insertable = false, updatable = false)
    })
    private HotEvent hotEvent;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "article_id", insertable = false, updatable = false)
    private Article article;
}
