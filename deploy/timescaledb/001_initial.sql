-- Sniffbot historical sensor data
-- Requires: TimescaleDB extension enabled on the database

-- Create the hypertable
CREATE TABLE sensor_readings (
    time        TIMESTAMPTZ NOT NULL,
    sensor_id   TEXT        NOT NULL,   -- e.g. 'tasmota_F847F7'
    temperature REAL        NOT NULL,   -- °C,    BME280
    humidity    REAL        NOT NULL,   -- %,     BME280
    dew_point   REAL        NOT NULL,   -- °C,    BME280
    pressure    REAL        NOT NULL,   -- hPa,   BME280
    pm1         SMALLINT    NOT NULL,   -- µg/m³, PMS5003, 0–999
    pm2_5       SMALLINT    NOT NULL,   -- µg/m³, PMS5003, 0–999
    pm10        SMALLINT    NOT NULL    -- µg/m³, PMS5003, 0–999
);

SELECT create_hypertable('sensor_readings', by_range('time'));

-- Compress chunks older than 7 days, segmented by sensor
ALTER TABLE sensor_readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id',
    timescaledb.compress_orderby   = 'time DESC'
);
SELECT add_compression_policy('sensor_readings', INTERVAL '7 days');
SELECT add_retention_policy('sensor_readings', INTERVAL '2 years');
