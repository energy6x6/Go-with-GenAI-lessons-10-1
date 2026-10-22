FROM golang:1.27.3@sha256:f20d83a83e18dbd2a4714b8ffd4b30b287b6243962dd75608e86abcc63ba4efc AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
RUN CGO_ENABLED=0 go build -trimpath -o /out/libratrack ./cmd/api \
 && CGO_ENABLED=0 go build -trimpath -o /out/demo-users ./cmd/demo-users \
 && CGO_ENABLED=0 go build -trimpath -o /out/healthcheck ./cmd/healthcheck

FROM scratch
COPY --from=build /out/ /
ENV LISTEN_HOST=0.0.0.0 PORT=8080 GIN_MODE=release
EXPOSE 8080
USER 65532:65532
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=6 CMD ["/healthcheck"]
ENTRYPOINT ["/libratrack"]
