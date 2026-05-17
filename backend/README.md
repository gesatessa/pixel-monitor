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
export PAYLOAD='{
  "email": "angel@hotmil.io",
  "password": "Texas429"
}'

curl -X 'POST' \
  'http://localhost:8000/api/user/token/' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "email": "kimi@info.me",
  "password": "Kanada71"
}'

curl -X 'POST' \
  'http://localhost:8000/api/user/token/' \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD"

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


## Movie API

Create the app:
```sh
docker compose run --rm api python manage.py startapp movie

# add 'movie' to INSTALLED_APPS

# after adding the model, make migrations:
docker compose run --rm api python manage.py makemigrations core
```

```sh
curl 'http://localhost:8000/api/movies/' \
  -H 'accept: application/json'


curl -X 'POST' \
  'http://localhost:8000/api/movies/' \
  -H "Authorization: Token $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Whiplash",
    "description": "intense music drama",
    "release_year": 2014
  }'

```

Routers automatically generate URL patterns for ViewSets and custom @action routes.

```sh
curl http://localhost:8000/api/movies/3/ | jq

# like a movie
curl -X POST http://localhost:8000/api/movies/1/like/ \
  -H "Authorization: Token $TOKEN"

# post a review
curl -X POST http://localhost:8000/api/movies/1/review/ \
  -H "Authorization: Token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rating": 5,
    "comment": "Great movie."
  }'
```

### Poster
Image uploads require multipart/form-data.

```sh
# @ => upload this file
curl -X POST \
  http://localhost:8000/api/movies/ \
  -H "Authorization: Token $ADMIN_TOKEN" \
  -F "title=Whiplash" \
  -F "description=Jazz drummer pushed to the edge" \
  -F "release_year=2014" \
  -F "poster=@./posters/whiplash.png"

# # you may need to run
# sudo chown -R 1000:1000 media
# chown -R 1000:1000 /code/media

curl -X POST \
  http://localhost:8000/api/movies/ \
  -H "Authorization: Token $ADMIN_TOKEN" \
  -F "title=Marriage Story" \
  -F "description=An emotional drama that follows a couple navigating love, separation, and the challenges of divorce." \
  -F "release_year=2019" \
  -F "poster=@./posters/mar_story.png"


curl http://localhost:8000/api/user/me/ \
  -H 'Authorization: Token $ADMIN_TOKEN'

curl -X 'POST' \
  'http://localhost:8000/api/movies/1/review/' \
  -H "Authorization: Token $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
  "rating": 4,
  "comment": "A gripping story about ambition, discipline, and obsession."
}'

curl -X 'POST' \
  'http://localhost:8000/api/movies/1/like/' \
  -H 'accept: */*' \
  -H "Authorization: Token $ADMIN_TOKEN" \
  -d ''

curl -X 'POST' \
  'http://localhost:8000/api/movies/2/review/' \
  -H "Authorization: Token $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
  "rating": 5,
  "comment": "Emotional, raw, and deeply human from start to finish."
}'

curl  'http://localhost:8000/api/movies/' | jq

```

## NeXT

We now have enough architecture to move into:
- pagination
- filtering
- search
- ordering
- JWT auth
- permissions per object
- nested routes
- tests
- async tasks
- production deployment

At this point our project stopped being CRUD practice and became a real API.


## cors

```sh
pip install django-cors-headers

```

```py
INSTALLED_APPS = [
    ...
    "corsheaders",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    ...
]

# allow frontend
CORS_ALLOWED_ORIGINS = [
    "http://localhost:5173",
]

```
Return absolute media URLs consistently.

Sometimes DRF returns relative paths depending on serializer context.

Update serializer:
```py
class MovieSerializer(serializers.ModelSerializer):
    poster = serializers.SerializerMethodField()

    class Meta:
        model = Movie
        fields = [...]

    def get_poster(self, obj):
        request = self.context.get('request')

        if obj.poster and request:
            return request.build_absolute_uri(obj.poster.url)

        return None
```


## Static & Media

`STATIC_ROOT` is where `python manage.py collectstatic` collects files before serving them. `WhiteNoise` serves from there.

We do NOT need `MEDIA_ROOT` anymore in production because uploads are going to S3.

Mental model:
- `Gunicorn` serves Django
- `WhiteNoise` serves static
- `S3` serves media


### Migration Step:
build image
    ->
run migration task
    ->
deploy service

```sh
aws ecs run-task ...
python manage.py migrate
```

### CI Pipeline
run tests
build docker image
collectstatic inside image
push image to ECR
