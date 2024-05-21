# Define the ARG before the FROM instruction
# ARG MODEL_NAME="falcon-7b-instruct"

FROM cgr.dev/chainguard/python:latest-dev as builder
ENV PATH="/app/venv/bin:$PATH"

WORKDIR /app

RUN python -m venv /app/venv
COPY requirements.txt .

RUN pip3 install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn

FROM cgr.dev/chainguard/python:latest

# ARG MODEL_NAME

WORKDIR /app

ENV PATH="/app/venv/bin:$PATH"

# Copy the model directory from your local file system to the container
# COPY ./models/${MODEL_NAME}/ /app/models/${MODEL_NAME}/
COPY ./instruct_pipeline.py model_config.py requirements.txt server.py .
COPY --from=builder /app/venv /app/venv

# Make port 6001 available to the world outside this container
EXPOSE 6001

# Run server.py when the container launches
#ENTRYPOINT ["python", "server.py"]

ENTRYPOINT ["gunicorn", "-w", "1", "--timeout", "900", "--bind", "0.0.0.0:6001", "server:app", "--threads", "100"]
