# Precompile execution file for PackageCompiler.
# Exercises all hot paths so they are compiled into the sysimage,
# eliminating first-request latency after startup.
# Does NOT connect to MQTT or Telegram — purely local computation.

using Sniffbot
using Dates

# Simulate an MQTT payload to compile JSON parsing + struct construction
const PAYLOAD = Vector{UInt8}("""{"Time":"2026-03-08T12:00:00","BME280":{"Temperature":20.7,"Humidity":24.4,"DewPoint":-0.4,"Pressure":1013.4},"PMS5003":{"CF1":22,"CF2.5":32,"CF10":49,"PM1":22,"PM2.5":32,"PM10":49,"PB0.3":4146,"PB0.5":934,"PB1":153,"PB2.5":48,"PB5":8,"PB10":2},"PressureUnit":"hPa","TempUnit":"C"}""")

Sniffbot.setup_logging(tempdir(); retention_days=1)
Sniffbot.MQTTLayer.on_message("test/topic", PAYLOAD)

# Exercise all formatters with a cached reading
const TL = Sniffbot.TelegramLayer
const r  = Sniffbot.CACHE[]

if !isnothing(r)
    TL.format_env(r)
    TL.format_pm(r.pms)
    TL.format_all(r)
    TL.format_reply(r.bme, :temperature)
    TL.format_reply(r.bme, :humidity)
    TL.format_reply(r.bme, :dew_point)
    TL.format_reply(r.bme, :pressure)
    TL.format_reply(r.pms, :pm1)
    TL.format_reply(r.pms, :pm25)
    TL.format_reply(r.pms, :pm10)
    TL.with_cache(TL.format_env)
    TL.with_cache(TL.format_all)
    TL.stale_suffix(r)
end

# Exercise status formatting for all MQTT states
for state in (:connected, :connecting, :disconnected)
    TL.format_status(state, Sniffbot.CACHE[], Sniffbot.START_TIME[])
    TL.format_status(state, nothing,           Sniffbot.START_TIME[])
end

# Exercise age_string across time ranges
for mins in (0, 1, 30, 90)
    TL.age_string(now() - Minute(mins))
end
