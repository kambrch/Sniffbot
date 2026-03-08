# Formatting helpers

const STALE_THRESHOLD = Minute(10)
const COL_WIDTH = 12

timestamp(dt::DateTime) = Dates.format(dt, "yyyy-mm-dd HH:MM:SS")

function age_string(dt::DateTime)::String
    delta = now() - dt
    mins = Dates.value(delta) ÷ 60_000
    mins < 1 && return "<1 min ago"
    mins < 60 && return "$mins min ago"
    h = mins ÷ 60
    m = mins % 60
    return "$(h)h $(m)min ago"
end

function metric_row(label, value, unit="")
    name = rpad(label, COL_WIDTH)
    isempty(unit) ? "$name $value" : "$name $value $unit"
end

function pre_block(title, rows)
    "<b>$title</b>\n<pre>" * join(rows, "\n") * "</pre>"
end

# Field formatters

format_reply(b::BME280Data, field::Symbol) = format_reply(Val(field), b)

format_reply(::Val{:temperature}, b::BME280Data) =
    metric_row("Temperature", b.temperature, "°C")

format_reply(::Val{:humidity}, b::BME280Data) =
    metric_row("Humidity", b.humidity, "%")

format_reply(::Val{:dew_point}, b::BME280Data) =
    metric_row("Dew point", b.dew_point, "°C")

format_reply(::Val{:pressure}, b::BME280Data) =
    metric_row("Pressure", b.pressure, "hPa")

format_reply(p::PMS5003Data, field::Symbol) = format_reply(Val(field), p)

format_reply(::Val{:pm1}, p::PMS5003Data) =
    metric_row("PM1", p.pm1, "µg/m³")

format_reply(::Val{:pm25}, p::PMS5003Data) =
    metric_row("PM2.5", p.pm2_5, "µg/m³")

format_reply(::Val{:pm10}, p::PMS5003Data) =
    metric_row("PM10", p.pm10, "µg/m³")

# Block formatters

function format_env(r::SensorReading)::String
    rows = [
        format_reply(r.bme, :temperature),
        format_reply(r.bme, :humidity),
        format_reply(r.bme, :dew_point),
        format_reply(r.bme, :pressure),
    ]
    pre_block("🌡 Environment", rows)
end

function format_pm(p::PMS5003Data)::String
    rows = [
        format_reply(p, :pm1),
        format_reply(p, :pm25),
        format_reply(p, :pm10),
    ]
    pre_block("🌫 Particulates", rows)
end

function format_all(r::SensorReading)::String
    join([
        format_env(r),
        format_pm(r.pms),
        "🕒 Updated: $(timestamp(r.received_at))",
    ], "\n\n")
end

function format_status(mqtt_state::Symbol,
                       db_state::Symbol,
                       reading::Union{Nothing,SensorReading},
                       start_time::DateTime)::String

    elapsed = now() - start_time
    mins = Dates.value(elapsed) ÷ 60_000
    uptime = "$(mins ÷ 60)h $(mins % 60)min"

    mqtt_icon =
        mqtt_state === :connected  ? "🟢" :
        mqtt_state === :connecting ? "🟡" :
        "🔴"

    db_icon =
        db_state === :connected ? "🟢" :
        db_state === :error     ? "🔴" :
        "🟡"                          # :disconnected — not yet tried

    last =
        isnothing(reading) ?
        "none yet" :
        "$(timestamp(reading.received_at)) ($(age_string(reading.received_at)))"

    rows = [
        metric_row("MQTT",   "$mqtt_icon $mqtt_state"),
        metric_row("DB",     "$db_icon $db_state"),
        metric_row("Last",   last),
        metric_row("Uptime", uptime),
    ]

    pre_block("⚙ System", rows)
end

# Cache freshness

function stale_suffix(r::SensorReading)::String
    age = now() - r.received_at
    age > STALE_THRESHOLD || return ""
    mins = Dates.value(age) ÷ 60_000
    "\n\n⚠ Stale data: last update $(mins) min ago."
end

function with_cache(f)::String
    r = CACHE[]
    isnothing(r) && return "No reading yet — sensor hasn't reported."
    f(r) * stale_suffix(r)
end

# Help

const HELP_TEXT = """
📊 Overview
/env         — Environmental parameters
/pm          — Particulate matter
/all         — Full snapshot

🔬 Individual readings
/temperature — Air temperature
/humidity    — Relative humidity
/dew_point   — Dew point
/pressure    — Atmospheric pressure
/pm1         — PM1
/pm25        — PM2.5
/pm10        — PM10

⚙ System
/status      — MQTT & DB state, last reading, uptime
/start       — Show this message
/help        — Show this message
"""
