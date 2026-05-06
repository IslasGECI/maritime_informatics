FROM islasgeci/base:22.04
COPY . /workdir
RUN apt update && \
    apt install --yes \
        gdal-bin \
        gmt \
        postgis \
        postgresql-client \
    && rm --force --recursive /var/lib/apt/lists/*
