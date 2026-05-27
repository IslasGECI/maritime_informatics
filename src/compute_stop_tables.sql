CREATE SCHEMA IF NOT EXISTS data_analysis;

DROP TABLE IF EXISTS data_analysis.stop_begin CASCADE;

CREATE TABLE data_analysis.stop_begin AS -- first stop position
    SELECT mmsi,
           t2 AS t_begin -- stop starts at first steady position
    FROM data_analysis.segments
    WHERE speed1 > 0.1 AND speed2 <= 0.1; -- speed threshold is 0.1 kn

CREATE INDEX IF NOT EXISTS idx_stop_begin_mmsi_t
ON data_analysis.stop_begin
USING btree (mmsi, t_begin);

DROP TABLE IF EXISTS data_analysis.stop_end CASCADE;

CREATE TABLE data_analysis.stop_end AS -- last stop position
    SELECT mmsi,
           t1 AS t_end -- stop ends at last steady position
    FROM data_analysis.segments
    WHERE speed1 <= 0.1 AND speed2 > 0.1; -- speed threshold is 0.1 kn

CREATE INDEX IF NOT EXISTS idx_stop_end_mmsi_t
ON data_analysis.stop_end
USING btree (mmsi, t_end);
