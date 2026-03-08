module MQTTLayer

using MQTTClient, JSON3, Dates
import ..CACHE, ..SensorReading, ..BME280Data, ..PMS5003Data, ..MQTT_STATE

const RECONNECT_DELAY_INITIAL = 5    # seconds
const RECONNECT_DELAY_MAX     = 300  # 5 minutes

function start_mqtt(broker::String, port::Int, username::String, password::String, topic::String)
    delay = RECONNECT_DELAY_INITIAL
    while true
        try
            client, conn = MakeConnection(broker, port; user=User(username, password))
            MQTT_STATE[] = :connecting
            connect(client, conn)
            @info "MQTT connected" broker topic
            MQTT_STATE[] = :connected  # mark connected after successful handshake
            subscribe(client, topic, on_message; qos=QOS_0)
            delay = RECONNECT_DELAY_INITIAL  # reset backoff after a successful connect
            fetch(client)                    # blocks until broker disconnects
            @warn "MQTT connection lost"
            MQTT_STATE[] = :disconnected
        catch e
            MQTT_STATE[] = :disconnected
            @error "MQTT connection failed" exception=(e, catch_backtrace())
        end
        @info "Reconnecting in $(delay)s…"
        sleep(delay)
        delay = min(delay * 2, RECONNECT_DELAY_MAX)
    end
end

# Physical limits: BME280 datasheet + PMS5003 datasheet (max output 999 µg/m³
# `condition || (side-effect; return false)` is idiomatic short-circuit guard clause
function valid_reading(b::BME280Data, p::PMS5003Data)::Bool
    -40 ≤ b.temperature ≤ 85   || (@warn "Temperature out of range" value=b.temperature; return false)
    0   ≤ b.humidity    ≤ 100  || (@warn "Humidity out of range"    value=b.humidity;    return false)
    -40 ≤ b.dew_point   ≤ 85   || (@warn "Dew point out of range"   value=b.dew_point;   return false)
    300 ≤ b.pressure    ≤ 1100 || (@warn "Pressure out of range"    value=b.pressure;    return false)
    0   ≤ p.pm1         ≤ 999  || (@warn "PM1 out of range"         value=p.pm1;         return false)
    0   ≤ p.pm2_5       ≤ 999  || (@warn "PM2.5 out of range"       value=p.pm2_5;       return false)
    0   ≤ p.pm10        ≤ 999  || (@warn "PM10 out of range"        value=p.pm10;        return false)
    return true
end

function on_message(topic::String, raw::Vector{UInt8})
    try
        data = JSON3.read(String(raw))
        b = data.BME280
        p = data.PMS5003
        bme = BME280Data(b.Temperature, b.Humidity, b.DewPoint, b.Pressure)
        pms = PMS5003Data(p.PM1, p[Symbol("PM2.5")], p.PM10)
        valid_reading(bme, pms) || return  # short-circuit early exit on invalid data
        received_at = now()
        CACHE[] = SensorReading(bme, pms, received_at)
        @info "Sensor reading cached" received_at
    catch e
        @error "Failed to parse MQTT payload" exception=(e, catch_backtrace())
    end
end

end # module
