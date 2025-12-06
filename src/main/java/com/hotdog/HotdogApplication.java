package com.hotdog;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * HotDog 热点事件自动提取系统
 * 
 * @author HotDog Team
 */
@SpringBootApplication
@EnableJpaRepositories
public class HotdogApplication {

    public static void main(String[] args) {
        SpringApplication.run(HotdogApplication.class, args);
    }
}
