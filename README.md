
```sh
# frontend/.env
VITE_API_URL=/api
```

```sh
cd frontend/

npm run build
# frontend/
# ├── dist/
# │   ├── index.html
# │   └── assets/


# verify 👇 (You should see /api somewhere in the generated JS.)
grep -R "/api" dist/assets
```

```sh
# make sure to set the `ALLOWED_HOSTS` accordingly.
docker compose up --build
```


```sh
docker compose exec api python manage.py createsuperuser
# docker compose run --rm api python manage.py createsuperuser

# 
docker compose logs -f api --tail=100

docker compose exec api python manage.py shell
# from django.contrib.auth import get_user_model
# User = get_user_model()
# User.objects.values("email")
```


## Fix
adding a image too large: 413 Request Entity Too Large