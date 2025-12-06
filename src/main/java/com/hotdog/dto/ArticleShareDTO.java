package com.hotdog.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 文章共享DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ArticleShareDTO {
    private List<Long> systemIds;
}
