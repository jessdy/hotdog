package com.hotdog.repository;

import com.hotdog.model.System;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * 系统数据访问接口
 */
@Repository
public interface SystemRepository extends JpaRepository<System, Long> {
    
    /**
     * 根据系统代码查询
     */
    Optional<System> findBySystemCode(String systemCode);
    
    /**
     * 查询所有活跃系统
     */
    java.util.List<System> findByIsActiveTrue();
}
