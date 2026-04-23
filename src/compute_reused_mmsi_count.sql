SELECT COUNT(*) AS n_reused_mmsi
FROM (
  SELECT sourcemmsi
  FROM ais_data.ships
  GROUP BY sourcemmsi
  HAVING COUNT(*) > 1
) AS reused_mmsi;
