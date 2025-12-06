package com.hotdog.service;

import com.hotdog.config.SystemContext;
import com.hotdog.dto.ArticleCreateDTO;
import com.hotdog.dto.ArticleQueryDTO;
import com.hotdog.dto.ArticleShareDTO;
import com.hotdog.model.Article;
import com.hotdog.model.ArticleSystem;
import com.hotdog.repository.ArticleRepository;
import com.hotdog.repository.ArticleSystemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 文章管理服务
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ArticleService {
    
    private final ArticleRepository articleRepository;
    private final ArticleSystemRepository articleSystemRepository;
    
    /**
     * 创建文章（自动关联当前系统）
     */
    @Transactional
    public Article createArticle(ArticleCreateDTO dto) {
        Article article = new Article();
        article.setTitle(dto.getTitle());
        article.setSummary(dto.getSummary());
        article.setFullText(dto.getFullText());
        article.setWeight(dto.getWeight());
        article.setSource(dto.getSource());
        article.setAttr(dto.getMetadata());
        article.setCreateTime(LocalDateTime.now());
        article.setIsDeleted(false);
        
        // 设置系统ID（从上下文获取）
        Long systemId = SystemContext.getSystemId();
        if (systemId != null) {
            article.setSystemId(systemId);
        }
        
        // 设置是否共享
        if (dto.getIsShared() != null) {
            article.setIsShared(dto.getIsShared());
        }
        
        return articleRepository.save(article);
    }
    
    /**
     * 批量创建文章
     */
    @Transactional
    public List<Article> batchCreateArticles(List<ArticleCreateDTO> dtos) {
        List<Article> articles = dtos.stream()
            .map(dto -> {
                Article article = new Article();
                article.setTitle(dto.getTitle());
                article.setSummary(dto.getSummary());
                article.setFullText(dto.getFullText());
                article.setWeight(dto.getWeight());
                article.setSource(dto.getSource());
                article.setAttr(dto.getMetadata());
                article.setCreateTime(LocalDateTime.now());
                article.setIsDeleted(false);
                return article;
            })
            .collect(Collectors.toList());
        return articleRepository.saveAll(articles);
    }
    
    /**
     * 查询文章（支持分页、筛选，按系统过滤）
     */
    public Page<Article> queryArticles(ArticleQueryDTO query, Long systemId, Pageable pageable) {
        // 如果没有指定 systemId，从上下文获取
        if (systemId == null) {
            systemId = SystemContext.getSystemId();
        }
        
        // 如果指定了 systemId，使用系统过滤查询
        if (systemId != null) {
            return articleRepository.findBySystemIdAndFilters(
                systemId,
                query != null ? query.getSource() : null,
                query != null ? query.getMinWeight() : null,
                pageable
            );
        }
        
        // 否则使用原有逻辑（向后兼容）
        if (query == null) {
            return articleRepository.findAll(pageable);
        }
        
        if (query.getSource() != null || query.getMinWeight() != null) {
            return articleRepository.findBySourceAndMinWeight(
                query.getSource(),
                query.getMinWeight(),
                pageable
            );
        }
        
        if (query.getSource() != null) {
            return articleRepository.findBySourceAndIsDeletedFalse(query.getSource(), pageable);
        }
        
        if (query.getMinWeight() != null) {
            return articleRepository.findByMinWeight(query.getMinWeight(), pageable);
        }
        
        return articleRepository.findAll(pageable);
    }
    
    /**
     * 将文章共享给指定系统
     */
    @Transactional
    public void shareArticleToSystem(Long articleId, ArticleShareDTO shareDTO) {
        Article article = getArticleById(articleId);
        
        if (shareDTO.getSystemIds() == null || shareDTO.getSystemIds().isEmpty()) {
            return;
        }
        
        for (Long systemId : shareDTO.getSystemIds()) {
            // 检查是否已存在关联
            ArticleSystemId id = new ArticleSystemId(articleId, systemId);
            if (!articleSystemRepository.existsById(id)) {
                ArticleSystem articleSystem = new ArticleSystem();
                articleSystem.setArticleId(articleId);
                articleSystem.setSystemId(systemId);
                articleSystemRepository.save(articleSystem);
            }
        }
        
        log.info("文章 {} 已共享给系统: {}", articleId, shareDTO.getSystemIds());
    }
    
    /**
     * 根据ID查询文章
     */
    public Article getArticleById(Long id) {
        return articleRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("文章不存在: " + id));
    }
    
    /**
     * 更新文章权重
     */
    @Transactional
    public void updateArticleWeight(Long articleId, BigDecimal weight) {
        Article article = getArticleById(articleId);
        article.setWeight(weight);
        articleRepository.save(article);
    }
    
    /**
     * 删除文章（软删除）
     */
    @Transactional
    public void deleteArticle(Long articleId) {
        Article article = getArticleById(articleId);
        article.setIsDeleted(true);
        articleRepository.save(article);
    }
}
