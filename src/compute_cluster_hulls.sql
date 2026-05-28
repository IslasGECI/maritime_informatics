CREATE SCHEMA IF NOT EXISTS data_analysis;

DROP TABLE IF EXISTS data_analysis.clusters_stops_hulls;

CREATE TABLE data_analysis.clusters_stops_hulls AS
    SELECT cid, -- cluster id
           ST_ConvexHull(st_collect(centr3035)) AS convex_hull,
           ST_ConcaveHull(st_collect(centr3035), 0.75) AS concave_hull,
           ST_MinimumBoundingCircle(st_collect(centr3035)) AS bounding_circle,
           ST_Centroid(st_collect(centr3035)) AS centroid,
           count(*) AS nb_stops, -- number of stops in this cluster (area)
           sum(nb_pos) AS nb_pos, -- sum of stops in the cluster
           count(DISTINCT mmsi) AS nb_ships, -- num of unique ships
           min(duration_s) AS min_dur,
           avg(duration_s) AS avg_dur,
           max(duration_s) AS max_dur
    FROM data_analysis.cluster_stops
    WHERE cid IS NOT NULL -- exclude outliers
    GROUP BY cid; -- group all the stops centroids within the same cluster

CREATE INDEX IF NOT EXISTS idx_clusters_stops_hulls_cid ON data_analysis.clusters_stops_hulls (cid);
