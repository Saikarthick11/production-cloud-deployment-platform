# Start with Python on a small Debian Linux image.
FROM python:3.14-slim

# Avoid bytecode files and send Python output straight to container logs.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy dependencies first so code edits can reuse this installation layer.
COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

# Run the service as an ordinary user rather than root.
RUN useradd --create-home --uid 10001 appuser
COPY app/ ./app/
USER appuser

# Document the container port; docker run -p publishes it to the host.
EXPOSE 8000

# Listen on the container's network interface. No development auto-reload.
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
