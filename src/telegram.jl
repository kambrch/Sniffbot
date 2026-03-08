module TelegramLayer

using Telegrambot, Dates
import ..CACHE, ..BME280Data, ..PMS5003Data, ..SensorReading, ..MQTT_STATE, ..START_TIME

include("formatting.jl")

# Rate limiting

const RATE_WINDOW = 60    # seconds
const RATE_MAX    = 20    # requests per window per user
const rate_cache = Dict{Int, Vector{Float64}}()

function rate_limited(chat_id::Int)::Bool
    now_ts = time()
    cutoff = now_ts - RATE_WINDOW
    times  = get!(() -> Float64[], rate_cache, chat_id)
    filter!(t -> t > cutoff, times)
    length(times) >= RATE_MAX && return true
    push!(times, now_ts)
    false
end

# Bot wiring

function make_handler(f, allowed_ids::Set{Int})
    return function (param, msg)
        chat_id = msg["chat"]["id"]
        if isempty(allowed_ids) || chat_id ∉ allowed_ids
            @warn "Unauthorized access attempt" chat_id
            return "Unauthorized."
        end
        if rate_limited(chat_id)
            @warn "Rate limit exceeded" chat_id
            return "⚠ Too many requests — slow down."
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
        @warn "TELEGRAM_ALLOWED_IDS not set — all requests will be denied"
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

end # module TelegramLayer
