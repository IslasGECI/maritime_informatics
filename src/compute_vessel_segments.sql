CREATE SCHEMA IF NOT EXISTS data_analysis;

DROP TABLE IF EXISTS data_analysis.segments CASCADE;

CREATE TABLE data_analysis.segments AS
    SELECT mmsi, -- ship identifier
           t1, t2, -- starting and ending timestamps
           speed1, speed2, -- starting and ending speeds
           p1, p2, -- starting and ending points
           st_makeline(p1, p2) AS segment, -- line segment connecting points
           st_distance(p1, p2) AS distance, -- distance between points
           (t2 - t1) AS duration_s, -- timestamps in seconds
           (st_distance(p1, p2) / NULLIF(t2 - t1, 0))
               AS speed_m_s -- speed in m/s
    FROM (
        SELECT mmsi, -- ship identifier
               LEAD(mmsi) OVER (ORDER BY mmsi, t, id) AS mmsi2, -- next MMSI
               t AS t1, -- starting time
               LEAD(t) OVER (ORDER BY mmsi, t, id) AS t2, -- ending time
               speed AS speed1, -- initial speed
               LEAD(speed) OVER (ORDER BY mmsi, t, id) AS speed2, -- final speed
               geom3035 AS p1, -- initial point
               LEAD(geom3035) OVER (ORDER BY mmsi, t, id) AS p2 -- final point
        FROM ais_data.dynamic_ships
    ) AS q1
WHERE mmsi = mmsi2; -- filter out different MMSI

CREATE INDEX idx_segments_speed
ON data_analysis.segments
USING btree (speed1, speed2);

