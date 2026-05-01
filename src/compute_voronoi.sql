CREATE SCHEMA IF NOT EXISTS data_analysis;

DROP TABLE IF EXISTS data_analysis.ports_voronoi;

CREATE TABLE data_analysis.ports_voronoi AS
SELECT por_id AS port_id,
       libelle_po AS port_name,
       geom3035,
       voronoi_zone3035
FROM context_data.ports
LEFT JOIN (
    SELECT (ST_Dump(ST_VoronoiPolygons(ST_Collect(geom3035)))).geom AS voronoi_zone3035
    FROM context_data.ports
) AS vp
ON (ST_Within(ports.geom3035, vp.voronoi_zone3035));

CREATE INDEX idx_ports_voronoi_zone
ON data_analysis.ports_voronoi
USING gist (voronoi_zone3035);
