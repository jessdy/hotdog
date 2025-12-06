package com.hotdog.dto;

import com.hotdog.model.ArticleMetadata;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 文章创建DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ArticleCreateDTO {
    
    @NotBlank(message = "标题不能为空")
    private String title;
    
    private String summary;
    
    private String fullText;
    
    @NotNull(message = "权重不能为空")
    @Positive(message = "权重必须大于0")
    private BigDecimal weight = BigDecimal.ONE;
    
    private String source;
    
    private Boolean isShared = false;  // 是否全局共享
    
    private ArticleMetadata metadata;
}
