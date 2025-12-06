package com.hotdog.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * 热点事件快照主键
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class HotEventSnapshotId implements Serializable {
    
    private LocalDateTime snapshotTime;
    private Integer rankNo;
    private Long systemId;
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        HotEventSnapshotId that = (HotEventSnapshotId) o;
        return Objects.equals(snapshotTime, that.snapshotTime) &&
               Objects.equals(rankNo, that.rankNo) &&
               Objects.equals(systemId, that.systemId);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(snapshotTime, rankNo, systemId);
    }
}
