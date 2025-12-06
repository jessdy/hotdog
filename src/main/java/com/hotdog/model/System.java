package com.hotdog.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 系统/租户实体
 */
@Entity
@Table(name = "hotd_systems", indexes = {
    @Index(name = "hotd_idx_systems_code", columnList = "system_code"),
    @Index(name = "hotd_idx_systems_active", columnList = "is_active")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
public class System {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "system_code", nullable = false, unique = true, length = 64)
    private String systemCode;
    
    @Column(name = "system_name", nullable = false, length = 128)
    private String systemName;
    
    @Column(columnDefinition = "TEXT")
    private String description;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
    
    @Column(name = "create_time", nullable = false, updatable = false)
    private LocalDateTime createTime;
    
    @Column(name = "update_time", nullable = false)
    private LocalDateTime updateTime;
    
    @PrePersist
    protected void onCreate() {
        if (createTime == null) {
            createTime = LocalDateTime.now();
        }
        if (updateTime == null) {
            updateTime = LocalDateTime.now();
        }
    }
    
    @PreUpdate
    protected void onUpdate() {
        updateTime = LocalDateTime.now();
    }
}
