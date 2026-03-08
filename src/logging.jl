using Logging, LoggingExtras, Dates

# Daily rotation: sniffbot-yyyy-mm-dd.log
# Only `s` needs escaping — it is a DateFormat code (milliseconds); all other letters are literals
const LOG_PATTERN = "\\sniffbot-yyyy-mm-dd.log"

function format_log(io::IO, log)
    ts    = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    level = rpad(string(log.level), 5)
    print(io, ts, " [", level, "] ", log.message)
    for (k, v) in log.kwargs
        if k === :exception && v isa Tuple
            print(io, " | exception=", sprint(showerror, v...))
        else
            print(io, " | ", k, "=", v)
        end
    end
    println(io, " @ $(log.file):$(log.line)")
end

function make_cleanup_callback(log_dir::String, retention_days::Int)
    function (::String)  # inner function is the implicit return value of the outer function
        cutoff = today() - Day(retention_days)
        for fname in readdir(log_dir)
            m = match(r"sniffbot-(\d{4}-\d{2}-\d{2})\.log$", fname)
            isnothing(m) && continue  # nil check
            Date(m[1]) < cutoff || continue
            rm(joinpath(log_dir, fname))
            @info "Deleted old log file" file=fname
        end
    end
end

function setup_logging(log_dir::String; retention_days::Int=30)
    mkpath(log_dir)
    cleanup = make_cleanup_callback(log_dir, retention_days)
    file_logger = DatetimeRotatingFileLogger(format_log, log_dir, LOG_PATTERN; rotation_callback=cleanup)
    logger = TeeLogger(
        MinLevelLogger(FormatLogger(format_log, stderr), Logging.Info),
        MinLevelLogger(file_logger, Logging.Info),
    )
    global_logger(logger)
    @info "Logging initialized" log_dir retention_days
end
