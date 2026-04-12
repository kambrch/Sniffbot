FROM julia:1.11-bookworm AS builder

WORKDIR /build
COPY Project.toml Manifest.toml ./
RUN julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
COPY src/ src/

FROM julia:1.11-bookworm

WORKDIR /opt/sniffbot
COPY --from=builder /build /opt/sniffbot
RUN mkdir -p logs

CMD ["julia", "--project", "-e", "using Sniffbot; Sniffbot.run()"]
