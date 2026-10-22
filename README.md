# LibraTrack — Lesson 10 baseline

Створено через GitHub template із гілки `main` проєкту
[Lesson 10](https://github.com/energy6x6/Go-with-GenAI-lessons-10),
коміт `b75b1c0a89936a14851c896d1afe856d653bb754`.
Історія цього репозиторію починається з одного коміту.
Результати попередніх перевірок і звіти залишено поза репозиторієм.

Go-застосунок LibraTrack містить REST API, Swagger, вебкаталог із HTMX,
JWT, ролі користувачів, PostgreSQL та вбудовані SQL-міграції й вебресурси.
Код розташований у `cmd/`, `internal/`, `migrations/`, `web/` і `docs/`.

Для початкового локального запуску потрібні Go 1.27.2, Docker Compose та Python 3:

```bash
python3 scripts/setup_env.py
docker compose up -d --wait postgres
go run ./cmd/demo-users
go run ./cmd/api
```

Каталог: `http://localhost:8085/catalog`.
Конфігурація й секрети створюються локально в ігнорованому `.env`.
Подальші DevOps-зміни виконуються в `develop` і переносяться в `main`
через GitHub Pull Request.

## English

Generated from the Lesson 10 main branch with a fresh history. LibraTrack includes
an embedded web interface and SQL migrations, REST API, Swagger and authentication.
Run the commands above for the baseline application. DevOps integration is developed
on `develop` and merged into `main` through a GitHub pull request.
