package com.hotdog.controller;

import com.hotdog.dto.ArticleCreateDTO;
import com.hotdog.dto.ArticleQueryDTO;
import com.hotdog.dto.ArticleShareDTO;
import com.hotdog.model.Article;
import com.hotdog.service.ArticleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

/**
 * 文章管理API
 */
@Tag(name = "文章管理", description = "文章的创建、查询、更新、删除等操作")
@RestController
@RequestMapping("/api/articles")
@RequiredArgsConstructor
public class ArticleController {
    
    private final ArticleService articleService;
    
    /**
     * 创建文章
     */
    @Operation(summary = "创建文章", description = "创建单篇文章，自动关联当前系统（通过 X-System-Code 请求头指定）")
    @PostMapping
    public ResponseEntity<Article> createArticle(@Valid @RequestBody ArticleCreateDTO dto) {
        Article article = articleService.createArticle(dto);
        return ResponseEntity.ok(article);
    }
    
    /**
     * 批量创建文章
     */
    @PostMapping("/batch")
    public ResponseEntity<List<Article>> batchCreateArticles(
            @Valid @RequestBody List<ArticleCreateDTO> dtos) {
        List<Article> articles = articleService.batchCreateArticles(dtos);
        return ResponseEntity.ok(articles);
    }
    
    /**
     * 查询文章列表（支持按系统过滤）
     */
    @Operation(summary = "查询文章列表", description = "支持按系统过滤、分页、来源、权重等条件筛选")
    @GetMapping
    public ResponseEntity<Page<Article>> queryArticles(
            @Parameter(description = "系统ID，用于过滤文章") @RequestParam(required = false) Long systemId,
            @RequestParam(required = false) String source,
            @RequestParam(required = false) BigDecimal minWeight,
            @RequestParam(required = false) BigDecimal maxWeight,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        ArticleQueryDTO query = new ArticleQueryDTO();
        query.setSource(source);
        query.setMinWeight(minWeight);
        query.setMaxWeight(maxWeight);
        query.setKeyword(keyword);
        
        Pageable pageable = PageRequest.of(page, size);
        Page<Article> result = articleService.queryArticles(query, systemId, pageable);
        return ResponseEntity.ok(result);
    }
    
    /**
     * 根据ID查询文章
     */
    @GetMapping("/{id}")
    public ResponseEntity<Article> getArticleById(@PathVariable Long id) {
        Article article = articleService.getArticleById(id);
        return ResponseEntity.ok(article);
    }
    
    /**
     * 更新文章权重
     */
    @PutMapping("/{id}/weight")
    public ResponseEntity<Void> updateWeight(
            @PathVariable Long id, 
            @RequestParam BigDecimal weight) {
        articleService.updateArticleWeight(id, weight);
        return ResponseEntity.ok().build();
    }
    
    /**
     * 将文章共享给指定系统
     */
    @Operation(summary = "共享文章", description = "将文章共享给指定的系统（支持数据源重叠场景）")
    @PostMapping("/{id}/share")
    public ResponseEntity<Void> shareArticle(
            @PathVariable Long id,
            @RequestBody ArticleShareDTO shareDTO) {
        articleService.shareArticleToSystem(id, shareDTO);
        return ResponseEntity.ok().build();
    }
    
    /**
     * 删除文章（软删除）
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteArticle(@PathVariable Long id) {
        articleService.deleteArticle(id);
        return ResponseEntity.ok().build();
    }
}
