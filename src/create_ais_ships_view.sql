CREATE OR REPLACE VIEW ais_data.ships AS
SELECT
    sourcemmsi,  -- MMSI identifier of the ship, attributed by country of flag
    imo,         -- IMO number of the ship, linked to the vessel structure
    callsign,    -- Callsign of the ship
    shipname     -- Ship name
FROM ais_data.static_ships
GROUP BY sourcemmsi, imo, callsign, shipname;
