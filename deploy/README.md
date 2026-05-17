
```sh

docker compose pull

docker compose run --rm --entrypoint sh tf

# once inside the container:
cd deploy
terraform init
```

NOTE:
don't forget to add `.terraform` to `.gitignore`
`.terraform/` → cache + downloaded providers/modules

