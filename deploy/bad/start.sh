#!/bin/sh
echo "Starting shop..."
gunicorn -c gunicorn_conf.py app:app
