module TelegramLayer

using Telegrambot, Dates
import ..CACHE, ..BME280Data, ..PMS5003Data, ..SensorReading, ..MQTT_STATE, ..START_TIME, ..LOG_DIR

include("formatting.jl")

# Bot wiring

function make_handler(f::Function, allowed_ids::Set{Int})
    return function (param, msg)
        if !isempty(allowed_ids) && msg["chat"]["id"] ∉ allowed_ids
            @warn "Unauthorized access attempt" chat_id=msg["chat"]["id"]
            return "Unauthorized."
        end
        try
            f(param, msg)
        catch e
            @error "Handler error" exception=(e, catch_backtrace())
            return "⚠ Error: $(typeof(e))"
        end
    end
end

function start_telegram(token::String, allowed_ids::Set{Int}=Set{Int}())

    h(f) = make_handler(f, allowed_ids)

    handlers = Dict{String,Function}(
        "start"       => h((_, _) -> HELP_TEXT),
        "help"        => h((_, _) -> HELP_TEXT),

        "temperature" => h((_, _) -> with_cache(r -> "<pre>" * format_reply(r.bme, :temperature) * "</pre>")),
        "humidity"    => h((_, _) -> with_cache(r -> "<pre>" * format_reply(r.bme, :humidity) * "</pre>")),
        "dew_point"   => h((_, _) -> with_cache(r -> "<pre>" * format_reply(r.bme, :dew_point) * "</pre>")),
        "pressure"    => h((_, _) -> with_cache(r -> "<pre>" * format_reply(r.bme, :pressure) * "</pre>")),

        "pm"          => h((_, _) -> with_cache(r -> format_pm(r.pms))),
        "pm1"         => h((_, _) -> with_cache(r -> "<pre>" * format_reply(r.pms,:pm1) * "</pre>")),
        "pm25"        => h((_, _) -> with_cache(r -> "<pre>" * format_reply(r.pms,:pm25) * "</pre>")),
        "pm10"        => h((_, _) -> with_cache(r -> "<pre>" * format_reply(r.pms,:pm10) * "</pre>")),

        "env"         => h((_, _) -> with_cache(format_env)),
        "all"         => h((_, _) -> with_cache(format_all)),

        "status"      => h((_, _) -> format_status(MQTT_STATE[], CACHE[], START_TIME[])),
    )

    if isempty(allowed_ids)
        @warn "TELEGRAM_ALLOWED_IDS empty — bot open to all users"
    end

    delay = 5
    while true
        try
            @info "Telegram bot starting"
            startBot(token; textHandle=handlers)
            @warn "Telegram polling loop exited unexpectedly"
        catch e
            @error "Telegram bot error" exception=(e, catch_backtrace())
        end
        @info "Restarting Telegram bot in $(delay)s…"
        sleep(delay)
        delay = min(delay * 2, 300)
    end
end

end
