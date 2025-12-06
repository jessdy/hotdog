package com.hotdog.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 系统创建DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SystemCreateDTO {
    private String systemCode;
    private String systemName;
    private String description;
    private SystemConfigDTO config;
}
