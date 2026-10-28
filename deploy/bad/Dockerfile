FROM python:3.13
WORKDIR /app
COPY app/ deploy/bad/ ./
RUN pip install -r requirements.txt
CMD ./start.sh
