package com.hotdog.controller;

import com.hotdog.dto.HotEventResponseDTO;
import com.hotdog.model.Article;
import com.hotdog.model.HotEvent;
import com.hotdog.service.HotEventService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 热点事件API
 */
@RestController
@RequestMapping("/api/hot-events")
@RequiredArgsConstructor
public class HotEventController {
    
    private final HotEventService hotEventService;
    
    /**
     * 获取实时热点事件（调用聚类函数，较慢但最新，支持多系统）
     */
    @GetMapping("/realtime")
    public ResponseEntity<List<HotEventResponseDTO>> getRealTimeHotEvents(
            @RequestParam(required = false) Long systemId,
            @RequestParam(required = false) Integer hours,
            @RequestParam(required = false) Float eps,
            @RequestParam(required = false) Integer minSamples,
            @RequestParam(defaultValue = "20") Integer limit) {
        List<HotEventResponseDTO> events = hotEventService
            .getRealTimeHotEvents(systemId, hours, eps, minSamples, limit);
        return ResponseEntity.ok(events);
    }
    
    /**
     * 获取热点事件快照（高性能，适合高并发，支持多系统）
     */
    @GetMapping("/snapshot")
    public ResponseEntity<List<HotEvent>> getHotEventsFromSnapshot(
            @RequestParam(required = false) Long systemId,
            @RequestParam(defaultValue = "20") Integer limit) {
        List<HotEvent> events = hotEventService.getHotEventsFromSnapshot(systemId, limit);
        return ResponseEntity.ok(events);
    }
    
    /**
     * 手动刷新热点快照（支持多系统）
     */
    @PostMapping("/snapshot/refresh")
    public ResponseEntity<Void> refreshSnapshot(
            @RequestParam(required = false) Long systemId) {
        hotEventService.refreshHotEventSnapshot(systemId);
        return ResponseEntity.ok().build();
    }
    
    /**
     * 获取热点事件的原始文章列表（从快照表，高性能，支持多系统）
     */
    @GetMapping("/snapshot/{rankNo}/articles")
    public ResponseEntity<List<Article>> getHotEventArticlesFromSnapshot(
            @PathVariable Integer rankNo,
            @RequestParam(required = false) Long systemId,
            @RequestParam(defaultValue = "50") Integer limit) {
        List<Article> articles = hotEventService.getHotEventArticles(systemId, rankNo, limit);
        return ResponseEntity.ok(articles);
    }
    
    /**
     * 获取实时热点事件的原始文章列表（根据聚类ID，支持多系统）
     */
    @GetMapping("/realtime/{clusterId}/articles")
    public ResponseEntity<List<Article>> getRealTimeHotEventArticles(
            @PathVariable Long clusterId,
            @RequestParam(required = false) Long systemId,
            @RequestParam(required = false) Integer hours,
            @RequestParam(defaultValue = "50") Integer limit) {
        List<Article> articles = hotEventService
            .getRealTimeHotEventArticles(systemId, clusterId, hours, limit);
        return ResponseEntity.ok(articles);
    }
}
