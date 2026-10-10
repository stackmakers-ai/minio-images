# minio-images

MinIO server and `mc` client container images, built from the **official upstream source**
(github.com/minio/minio, github.com/minio/mc) at pinned release tags.

MinIO no longer publishes community images or binaries (docker.io/minio withdrawn,
quay.io/minio private, dl.min.io archive returns 410), so the stacks that run MinIO pull these instead.

| Image | Tag |
|---|---|
| `ghcr.io/stackmakers-ai/minio` | `RELEASE.2025-09-07T16-13-09Z` |
| `ghcr.io/stackmakers-ai/mc` | `RELEASE.2025-08-13T08-35-41Z` |

The runtime layout mirrors upstream `Dockerfile.release` (ubi9-micro, `minio` + `mc` in `/usr/bin`,
same entrypoint and env), so it is a drop-in for `quay.io/minio/minio` / `quay.io/minio/mc`.

To build a newer release: change `MINIO_TAG` / `MC_TAG` in `.github/workflows/build.yml` and push.
Licensed AGPL-3.0 (upstream).
