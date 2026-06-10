ARG DEBIAN_IMAGE=debian:bookworm-slim

FROM ${DEBIAN_IMAGE} AS builder

LABEL maintainer="carlo.mancini-terracciano@uniroma1.it"

ARG APPTAINER_VERSION
ARG BUILD_DATE
ARG TARGETARCH
ARG DEBIAN_IMAGE
ARG GO_VERSION

ENV LANG=C.UTF-8
ENV PATH="/usr/local/go/bin:${PATH}"

RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get -yq --no-install-recommends install \
      ca-certificates \
      curl \
      git \
      build-essential \
      pkg-config \
      squashfs-tools \
      cryptsetup-bin \
      uidmap \
      libseccomp-dev \
      libglib2.0-dev \
      libfuse3-dev \
      libssl-dev \
      uuid-dev \
      libgpgme-dev \
      libassuan-dev \
      libdevmapper-dev \
      wget \
    && \
    apt-get -y clean && \
    rm -rf /var/cache/apt/archives/* \
           /var/lib/apt/lists/*

RUN test -n "${APPTAINER_VERSION}" || (echo "ERROR: APPTAINER_VERSION is not set" >&2; exit 1) && \
    test -n "${TARGETARCH}" || (echo "ERROR: TARGETARCH is not set" >&2; exit 1) && \
    case "${TARGETARCH}" in \
      amd64) GO_ARCH="amd64" ;; \
      arm64) GO_ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" && \
    echo "Downloading Go from: ${GO_URL}" && \
    curl -fsSL --retry 5 --retry-delay 10 \
      "${GO_URL}" \
      --output /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm -f /tmp/go.tar.gz && \
    go version

RUN APPTAINER_URL="https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}.tar.gz" && \
    echo "Downloading Apptainer from: ${APPTAINER_URL}" && \
    curl -fsSL --retry 5 --retry-delay 10 \
      "${APPTAINER_URL}" \
      --output /tmp/apptainer.tar.gz && \
    mkdir -p /tmp/apptainer && \
    tar -xzf /tmp/apptainer.tar.gz -C /tmp/apptainer --strip-components=1 && \
    cd /tmp/apptainer && \
    ./mconfig --prefix=/usr/local --without-suid && \
    make -C builddir && \
    make -C builddir install && \
    rm -rf /tmp/apptainer /tmp/apptainer.tar.gz

#######################################################################

FROM ${DEBIAN_IMAGE}

LABEL maintainer="carlo.mancini-terracciano@uniroma1.it"

ARG APPTAINER_VERSION
ARG BUILD_DATE
ARG DEBIAN_IMAGE

LABEL org.label-schema.apptainer-version="${APPTAINER_VERSION}"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.name="carlomt/apptainer"
LABEL org.label-schema.description="Apptainer Docker image"
LABEL org.label-schema.url="https://github.com/carlomt/apptainer"
LABEL org.label-schema.base-image="${DEBIAN_IMAGE}"
LABEL org.label-schema.docker.cmd="docker build -t carlomt/apptainer:latest ."

ENV LANG=C.UTF-8

RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get -yq --no-install-recommends install \
      ca-certificates \
      squashfs-tools \
      cryptsetup-bin \
      uidmap \
      fuse3 \
      libseccomp2 \
      libglib2.0-0 \
      libfuse3-3 \
      libssl3 \
      libgpgme11 \
      libassuan0 \
      libdevmapper1.02.1 \
    && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/cache/apt/archives/* \
           /var/lib/apt/lists/*

COPY --from=builder /usr/local/ /usr/local/

RUN apptainer --version && \
    apptainer buildcfg

WORKDIR /workspace

CMD ["bash"]