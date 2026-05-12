FROM mcr.microsoft.com/devcontainers/python:1-3.12

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        build-essential \
        git \
        pkg-config \
        libglib2.0-0 \
        libnss3 \
        libsm6 \
        libxrender1 \
        libxext6 \
        libfontconfig1 \
        libjpeg62-turbo-dev \
        libpng-dev \
        libavcodec-dev \
        libavformat-dev \
        libavdevice-dev \
        libavfilter-dev \
        libavutil-dev \
        libswscale-dev \
        libswresample-dev \
        libpostproc-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_DEFAULT_TIMEOUT=100

RUN python -m pip install --upgrade pip setuptools wheel
