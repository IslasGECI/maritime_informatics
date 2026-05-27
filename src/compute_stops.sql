CREATE SCHEMA IF NOT EXISTS data_analysis;

DROP TABLE IF EXISTS data_analysis.stops CASCADE;

CREATE TABLE data_analysis.stops AS
    SELECT
        mmsi, -- ship identifier
        t_begin, -- start of the stop event
        t_end, -- end of the stop event
        (t_end - t_begin) AS duration_s -- stop duration in seconds
    FROM data_analysis.stop_begin
    INNER JOIN LATERAL (
        -- keep only stops that have an end
        SELECT t_end
        FROM data_analysis.stop_end
        WHERE stop_begin.mmsi = stop_end.mmsi
          AND t_begin <= t_end -- stop follows the beginning
        ORDER BY t_end
        LIMIT 1 -- select only the first stop end
    ) AS q2 ON (true);
