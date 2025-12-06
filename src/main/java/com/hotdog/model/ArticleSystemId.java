package com.hotdog.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.Objects;

/**
 * 文章-系统关联主键
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ArticleSystemId implements Serializable {
    
    private Long articleId;
    private Long systemId;
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        ArticleSystemId that = (ArticleSystemId) o;
        return Objects.equals(articleId, that.articleId) &&
               Objects.equals(systemId, that.systemId);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(articleId, systemId);
    }
}
