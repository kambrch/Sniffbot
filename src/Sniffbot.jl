module Sniffbot
export run

using Dates   # used by cache.jl
using DotEnv

export parse_sensor_id

# Extract device identifier from Tasmota MQTT topic.
# "tele/tasmota_F847F7/SENSOR"  →  "tasmota_F847F7"
# Falls back to the full topic string if format is unexpected.
function parse_sensor_id(topic::String)::String
    parts = split(topic, '/')
    length(parts) >= 2 && !isempty(parts[1]) && !isempty(parts[2]) ? String(parts[2]) : topic
end

include("cache.jl")
include("logging.jl")
include("mqtt.jl")
include("telegram.jl")
include("storage.jl")

function require_env(key::String)::String
    haskey(ENV, key) || error("Required env var $key is not set")
    ENV[key]
end

function run()
    DotEnv.load!(; override=true)   # .env always wins over inherited shell vars
    START_TIME[] = now()  # record bot start time for /status uptime display
    retention_days = let v = tryparse(Int, get(ENV, "LOG_RETENTION_DAYS", "30"))
        isnothing(v) && error("LOG_RETENTION_DAYS must be an integer")
        v
    end
    # log_dir: resolved at runtime so sysimage deployments write to the correct location.
    # Override with SNIFFBOT_LOG_DIR env var; default is logs/ relative to the working directory.
    log_dir = get(ENV, "SNIFFBOT_LOG_DIR", joinpath(pwd(), "logs"))
    setup_logging(log_dir; retention_days)
    broker   = get(ENV, "MQTT_BROKER", "router-hswro")
    port     = let v = tryparse(Int, get(ENV, "MQTT_PORT", "1883"))
        isnothing(v) && error("MQTT_PORT must be an integer")
        v
    end
    username = require_env("MQTT_USERNAME")
    password = require_env("MQTT_PASSWORD")
    topic    = require_env("MQTT_TOPIC")
    token    = require_env("TELEGRAM_TOKEN")
    allowed_ids = let ids = Int[]
        for raw in split(get(ENV, "TELEGRAM_ALLOWED_IDS", ""), ",")
            s = strip(raw)
            isempty(s) && continue
            v = tryparse(Int, s)
            isnothing(v) && error("TELEGRAM_ALLOWED_IDS: $(repr(s)) is not a valid integer chat ID")
            push!(ids, v)
        end
        Set{Int}(ids)
    end

    sensor_id  = get(ENV, "SENSOR_ID", parse_sensor_id(topic))
    connstring = get(ENV, "PG_CONNSTRING", "postgresql:///sniffbot")

    storage_ch = Channel{SensorReading}(512)  # ~40 min buffer at 5s publish interval

    # Storage task — outer supervisor matches MQTT pattern
    storage_task = @async while true
        try
            StorageLayer.start_storage(storage_ch, sensor_id, connstring)
        catch e
            @error "Storage supervisor: task exited, restarting in 10s" exception=(e, catch_backtrace())
            sleep(10)
        end
    end
    errormonitor(storage_task)

    # MQTT task — pass storage channel
    mqtt_task = @async while true
        try
            MQTTLayer.start_mqtt(broker, port, username, password, topic, storage_ch)
        catch e
            @error "MQTT supervisor: task exited unexpectedly, restarting in 10s" exception=(e, catch_backtrace())
            sleep(10)
        end
    end
    errormonitor(mqtt_task)

    TelegramLayer.start_telegram(token, allowed_ids)
end

end # module Sniffbot
