package com.hotdog.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Favicon 控制器
 * 处理浏览器自动请求的 favicon.ico，避免 NoResourceFoundException
 */
@RestController
public class FaviconController {
    
    @GetMapping("/favicon.ico")
    public ResponseEntity<Void> favicon() {
        // 返回 204 No Content，浏览器会使用默认图标
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }
}
