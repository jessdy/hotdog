package com.hotdog.config;

/**
 * 系统上下文（ThreadLocal）
 * 用于在请求处理过程中传递系统信息
 */
public class SystemContext {
    
    private static final ThreadLocal<Long> SYSTEM_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> SYSTEM_CODE = new ThreadLocal<>();
    
    public static void setSystemId(Long systemId) {
        SYSTEM_ID.set(systemId);
    }
    
    public static Long getSystemId() {
        return SYSTEM_ID.get();
    }
    
    public static void setSystemCode(String systemCode) {
        SYSTEM_CODE.set(systemCode);
    }
    
    public static String getSystemCode() {
        return SYSTEM_CODE.get();
    }
    
    public static void clear() {
        SYSTEM_ID.remove();
        SYSTEM_CODE.remove();
    }
}
