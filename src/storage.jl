module StorageLayer

using LibPQ, Dates
import ..SensorReading, ..DB_STATE

const RECONNECT_DELAY_INITIAL = 5
const RECONNECT_DELAY_MAX     = 300

const INSERT_SQL = """
    INSERT INTO sensor_readings
        (time, sensor_id, temperature, humidity, dew_point, pressure, pm1, pm2_5, pm10)
    VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)
"""

function start_storage(ch::Channel{SensorReading}, sensor_id::String, connstring::String)
    delay = RECONNECT_DELAY_INITIAL
    while true
        conn = nothing
        try
            conn = LibPQ.Connection(connstring)
            DB_STATE[] = :connected
            @info "DB connected" connstring
            delay = RECONNECT_DELAY_INITIAL
            while true
                r = take!(ch)
                execute(conn, INSERT_SQL, [
                    r.received_at, sensor_id,
                    r.bme.temperature, r.bme.humidity, r.bme.dew_point, r.bme.pressure,
                    r.pms.pm1, r.pms.pm2_5, r.pms.pm10,
                ])
            end
        catch e
            DB_STATE[] = :error
            @error "DB error, reconnecting in $(delay)s" exception=(e, catch_backtrace())
            conn !== nothing && close(conn)
        end
        sleep(delay)
        delay = min(delay * 2, RECONNECT_DELAY_MAX)
    end
end

end # module StorageLayer
