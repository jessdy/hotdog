package com.hotdog.controller;

import com.hotdog.dto.SystemConfigDTO;
import com.hotdog.dto.SystemCreateDTO;
import com.hotdog.model.System;
import com.hotdog.model.SystemConfig;
import com.hotdog.service.SystemService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 系统管理API
 */
@Tag(name = "系统管理", description = "多租户系统的创建、配置、定时任务管理等操作")
@RestController
@RequestMapping("/api/systems")
@RequiredArgsConstructor
public class SystemController {
    
    private final SystemService systemService;
    
    /**
     * 创建系统
     */
    @Operation(summary = "创建系统", description = "创建新的多租户系统，并自动创建系统配置和定时任务")
    @PostMapping
    public ResponseEntity<System> createSystem(@Valid @RequestBody SystemCreateDTO dto) {
        System system = systemService.createSystem(dto);
        return ResponseEntity.ok(system);
    }
    
    /**
     * 查询系统列表
     */
    @GetMapping
    public ResponseEntity<List<System>> getSystems(
            @RequestParam(required = false) Boolean isActive) {
        List<System> systems;
        if (isActive != null && isActive) {
            systems = systemService.getActiveSystems();
        } else {
            systems = systemService.getActiveSystems(); // 简化实现
        }
        return ResponseEntity.ok(systems);
    }
    
    /**
     * 查询系统详情（根据ID）
     */
    @GetMapping("/{id}")
    public ResponseEntity<System> getSystemById(@PathVariable Long id) {
        System system = systemService.getSystemById(id);
        return ResponseEntity.ok(system);
    }
    
    /**
     * 根据系统代码查询
     */
    @GetMapping("/code/{systemCode}")
    public ResponseEntity<System> getSystemByCode(@PathVariable String systemCode) {
        System system = systemService.getSystemByCode(systemCode);
        return ResponseEntity.ok(system);
    }
    
    /**
     * 更新系统配置
     */
    @PutMapping("/{id}/config")
    public ResponseEntity<SystemConfig> updateSystemConfig(
            @PathVariable Long id,
            @RequestBody SystemConfigDTO configDTO) {
        SystemConfig config = systemService.updateSystemConfig(id, configDTO);
        return ResponseEntity.ok(config);
    }
    
    /**
     * 为系统设置定时任务
     */
    @PostMapping("/{id}/setup-cron")
    public ResponseEntity<Void> setupCronJobs(@PathVariable Long id) {
        systemService.setupCronJobsForSystem(id);
        return ResponseEntity.ok().build();
    }
    
    /**
     * 为所有系统设置定时任务
     */
    @PostMapping("/setup-all-cron")
    public ResponseEntity<Void> setupAllCronJobs() {
        systemService.setupAllCronJobs();
        return ResponseEntity.ok().build();
    }
}
