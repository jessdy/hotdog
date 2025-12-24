package com.hotdog.config;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web配置
 */
@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {
    
    private final SystemContextInterceptor systemContextInterceptor;
    
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("*")
            .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
            .allowedHeaders("*")
            .maxAge(3600);
        
        // 允许访问 Knife4j 文档
        registry.addMapping("/doc.html")
            .allowedOrigins("*")
            .allowedMethods("GET", "OPTIONS")
            .allowedHeaders("*");
    }
    
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(systemContextInterceptor)
            .addPathPatterns("/api/**")
            .excludePathPatterns(
                "/api/systems/**",  // 系统管理接口不拦截
                "/doc.html",        // Knife4j 文档页面
                "/webjars/**",      // Knife4j 静态资源
                "/v3/api-docs/**",  // Swagger API 文档
                "/swagger-ui/**",   // Swagger UI
                "/favicon.ico"      // 图标
            );
    }
}
