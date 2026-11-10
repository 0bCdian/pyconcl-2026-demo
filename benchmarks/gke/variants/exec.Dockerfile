ARG BASE=bad
FROM ${BASE}
RUN sed -i "s/^gunicorn/exec gunicorn/" start.sh
CMD ["./start.sh"]
