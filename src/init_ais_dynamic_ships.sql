CREATE SCHEMA IF NOT EXISTS "ais_data";

CREATE TABLE ais_data.dynamic_ships (
    id bigserial, -- unique identifier of the row in the table
    sourcemmsi integer, -- MMSI identifier of the source ship's transceiver
    navigationalstatus integer, -- Navigational status of the vessel
    rateofturn integer, -- Rate of turn
    speedoverground double precision, -- Speed over ground (SOG) of the vessel
    courseoverground double precision, -- Course over ground (COG)
    trueheading integer, -- True heading of the vessel
    lon double precision, -- Longitude in decimal degrees (EPSG:4326)
    lat double precision, -- Latitude in decimal degrees (EPSG:4326)
    t bigint, -- Timestamp of the AIS position report (Unix epoch)
    mmsi integer, -- MMSI identifier (aliased from sourcemmsi)
    speed double precision, -- Speed over ground (aliased from speedoverground)
    geom3035 geometry(Point, 3035), -- Geographic position in ETRS89-LAEA projection
    CONSTRAINT dynamic_ships_pkey PRIMARY KEY (id) -- Primary Key
);

CREATE INDEX IF NOT EXISTS idx_dynamic_ships_mmsi_t
ON ais_data.dynamic_ships
USING btree (mmsi, t);

CREATE INDEX IF NOT EXISTS idx_dynamic_ships_t
ON ais_data.dynamic_ships
USING btree (t);
