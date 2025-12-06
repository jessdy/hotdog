package com.hotdog.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 系统配置DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SystemConfigDTO {
    private Integer defaultHours = 24;
    private Float defaultEps = 0.38f;
    private Integer defaultMinSamples = 3;
    private String embeddingCron = "*/8 * * * *";
    private String clusteringCron = "*/12 * * * *";
    private Integer maxArticlesLimit = 80000;
    private Integer snapshotLimit = 100;
}
