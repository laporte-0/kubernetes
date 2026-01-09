FROM python:3.12-alpine

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY app_nodb.py .

EXPOSE 5000

ENV APP_MODULE=app

CMD ["sh", "-c", "flask --app ${APP_MODULE} run --host=0.0.0.0 --port=5000"]
