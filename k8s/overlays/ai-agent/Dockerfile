FROM python:3.11-slim

WORKDIR /agent

COPY agent/*.py ./

RUN pip install --no-cache-dir requests boto3 kubernetes

RUN chmod +x autonomous_agent.py

CMD ["python", "autonomous_agent.py"]
