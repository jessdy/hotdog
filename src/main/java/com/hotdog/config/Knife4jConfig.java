package com.hotdog.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Knife4j (Swagger) 配置
 */
@Configuration
public class Knife4jConfig {
    
    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("HotDog API 文档")
                .version("1.0.0")
                .description("热点事件自动提取系统 API 文档\n\n" +
                    "基于语义向量 + DBSCAN 滑动聚类，自动发现热点事件/话题")
                .contact(new Contact()
                    .name("HotDog Team")
                    .email("support@hotdog.com"))
                .license(new License()
                    .name("Apache 2.0")
                    .url("https://www.apache.org/licenses/LICENSE-2.0.html")));
    }
}
