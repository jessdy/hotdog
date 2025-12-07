package com.hotdog.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 系统配置实体
 */
@Entity
@Table(name = "hotd_system_configs")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SystemConfig {
    
    @Id
    @Column(name = "system_id")
    private Long systemId;
    
    @OneToOne
    @JoinColumn(name = "system_id")
    @MapsId
    private System system;
    
    @Column(name = "default_hours")
    private Integer defaultHours = 24;
    
    @Column(name = "default_eps", columnDefinition = "FLOAT")
    private Float defaultEps = 0.38f;
    
    @Column(name = "default_min_samples")
    private Integer defaultMinSamples = 3;
    
    @Column(name = "embedding_cron", length = 64)
    private String embeddingCron = "*/8 * * * *";
    
    @Column(name = "clustering_cron", length = 64)
    private String clusteringCron = "*/12 * * * *";
    
    @Column(name = "max_articles_limit")
    private Integer maxArticlesLimit = 80000;
    
    @Column(name = "snapshot_limit")
    private Integer snapshotLimit = 100;
    
    @Column(name = "create_time", nullable = false, updatable = false)
    private LocalDateTime createTime;
    
    @Column(name = "update_time", nullable = false)
    private LocalDateTime updateTime;
    
    @PrePersist
    protected void onCreate() {
        if (createTime == null) {
            createTime = LocalDateTime.now();
        }
        if (updateTime == null) {
            updateTime = LocalDateTime.now();
        }
    }
    
    @PreUpdate
    protected void onUpdate() {
        updateTime = LocalDateTime.now();
    }
}
