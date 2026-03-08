module Sniffbot
using Dates   # used by cache.jl
using DotEnv

include("cache.jl")
include("logging.jl")
include("mqtt.jl")
include("telegram.jl")

function run()
    DotEnv.load!(; override=true)   # .env always wins over inherited shell vars
    START_TIME[] = now()  # record bot start time for /status uptime display
    retention_days = let v = tryparse(Int, get(ENV, "LOG_RETENTION_DAYS", "30"))
        isnothing(v) && error("LOG_RETENTION_DAYS must be an integer")
        v
    end
    setup_logging(; retention_days)
    broker      = get(ENV, "MQTT_BROKER", "router-hswro")  # get(dict, key, default): safe access with fallback
    port        = let v = tryparse(Int, get(ENV, "MQTT_PORT", "1883"))
        isnothing(v) && error("MQTT_PORT must be an integer")
        v
    end
    username    = ENV["MQTT_USERNAME"]
    password    = ENV["MQTT_PASSWORD"]
    topic       = ENV["MQTT_TOPIC"]
    token       = ENV["TELEGRAM_TOKEN"]
    allowed_ids = Set{Int}(                                              # generator expression with filter:
        parse(Int, strip(id)) for id in split(get(ENV, "TELEGRAM_ALLOWED_IDS", ""), ",")
        if !isempty(strip(id))                                           # (expr for x in iter if cond) — lazy, no intermediate array
    )

    errormonitor(@async MQTTLayer.start_mqtt(broker, port, username, password, topic))  # errormonitor: logs task errors automatically (Julia 1.7+)
    TelegramLayer.start_telegram(token, allowed_ids)   # blocks in long-poll loop
end

end # module Sniffbot
