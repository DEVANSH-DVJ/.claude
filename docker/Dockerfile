# Template dev image. Edit the bunched blocks below for the project's toolchain.
# Build context is docker/ (see build.sh); runtime code is bind-mounted at /workspace.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# --- system packages + formatters (edit this block) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo curl wget git ca-certificates build-essential pkg-config \
      shfmt clang-format nodejs npm \
    && npm install -g prettier \
    && rm -rf /var/lib/apt/lists/*

# --- miniconda + conda env (edit environment.yml) ---
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN curl -fsSL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh" -o /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p "$CONDA_DIR" \
    && rm /tmp/miniconda.sh
COPY environment.yml /tmp/environment.yml
RUN conda env update -n base -f /tmp/environment.yml && conda clean -afy

# --- rust / cargo (edit toolchain + components) ---
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
ENV PATH=$CARGO_HOME/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --component rustfmt clippy

# --- interactive entrypoint (exec.sh overrides this with bash) ---
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
