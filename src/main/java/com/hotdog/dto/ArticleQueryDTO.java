package com.hotdog.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 文章查询DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ArticleQueryDTO {
    private String source;
    private BigDecimal minWeight;
    private BigDecimal maxWeight;
    private String keyword; // 标题关键词搜索
}
