package com.hotdog.repository;

import com.hotdog.model.SystemConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * 系统配置数据访问接口
 */
@Repository
public interface SystemConfigRepository extends JpaRepository<SystemConfig, Long> {
    
    /**
     * 根据系统ID查询配置
     */
    Optional<SystemConfig> findBySystemId(Long systemId);
}
