FROM ghcr.io/coreweave/nccl-tests:12.4.1-devel-ubuntu20.04-nccl2.27.3-1-d82e3c0

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

ENV PYTHON_VERSION=3.12

ENV CUDA_HOME=/usr/local/cuda/
ENV NVSHMEM_VERSION=3.2.5-1
ENV NVSHMEM_PREFIX=/opt/nvshmem-${NVSHMEM_VERSION}

ENV VENV_PATH="/app/venv"
ENV PYTHON="${VENV_PATH}/bin/python"
ENV PATH="${VENV_PATH}/bin:${PATH}"

RUN echo 'tzdata tzdata/Areas select America' | debconf-set-selections \
    && echo 'tzdata tzdata/Zones/America select New_York' | debconf-set-selections \
    && apt-get -qq update \
    && apt-get -qq install -y ccache software-properties-common git wget curl \
    && for i in 1 2 3; do \
        add-apt-repository -y ppa:deadsnakes/ppa && break || \
        { echo "Attempt $i failed, retrying in 5s..."; sleep 5; }; \
    done \
    && apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends \
      # Python and related tools
      python${PYTHON_VERSION} \
      python${PYTHON_VERSION}-dev \
      python${PYTHON_VERSION}-venv \
      ca-certificates \
      htop \
      iputils-ping net-tools \
      vim ripgrep bat clangd fuse fzf \
      nodejs npm clang fd-find xclip \
      zsh \
      # Build tools for UCX, NVSHMEM, etc.
      build-essential \
      autoconf automake libtool pkg-config \
      ninja-build cmake \
      # Other dependencies
      libnuma1 libsubunit0 libpci-dev \
      # MPI / PMIx / libfabric for NVSHMEM
      libopenmpi-dev openmpi-bin \
      libpmix-dev libfabric-dev \
      datacenter-gpu-manager \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install UV and up-to-date cmake
RUN curl -LsSf https://astral.sh/uv/install.sh \
        | env UV_INSTALL_DIR="/usr/local/bin/" sh
ENV UV="/usr/local/bin/uv"
RUN "${UV}" venv "${VENV_PATH}"
RUN "${UV}" pip install --python "${PYTHON}" \
      --no-progress --no-cache-dir "cmake<4.0"


# --- Build and Install NVSHMEM from Source ---
ENV CC=/usr/bin/mpicc
ENV CXX=/usr/bin/mpicxx
ENV MAX_JOBS=32
RUN cd /tmp \
    && wget https://developer.nvidia.com/downloads/assets/secure/nvshmem/nvshmem_src_${NVSHMEM_VERSION}.txz \
    && tar -xf nvshmem_src_${NVSHMEM_VERSION}.txz \
    && cd nvshmem_src \
    && mkdir build \
    && cd build \
    && cmake \
      -G Ninja \
      -DCMAKE_C_COMPILER=${CC}           \
      -DCMAKE_CXX_COMPILER=${CXX}        \
      -DMPI_C_COMPILER=${CC}             \
      -DMPI_CXX_COMPILER=${CXX}          \
      -DMPI_HOME=/usr/lib/x86_64-linux-gnu/openmpi \
      -DNVSHMEM_PREFIX=${NVSHMEM_PREFIX} \
      -DCMAKE_CUDA_ARCHITECTURES="90a"   \
      -DNVSHMEM_MPI_SUPPORT=1            \
      -DNVSHMEM_PMIX_SUPPORT=0           \
      -DNVSHMEM_LIBFABRIC_SUPPORT=0      \
      -DNVSHMEM_IBRC_SUPPORT=1           \
      -DNVSHMEM_IBGDA_SUPPORT=1          \
      -DNVSHMEM_IBDEVX_SUPPORT=1         \
      -DNVSHMEM_USE_GDRCOPY=1            \
      -DNVSHMEM_BUILD_TESTS=1            \
      -DNVSHMEM_BUILD_EXAMPLES=0         \
      -DLIBFABRIC_HOME=/usr              \
      .. \
    && ninja -j${MAX_JOBS} \
    && ninja -j${MAX_JOBS} install

ENV PATH=${NVSHMEM_PREFIX}/bin:${PATH}
ENV LD_LIBRARY_PATH=${NVSHMEM_PREFIX}/lib:${LD_LIBRARY_PATH}
ENV CPATH=${NVSHMEM_PREFIX}/include:${CPATH}
ENV LIBRARY_PATH=${NVSHMEM_PREFIX}/lib:${LIBRARY_PATH}
ENV PKG_CONFIG_PATH=${NVSHMEM_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}

WORKDIR /app/
ENTRYPOINT ["sleep", "infinity"]
