# syntax=docker/dockerfile:1
# MinIO server + mc built from the official upstream source at pinned release tags.
# MinIO stopped publishing community images/binaries (docker.io/minio withdrawn,
# quay.io/minio private, dl.min.io archive -> 410), so we build the same releases
# ourselves. Runtime layout mirrors upstream Dockerfile.release so it is a drop-in.

ARG MINIO_TAG=RELEASE.2025-09-07T16-13-09Z
ARG MC_TAG=RELEASE.2025-08-13T08-35-41Z

FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build
ARG MINIO_TAG
ARG MC_TAG
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0 GOTOOLCHAIN=auto GOOS=$TARGETOS GOARCH=$TARGETARCH
RUN apk add --no-cache git ca-certificates
WORKDIR /src
RUN git clone --depth 1 --branch "$MINIO_TAG" https://github.com/minio/minio.git minio \
 && git clone --depth 1 --branch "$MC_TAG" https://github.com/minio/mc.git mc
# Upstream release builds pass the release time (RFC3339) and MINIO_RELEASE=RELEASE,
# which yields ReleaseTag=RELEASE.<tag> exactly like the official binaries.
RUN cd minio \
 && V=$(echo "$MINIO_TAG" | sed -E 's/^RELEASE\.([0-9-]+)T([0-9]+)-([0-9]+)-([0-9]+)Z$/\1T\2:\3:\4Z/') \
 && LDF=$(GOOS= GOARCH= MINIO_RELEASE=RELEASE go run buildscripts/gen-ldflags.go "$V") \
 && go build -tags kqueue -trimpath -ldflags "$LDF" -o /out/minio
RUN cd mc \
 && V=$(echo "$MC_TAG" | sed -E 's/^RELEASE\.([0-9-]+)T([0-9]+)-([0-9]+)-([0-9]+)Z$/\1T\2:\3:\4Z/') \
 && LDF=$(GOOS= GOARCH= MC_RELEASE=RELEASE go run buildscripts/gen-ldflags.go "$V") \
 && go build -tags kqueue -trimpath -ldflags "$LDF" -o /out/mc
RUN cp minio/dockerscripts/docker-entrypoint.sh /out/ \
 && mkdir -p /out/licenses/minio /out/licenses/mc \
 && cp minio/LICENSE minio/CREDITS /out/licenses/minio/ \
 && cp mc/LICENSE mc/CREDITS /out/licenses/mc/

FROM registry.access.redhat.com/ubi9/ubi-micro:latest AS minio
ARG MINIO_TAG
LABEL org.opencontainers.image.source="https://github.com/stackmakers-ai/minio-images" \
      org.opencontainers.image.description="MinIO server ${MINIO_TAG} built from official upstream source" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      version="${MINIO_TAG}" release="${MINIO_TAG}"
ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_CONFIG_ENV_FILE=config.env \
    MC_CONFIG_DIR=/tmp/.mc
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /out/minio /out/mc /out/docker-entrypoint.sh /usr/bin/
COPY --from=build /out/licenses /licenses
EXPOSE 9000
VOLUME ["/data"]
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]

FROM registry.access.redhat.com/ubi9/ubi-micro:latest AS mc
ARG MC_TAG
LABEL org.opencontainers.image.source="https://github.com/stackmakers-ai/minio-images" \
      org.opencontainers.image.description="MinIO client (mc) ${MC_TAG} built from official upstream source" \
      org.opencontainers.image.licenses="AGPL-3.0"
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /out/mc /usr/bin/mc
COPY --from=build /out/licenses/mc /licenses
ENTRYPOINT ["mc"]
