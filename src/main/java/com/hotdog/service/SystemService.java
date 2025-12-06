package com.hotdog.service;

import com.hotdog.dto.SystemConfigDTO;
import com.hotdog.dto.SystemCreateDTO;
import com.hotdog.model.System;
import com.hotdog.model.SystemConfig;
import com.hotdog.repository.SystemConfigRepository;
import com.hotdog.repository.SystemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 系统管理服务
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SystemService {
    
    private final SystemRepository systemRepository;
    private final SystemConfigRepository systemConfigRepository;
    private final JdbcTemplate jdbcTemplate;
    
    /**
     * 创建系统
     */
    @Transactional
    public System createSystem(SystemCreateDTO dto) {
        // 检查系统代码是否已存在
        if (systemRepository.findBySystemCode(dto.getSystemCode()).isPresent()) {
            throw new RuntimeException("系统代码已存在: " + dto.getSystemCode());
        }
        
        // 创建系统
        System system = new System();
        system.setSystemCode(dto.getSystemCode());
        system.setSystemName(dto.getSystemName());
        system.setDescription(dto.getDescription());
        system.setIsActive(true);
        system = systemRepository.save(system);
        
        // 创建系统配置
        SystemConfig config = new SystemConfig();
        config.setSystemId(system.getId());
        config.setSystem(system);
        if (dto.getConfig() != null) {
            SystemConfigDTO configDTO = dto.getConfig();
            config.setDefaultHours(configDTO.getDefaultHours());
            config.setDefaultEps(configDTO.getDefaultEps());
            config.setDefaultMinSamples(configDTO.getDefaultMinSamples());
            config.setEmbeddingCron(configDTO.getEmbeddingCron());
            config.setClusteringCron(configDTO.getClusteringCron());
            config.setMaxArticlesLimit(configDTO.getMaxArticlesLimit());
            config.setSnapshotLimit(configDTO.getSnapshotLimit());
        }
        systemConfigRepository.save(config);
        
        // 设置定时任务
        setupCronJobsForSystem(system.getId());
        
        log.info("创建系统成功: {} (ID: {})", system.getSystemCode(), system.getId());
        return system;
    }
    
    /**
     * 根据系统代码查询系统
     */
    public System getSystemByCode(String systemCode) {
        return systemRepository.findBySystemCode(systemCode)
            .orElseThrow(() -> new RuntimeException("系统不存在: " + systemCode));
    }
    
    /**
     * 根据系统ID查询系统
     */
    public System getSystemById(Long id) {
        return systemRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("系统不存在: id=" + id));
    }
    
    /**
     * 查询所有活跃系统
     */
    public List<System> getActiveSystems() {
        return systemRepository.findByIsActiveTrue();
    }
    
    /**
     * 更新系统配置
     */
    @Transactional
    public SystemConfig updateSystemConfig(Long systemId, SystemConfigDTO configDTO) {
        SystemConfig config = systemConfigRepository.findBySystemId(systemId)
            .orElseThrow(() -> new RuntimeException("系统配置不存在: systemId=" + systemId));
        
        if (configDTO.getDefaultHours() != null) {
            config.setDefaultHours(configDTO.getDefaultHours());
        }
        if (configDTO.getDefaultEps() != null) {
            config.setDefaultEps(configDTO.getDefaultEps());
        }
        if (configDTO.getDefaultMinSamples() != null) {
            config.setDefaultMinSamples(configDTO.getDefaultMinSamples());
        }
        if (configDTO.getEmbeddingCron() != null) {
            config.setEmbeddingCron(configDTO.getEmbeddingCron());
        }
        if (configDTO.getClusteringCron() != null) {
            config.setClusteringCron(configDTO.getClusteringCron());
            // 更新定时任务
            setupCronJobsForSystem(systemId);
        }
        if (configDTO.getMaxArticlesLimit() != null) {
            config.setMaxArticlesLimit(configDTO.getMaxArticlesLimit());
        }
        if (configDTO.getSnapshotLimit() != null) {
            config.setSnapshotLimit(configDTO.getSnapshotLimit());
        }
        
        return systemConfigRepository.save(config);
    }
    
    /**
     * 为系统设置定时任务
     */
    @Transactional
    public void setupCronJobsForSystem(Long systemId) {
        System system = systemRepository.findById(systemId)
            .orElseThrow(() -> new RuntimeException("系统不存在: systemId=" + systemId));
        
        SystemConfig config = systemConfigRepository.findBySystemId(systemId)
            .orElseThrow(() -> new RuntimeException("系统配置不存在: systemId=" + systemId));
        
        if (!system.getIsActive()) {
            // 系统未启用，删除定时任务
            String jobName = "hotd-cluster-" + system.getSystemCode();
            jdbcTemplate.execute("SELECT cron.unschedule('" + jobName + "')");
            return;
        }
        
        // 创建或更新聚类定时任务
        String jobName = "hotd-cluster-" + system.getSystemCode();
        jdbcTemplate.execute("SELECT cron.unschedule('" + jobName + "')");
        String sql = String.format(
            "SELECT cron.schedule('%s', '%s', 'SELECT hotd_refresh_snapshot_by_system(%d)')",
            jobName, config.getClusteringCron(), systemId
        );
        jdbcTemplate.execute(sql);
        
        log.info("为系统设置定时任务: {} (cron: {})", system.getSystemCode(), config.getClusteringCron());
    }
    
    /**
     * 为所有系统设置定时任务
     */
    @Transactional
    public void setupAllCronJobs() {
        jdbcTemplate.execute("SELECT hotd_setup_system_cron_jobs()");
        log.info("为所有系统设置定时任务完成");
    }
}
