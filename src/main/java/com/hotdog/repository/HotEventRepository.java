package com.hotdog.repository;

import com.hotdog.model.HotEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 热点事件数据访问接口
 */
@Repository
public interface HotEventRepository extends JpaRepository<HotEvent, HotEventSnapshotId> {
    
    /**
     * 查询最新的热点事件快照
     */
    @Query("SELECT h FROM HotEvent h WHERE h.snapshotTime = " +
           "(SELECT MAX(h2.snapshotTime) FROM HotEvent h2) " +
           "ORDER BY h.rankNo ASC")
    List<HotEvent> findLatestSnapshot();
    
    /**
     * 查询最新的热点事件快照（限制数量）
     */
    @Query(value = "SELECT h.* FROM hotd_event_snapshot h " +
           "WHERE h.snapshot_time = (SELECT MAX(snapshot_time) FROM hotd_event_snapshot) " +
           "ORDER BY h.rank_no ASC LIMIT ?1", nativeQuery = true)
    List<HotEvent> findTopByOrderByRankNoAsc(int limit);
    
    /**
     * 根据排名查询热点事件
     */
    @Query("SELECT h FROM HotEvent h WHERE h.snapshotTime = " +
           "(SELECT MAX(h2.snapshotTime) FROM HotEvent h2) AND h.rankNo = :rankNo")
    HotEvent findByLatestRankNo(@Param("rankNo") Integer rankNo);
    
    /**
     * 根据快照时间查询热点事件
     */
    List<HotEvent> findBySnapshotTimeOrderByRankNoAsc(LocalDateTime snapshotTime);
    
    /**
     * 按系统查询最新的热点事件快照
     */
    @Query(value = "SELECT h.* FROM hotd_event_snapshot h " +
           "WHERE h.system_id = ?1 " +
           "AND h.snapshot_time = (SELECT MAX(snapshot_time) FROM hotd_event_snapshot WHERE system_id = ?1) " +
           "ORDER BY h.rank_no ASC LIMIT ?2", nativeQuery = true)
    List<HotEvent> findLatestSnapshotBySystem(Long systemId, int limit);
    
    /**
     * 按系统查询最新的热点事件快照（不限制数量）
     */
    @Query(value = "SELECT h.* FROM hotd_event_snapshot h " +
           "WHERE h.system_id = ?1 " +
           "AND h.snapshot_time = (SELECT MAX(snapshot_time) FROM hotd_event_snapshot WHERE system_id = ?1) " +
           "ORDER BY h.rank_no ASC", nativeQuery = true)
    List<HotEvent> findLatestSnapshotBySystem(Long systemId);
}
