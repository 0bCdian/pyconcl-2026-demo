ARG BASE=bad
FROM ${BASE}
COPY gunicorn_conf.py ./
