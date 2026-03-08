# Build a precompiled sysimage to eliminate TTFX on first Telegram command.
#
# Usage (from project root):
#   julia --project=build build/build_sysimage.jl
#
# Run the bot with:
#   julia --sysimage sniffbot.so -e 'using Sniffbot; Sniffbot.run()'

using PackageCompiler

@info "Building sysimage — this takes a few minutes…"

create_sysimage(
    ["Sniffbot"];
    sysimage_path           = joinpath(@__DIR__, "..", "sniffbot.so"),
    precompile_execution_file = joinpath(@__DIR__, "precompile.jl"),
)

@info "Done. Run with: julia --sysimage sniffbot.so -e 'using Sniffbot; Sniffbot.run()'"
