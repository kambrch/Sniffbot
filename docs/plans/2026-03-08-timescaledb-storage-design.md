# TimescaleDB Historical Storage — Design

**Date:** 2026-03-08
**Status:** Approved

## Goal

Store every sensor reading persistently in TimescaleDB for Grafana dashboards.
Retention: 2 years. Deployment: same machine as the bot (local Unix socket).

## Schema

Wide table — one row per reading, all sensor fields as columns.

```sql
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

ALTER TABLE sensor_readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id',
    timescaledb.compress_orderby   = 'time DESC'
);
SELECT add_compression_policy('sensor_readings', INTERVAL '7 days');
SELECT add_retention_policy('sensor_readings', INTERVAL '2 years');
```

**Type rationale:**
- `REAL` (4 bytes) for BME280 floats — 7 significant digits, sufficient for sensor resolution (0.01 °C, 0.18 Pa)
- `SMALLINT` (2 bytes) for PM values — range 0–32767 covers PMS5003 max output of 999 µg/m³
- `sensor_id TEXT` for future multi-sensor extension; no lookup table needed (Grafana uses labels directly)
- `sensor_id` in `compress_segmentby` enables per-sensor compression and efficient filtered queries

Row size: ~52 bytes (vs ~76 bytes with DOUBLE PRECISION + INTEGER).

## Architecture

### New files
- `src/storage.jl` — `module StorageLayer`: connection, writer loop, backoff
- `deploy/timescaledb/001_initial.sql` — migration script

### Changed files
- `src/cache.jl` — add `DB_STATE :: Ref{Symbol}(:disconnected)`
- `src/mqtt.jl` — `put!(ch, reading)` after `CACHE[] = reading`
- `src/Sniffbot.jl` — create channel, start storage task, parse `sensor_id`
- `src/formatting.jl` — DB row in `/status` output
- `src/telegram.jl` — import `DB_STATE`
- `Project.toml` — add `LibPQ`
- `.env_template` — add `PG_CONNSTRING`, `SENSOR_ID`

### Data flow

```
on_message(topic, raw)
    ├─► CACHE[] = reading          (real-time, as now)
    └─► put!(ch, reading)          (non-blocking; drops if channel full)

Channel{SensorReading}(512)        (~40 min buffer at 5s publish interval)
    └─► StorageLayer.start_storage(ch, sensor_id)
            loop:
                reading = take!(ch)
                INSERT INTO sensor_readings ...
                DB_STATE[] = :connected
            on error:
                DB_STATE[] = :error
                @warn / @error
                reconnect with exponential backoff (5s → 300s)
                reading dropped (not re-queued)
```

### sensor_id

Derived at startup by splitting `MQTT_TOPIC`:

```
"tele/tasmota_F847F7/SENSOR"  →  split('/')[2]  →  "tasmota_F847F7"
```

Overridable via `SENSOR_ID` env var.

### Connection

`PG_CONNSTRING` env var, defaulting to `postgresql:///sniffbot`
(Unix socket, peer authentication — no password for local deployment).

## Error Handling

| Scenario | Behaviour |
|---|---|
| DB down at startup | Backoff loop; channel buffers readings; `run()` not blocked |
| DB lost mid-run | `DB_STATE[] = :error`; backoff reconnect; channel drains on reconnect |
| Channel full (>512 readings, ~40 min outage) | `@warn` + drop; CACHE still updates |
| INSERT fails | Log + discard; not re-queued (avoids infinite retry loops) |

## DB_STATE values

`:disconnected` — startup or between retries
`:connected` — last write succeeded
`:error` — last write or connection failed

## /status output (after change)

```
⚙ System
MQTT         🟢 connected
DB           🟢 connected
Last         2026-03-08 12:00:00 (1 min ago)
Uptime       2h 15min
```

## Example Grafana query

```sql
SELECT time_bucket('5 minutes', time) AS bucket,
       avg(temperature), avg(humidity), avg(pm2_5)
FROM sensor_readings
WHERE time > NOW() - INTERVAL '24 hours'
  AND sensor_id = 'tasmota_F847F7'
GROUP BY bucket ORDER BY bucket;
```
