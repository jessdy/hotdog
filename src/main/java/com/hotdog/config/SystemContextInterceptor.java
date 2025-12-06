package com.hotdog.config;

import com.hotdog.model.System;
import com.hotdog.repository.SystemRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.Optional;

/**
 * 系统上下文拦截器
 * 从请求头或参数中提取系统信息，设置到 ThreadLocal
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class SystemContextInterceptor implements HandlerInterceptor {
    
    private final SystemRepository systemRepository;
    
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        // 从请求头获取系统代码
        String systemCode = request.getHeader("X-System-Code");
        
        // 如果没有，从查询参数获取
        if (systemCode == null || systemCode.isEmpty()) {
            systemCode = request.getParameter("systemCode");
        }
        
        // 如果还没有，尝试从 systemId 参数获取
        String systemIdParam = request.getParameter("systemId");
        if (systemCode == null && systemIdParam != null) {
            try {
                Long systemId = Long.parseLong(systemIdParam);
                Optional<System> system = systemRepository.findById(systemId);
                if (system.isPresent()) {
                    systemCode = system.get().getSystemCode();
                }
            } catch (NumberFormatException e) {
                log.warn("Invalid systemId parameter: {}", systemIdParam);
            }
        }
        
        // 设置系统上下文
        if (systemCode != null && !systemCode.isEmpty()) {
            Optional<System> system = systemRepository.findBySystemCode(systemCode);
            if (system.isPresent() && system.get().getIsActive()) {
                SystemContext.setSystemCode(systemCode);
                SystemContext.setSystemId(system.get().getId());
            } else {
                log.warn("System not found or inactive: {}", systemCode);
            }
        }
        
        return true;
    }
    
    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, 
                                Object handler, Exception ex) {
        // 清理 ThreadLocal，避免内存泄漏
        SystemContext.clear();
    }
}
