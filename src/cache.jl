# Structs are immutable by default in Julia — safe to share across tasks without copying
struct BME280Data
    temperature::Float64   # °C
    humidity::Float64      # %
    dew_point::Float64     # °C
    pressure::Float64      # hPa
end

struct PMS5003Data
    pm1::Int               # µg/m³
    pm2_5::Int             # µg/m³
    pm10::Int              # µg/m³
end

struct SensorReading
    bme::BME280Data
    pms::PMS5003Data
    received_at::DateTime
end

# Ref wraps an immutable value in a mutable container — Julia pattern for shared mutable state
const CACHE = Ref{Union{Nothing, SensorReading}}(nothing)

# Symbol ref for MQTT connection state — updated by MQTTLayer
const MQTT_STATE = Ref{Symbol}(:disconnected)

# Bot start time — initialized at module load; reset to now() at run() entry for accurate uptime
const START_TIME = Ref{DateTime}(now())
