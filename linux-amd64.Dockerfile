FROM golang:alpine as builder

ARG VERSION
ENV CGO_ENABLED=1
RUN apk add --no-cache git gcc musl-dev nodejs npm && \
    git clone -n https://github.com/AnalogJ/scrutiny.git /scrutiny && cd /scrutiny && \
    git checkout ${VERSION} -b hotio && \
    go mod vendor && \
    go build -ldflags '-w -extldflags "-static"' -o scrutiny webapp/backend/cmd/scrutiny/scrutiny.go && \
    go build -ldflags '-w -extldflags "-static"' -o scrutiny-collector-selftest collector/cmd/collector-selftest/collector-selftest.go && \
    go build -ldflags '-w -extldflags "-static"' -o scrutiny-collector-metrics collector/cmd/collector-metrics/collector-metrics.go && \
    chmod 755 "/scrutiny/scrutiny" && \
    chmod 755 "/scrutiny/scrutiny-collector-selftest" && \
    chmod 755 "/scrutiny/scrutiny-collector-metrics" && \
    cd /scrutiny/webapp/frontend && \
    mkdir /scrutiny-web && \
    npm install && \
    npx ng build --output-path=/scrutiny-web --deploy-url="/web/" --base-href="/web/" --prod

FROM hotio/base@sha256:8dab11de6a8e64fbbdef2b1ef1b6c64ff8ada8401589d0b4d384ad20300fb24e
EXPOSE 8080
ENV INTERVAL=86400 API_ENDPOINT="http://localhost:8080" MODE="both"
RUN apk add --no-cache smartmontools && \
    mkdir -p /scrutiny/config && \
    ln -s "${CONFIG_DIR}/app/scrutiny.yaml" /scrutiny/config/scrutiny.yaml && \
    ln -s "${CONFIG_DIR}/app/collector.yaml" /scrutiny/config/collector.yaml
COPY --from=builder /scrutiny/scrutiny ${APP_DIR}/
COPY --from=builder /scrutiny/scrutiny-collector-selftest ${APP_DIR}/
COPY --from=builder /scrutiny/scrutiny-collector-metrics ${APP_DIR}/
COPY --from=builder /scrutiny-web ${APP_DIR}/scrutiny-web/
COPY root/ /
