# pixel-monitor

## config
```sh
docker compose build --no-cache api

docker compose run --rm api django-admin startproject config .

docker compose up api
```

## core

```sh
docker compose run --rm api python manage.py startapp core
# don't forget to add `core` in settings.py
```

### User
Add `UserManager` & `User` model in the core app. Run the migrations.
```sh
docker compose run --rm api python manage.py makemigrations core

docker compose run --rm api python manage.py createsuperuser

docker compose up --build

```

Alternatively you can create superuser like so:
```sh
# get a shell
docker compose exec api sh

python manage.py createsuperuser

```

Verify the DB
```sh
docker compose exec -it db psql -U $PG_USER -d $PG_DB

admindb=#
```

Now you can investigate
```sql
\dt

SELECT email, date_joined, is_staff FROM core_user;

```

## User API

```sh
docker compose run --rm api python manage.py startapp user
```

Now we can create/register a user. Also possible via the api doc `http://localhost:8000/api/docs/`
```sh
curl -X 'POST' \
  'http://localhost:8000/api/user/create/' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "email": "angel@hotmil.com",
  "password": "Texas429"
}'
```

### Auth

A user can login:
```sh
curl -X 'POST' \
  'http://localhost:8000/api/user/token/' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "email": "kimi@info.me",
  "password": "Kanada71"
}'

# {
#   "token": "b10d148ed1c6564237ae070569a1cffb27953716"
# }

TOKEN=b10d148ed1c6564237ae070569a1cffb27953716
curl -i http://localhost:8000/api/user/me/ \
  -H "Authorization: Token $TOKEN"

# update
curl -X 'PATCH' \
  'http://localhost:8000/api/user/me/' \
  -H "Authorization: Token $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
  "email": "kimi@info.me",
  "password": "Kanada92"
}'

```

📢 In shells:
'single quotes' → literal text
"double quotes" → variable expansion happens
