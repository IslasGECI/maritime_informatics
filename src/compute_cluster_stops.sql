CREATE SCHEMA IF NOT EXISTS data_analysis;

CREATE INDEX IF NOT EXISTS idx_stops_centroid
ON data_analysis.stops
USING btree (centr3035);

DROP TABLE IF EXISTS data_analysis.cluster_stops CASCADE;

CREATE TABLE data_analysis.cluster_stops AS
    SELECT *,
           ST_ClusterDBSCAN(centr3035, eps := 50, minpoints := 5) OVER () AS cid
    FROM data_analysis.stops
    WHERE duration_s >= 60; -- 1 minute long
