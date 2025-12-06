package com.hotdog.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 文章元数据
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ArticleMetadata {
    private String author;
    private List<String> tags;
    private String category;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss'Z'")
    private LocalDateTime publishTime;
    
    private String url;
    
    // 可扩展其他字段
    private String publisher;
    private Integer viewCount;
    private Integer likeCount;
}
