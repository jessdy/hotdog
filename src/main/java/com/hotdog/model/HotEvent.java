package com.hotdog.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 热点事件快照实体
 */
@Entity
@Table(name = "hotd_event_snapshot")
@IdClass(HotEventSnapshotId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class HotEvent {
    
    @Id
    @Column(name = "snapshot_time")
    private LocalDateTime snapshotTime;
    
    @Id
    @Column(name = "rank_no")
    private Integer rankNo;
    
    @Id
    @Column(name = "system_id")
    private Long systemId;
    
    @Column(name = "cluster_id")
    private Long clusterId;
    
    private String title;
    
    @Column(name = "article_count")
    private Long articleCount;
    
    @Column(name = "total_weight", precision = 16, scale = 4)
    private BigDecimal totalWeight;
    
    @Column(name = "hot_score", precision = 18, scale = 6)
    private BigDecimal hotScore;
    
    @Column(name = "sample_titles", columnDefinition = "TEXT")
    private String sampleTitles;
    
    @Column(name = "hours_window")
    private Integer hoursWindow;
    
    @Column(name = "model_name")
    private String modelName;
}
