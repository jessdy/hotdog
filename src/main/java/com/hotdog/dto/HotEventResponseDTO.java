package com.hotdog.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

/**
 * 热点事件响应DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class HotEventResponseDTO {
    private Integer rank;
    private Long clusterId;
    private String title;
    private Long articleCount;
    private BigDecimal totalWeight;
    private BigDecimal hotScore;
    private String sampleTitles;
    private List<Long> articleIds; // 文章ID列表
}
