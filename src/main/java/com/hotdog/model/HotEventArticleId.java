package com.hotdog.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * 热点事件-文章关联主键
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class HotEventArticleId implements Serializable {
    
    private LocalDateTime snapshotTime;
    private Integer rankNo;
    private Long articleId;
    private Long systemId;
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        HotEventArticleId that = (HotEventArticleId) o;
        return Objects.equals(snapshotTime, that.snapshotTime) &&
               Objects.equals(rankNo, that.rankNo) &&
               Objects.equals(articleId, that.articleId) &&
               Objects.equals(systemId, that.systemId);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(snapshotTime, rankNo, articleId, systemId);
    }
}
