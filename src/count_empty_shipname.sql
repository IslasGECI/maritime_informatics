SELECT COUNT(*) AS n_empty_shipname
FROM ais_data.ships
WHERE shipname IS NULL
   OR TRIM(shipname) = '';
