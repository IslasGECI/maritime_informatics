FROM islasgeci/base:1.0.0
COPY . /workdir
RUN apt update && \
    apt install --yes postgresql-client && \
    rm --force --recursive /var/lib/apt/lists/*
