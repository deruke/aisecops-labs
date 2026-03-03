FROM python:3.11-slim

RUN pip install --no-cache-dir deepteam requests pyyaml

WORKDIR /app

COPY config.yaml /app/config.yaml
COPY requirements.txt /app/requirements.txt
COPY target_callback.py /app/target_callback.py

RUN mkdir -p /app/results

CMD ["bash"]
