ARG BASE=bad
FROM ${BASE}
RUN sed -i "s/^workers = .*/workers = 1/" gunicorn_conf.py && sed -i "s/^gunicorn/exec gunicorn/" start.sh
CMD ["./start.sh"]
