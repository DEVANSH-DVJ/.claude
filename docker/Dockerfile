# ==== base ====
# Shared base: system packages, node, conda, rust, formatters, entrypoint.
# A block runs from its marker to the next; derive.sh drops untaken ones.
# OS image; build.sh passes BASE_OS (a CUDA image works too)
ARG OS=ubuntu:24.04
FROM ${OS}
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo curl wget git ca-certificates build-essential pkg-config xz-utils \
    && rm -rf /var/lib/apt/lists/*

# node from the official tarball; amd64 maps to x64
ARG NODE_VERSION=22.14.0
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${TARGETARCH/amd64/x64}.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1 --exclude='*/CHANGELOG.md' --exclude='*/README.md' --exclude='*/LICENSE'

# miniconda pinned to py311, matching environment.yml
ARG MINICONDA_VERSION=py311_26.7.1-1
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN curl -fsSL "https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-$(uname -m).sh" -o /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p "$CONDA_DIR" \
    && rm /tmp/miniconda.sh \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# rust / cargo, minimal profile plus clippy and rustfmt
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
ENV PATH=$CARGO_HOME/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable -c clippy -c rustfmt

# formatters, grouped last so they are easy to edit
RUN apt-get update && apt-get install -y --no-install-recommends shfmt clang-format \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g prettier \
    && pip install --no-cache-dir ruff

# interactive entrypoint (exec.sh overrides this with bash)
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ==== drawio ====
# draw.io desktop, Xvfb, poppler, pdf python tools, and licensed fonts.

# draw.io desktop; export runs through .claude/skills/drawio/scripts/export.sh
ARG DRAWIO_VERSION=31.3.2
RUN curl -fsSL "https://github.com/jgraph/drawio-desktop/releases/download/v${DRAWIO_VERSION}/drawio-${TARGETARCH}-${DRAWIO_VERSION}.deb" -o /tmp/drawio.deb \
    && apt-get update && apt-get install -y --no-install-recommends xvfb /tmp/drawio.deb \
      libasound2t64 libgbm1 libnss3 libgtk-3-0t64 libxss1 libxtst6 libsecret-1-0 libnotify4 \
    && rm -rf /var/lib/apt/lists/* /tmp/drawio.deb

# poppler for pdf rendering
RUN apt-get update && apt-get install -y --no-install-recommends poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# pdf python tools for the pdf addon
RUN pip install --no-cache-dir pdf2image pillow

# fontconfig and licensed fonts, last so font edits rebuild little
RUN apt-get update && apt-get install -y --no-install-recommends fontconfig \
    && rm -rf /var/lib/apt/lists/*
COPY fonts/ /usr/share/fonts/truetype/local/
RUN fc-cache -f

# ==== slides ====
# LibreOffice Impress and deck python tools for the pptx addon.

# LibreOffice Impress for deck rendering
RUN apt-get update && apt-get install -y --no-install-recommends libreoffice-impress \
    && rm -rf /var/lib/apt/lists/*

# deck python tools for the pptx addon
RUN pip install --no-cache-dir python-pptx lxml "markitdown[pptx]"

# ==== project ====
# Project-owned from this marker on; derive.sh --sync keeps it.
# conda env from environment.yml
COPY environment.yml /tmp/environment.yml
RUN conda env update -n base -f /tmp/environment.yml && conda clean -afy

# ---- project toolchain: add the project's own blocks below ----

# workspace and interactive entrypoint
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
