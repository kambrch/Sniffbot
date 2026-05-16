FROM julia:1.12-bookworm AS builder

WORKDIR /build
COPY Project.toml Manifest.toml ./
RUN julia --project -e 'using Pkg; Pkg.instantiate()'
COPY src/ src/
RUN julia --project -e 'using Pkg; Pkg.precompile()'

FROM julia:1.12-bookworm

WORKDIR /opt/sniffbot
COPY --from=builder /build /opt/sniffbot
COPY --from=builder /root/.julia /root/.julia
RUN mkdir -p logs

CMD ["julia", "--project", "-e", "using Sniffbot; Sniffbot.run()"]
