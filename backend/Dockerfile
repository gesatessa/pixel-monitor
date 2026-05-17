FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

ARG DEV=false

WORKDIR /code

COPY requirements.txt /code/
RUN pip install -U --no-cache-dir -r requirements.txt

COPY . /code/

EXPOSE 8000
# CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

# Collect static files (for production)
RUN python manage.py collectstatic --noinput

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
