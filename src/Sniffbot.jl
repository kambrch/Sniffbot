module Sniffbot
using Dates   # used by cache.jl

include("cache.jl")
include("logging.jl")
include("mqtt.jl")
include("telegram.jl")

function run()
    START_TIME[] = now()  # record bot start time for /status uptime display
    retention_days = parse(Int, get(ENV, "LOG_RETENTION_DAYS", "30"))
    setup_logging(; retention_days)
    broker      = get(ENV, "MQTT_BROKER", "router-hswro")  # get(dict, key, default): safe access with fallback
    port        = parse(Int, get(ENV, "MQTT_PORT", "1883"))
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
