ARG BASE=bad
FROM ${BASE}
RUN echo "preload_app = True" >> gunicorn_conf.py
