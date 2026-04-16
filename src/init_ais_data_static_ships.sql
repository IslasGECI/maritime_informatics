CREATE SCHEMA "ais_data";

CREATE TABLE ais_data.static_ships (
    id bigserial, -- unique identifier of the row in the table
    sourcemmsi integer, -- MMSI identifier of the source ship’s transceiver
    imo integer, -- IMO number of the ship, linked to the vessel structure
    callsign text, -- Callsign of the ship
    shipname text, -- Ship name
    shiptype integer, -- Type of the vessel, according to AIS specifications
    to_bow integer, -- Distance of the AIS transceiver from bow (front) of vessel, rounded to the nearest meter
    to_stern integer, -- Distance of AIS antenna from stern (back)
    to_starboard integer, -- Distance of AIS antenna from starboard (right)
    to_port integer, -- Distance of AIS antenna from port (left)
    eta text, -- Estimated Time of Arrival to destination
    draught double precision, -- Ship draught
    destination text, -- Declared ship destination
    mothershipmmsi integer, -- MMSI of the mothership
    ts bigint, -- Timestamp of the AIS frame
    CONSTRAINT static_ships_pkey PRIMARY KEY (id) -- Primary Key
);
