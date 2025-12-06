package com.hotdog.controller;

import com.hotdog.service.EmbeddingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 向量化服务API
 */
@RestController
@RequestMapping("/api/embedding")
@RequiredArgsConstructor
public class EmbeddingController {
    
    private final EmbeddingService embeddingService;
    
    /**
     * 触发批量向量化
     */
    @PostMapping("/trigger")
    public ResponseEntity<Map<String, String>> triggerBatchEmbedding() {
        embeddingService.triggerBatchEmbedding();
        Map<String, String> response = new HashMap<>();
        response.put("message", "批量向量化已触发");
        return ResponseEntity.ok(response);
    }
    
    /**
     * 获取待向量化的文章数量
     */
    @GetMapping("/pending-count")
    public ResponseEntity<Map<String, Long>> getPendingEmbeddingCount() {
        Long count = embeddingService.getPendingEmbeddingCount();
        Map<String, Long> response = new HashMap<>();
        response.put("pendingCount", count);
        return ResponseEntity.ok(response);
    }
}
