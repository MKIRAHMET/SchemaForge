FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
bash \
&& apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash model \
&& mkdir -p /workdir \
&& chown model:model /workdir

WORKDIR /workdir

# ------------ DO NOT CHANGE BELOW --------------

COPY ./tests/ /tests/
COPY ./solution.sh /tests/
COPY ./grader.py /tests/
COPY ./data /workdir/data

RUN chown -R model:model /workdir/data \
&& chmod -R 700 /workdir/data