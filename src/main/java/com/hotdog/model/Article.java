package com.hotdog.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.vladmihalcea.hibernate.type.json.JsonBinaryType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Type;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 文章实体
 */
@Entity
@Table(name = "hotd_articles", indexes = {
    @Index(name = "hotd_idx_articles_time", columnList = "create_time DESC"),
    @Index(name = "hotd_idx_articles_weight", columnList = "weight DESC"),
    @Index(name = "hotd_idx_articles_deleted", columnList = "is_deleted")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Article {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "system_id")
    private Long systemId;
    
    @Column(name = "is_shared")
    private Boolean isShared = false;
    
    @Column(nullable = false, length = 1000)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String summary;
    
    @Column(name = "full_text", columnDefinition = "TEXT")
    private String fullText;
    
    @Column(nullable = false, precision = 16, scale = 4)
    private BigDecimal weight = BigDecimal.ONE;
    
    @Column(name = "create_time", nullable = false, updatable = false)
    private LocalDateTime createTime;
    
    private String source;
    
    @Column(columnDefinition = "JSONB")
    @Type(JsonBinaryType.class)
    private ArticleMetadata attr;
    
    @Column(columnDefinition = "vector(1024)")
    @JsonIgnore
    private float[] embedding;
    
    @Column(name = "is_deleted")
    private Boolean isDeleted = false;
    
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
