FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /code

COPY requirements.txt /code/
RUN pip install -U --no-cache-dir -r requirements.txt

COPY . /code/

EXPOSE 8000
# CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
