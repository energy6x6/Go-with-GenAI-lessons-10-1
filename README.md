# Go with GenAI DevOps Basics

Навчальне середовище Ubuntu з Docker, локальним емулятором AWS Floci та K3s.
Власний застосунок LibraTrack працює разом із PostgreSQL через Docker Compose.
У K3s розгортається LibraTrack із власною PostgreSQL та окремий HTTP demo API
з двома репліками.

## Застосунок LibraTrack

Репозиторій створено через GitHub template із гілки `main` власного проєкту
[Lesson 10](https://github.com/energy6x6/Go-with-GenAI-lessons-10),
коміт `b75b1c0a89936a14851c896d1afe856d653bb754`.
Go-застосунок розташований у корені репозиторію: `cmd/`, `internal/`,
`migrations/`, `web/`. DevOps-зміни розробляються в `develop`
і потрапляють до `main` через GitHub Pull Request.
Застосунок має каталог книг, авторів і категорій, PostgreSQL, JWT,
ролі користувачів, Swagger та вебінтерфейс.
Міграції, HTML, CSS і JavaScript вбудовані у виконуваний файл Go.

Команди нижче виконуються в корені цього репозиторію всередині Ubuntu VM.
Потрібні Docker Engine з Compose plugin, Python 3 та Bash. Перевірене середовище:
Ubuntu Server 24.04, amd64, 4 vCPU, 6 GiB RAM.

```bash
bash scripts/start-library.sh
```

Сценарій створює `.env` з випадковими паролями та JWT secret, збирає образ,
запускає PostgreSQL і API, чекає статусу `healthy` та створює локальні
демоакаунти reader, librarian і admin. Повторний запуск зберігає наявний `.env`
та файл облікових даних. Дані PostgreSQL розміщуються у volume
`projectgo-library_pgdata`. База `libratrack_devops_test` призначена для тестів.

| Сторінка | Адреса |
| --- | --- |
| Каталог | http://127.0.0.1:8080/catalog |
| Вхід | http://127.0.0.1:8080/login |
| Swagger | http://127.0.0.1:8080/swagger/index.html |
| API каталогу | http://127.0.0.1:8080/api/v1/books |
| Стан HTTP сервера | http://127.0.0.1:8080/health |

Для доступу з хоста через VirtualBox NAT потрібно переспрямувати порт хоста
`127.0.0.1:8080` на порт `8080` гостя. PostgreSQL не публікує порт на хості.
Docker healthcheck читає каталог через API, перевіряючи також доступ до бази.

Облікові дані зберігаються локально в `../projectgo-artifacts/accounts/.demo-accounts.txt`
з правами `0600`. Каталог `projectgo-artifacts` розташований поряд із checkout.
Змінна `PROJECTGO_ARTIFACTS_DIR` дозволяє задати іншу зовнішню папку.
Секрети, результати перевірок, вимірювання, скриншоти та звіти не входять до Git.
`.env` виключено з Docker build context.
Застосунок працює від непривілейованого користувача, з файловою системою лише
для читання та окремою роллю PostgreSQL без `SUPERUSER`.

## Перевірка Compose

```bash
docker compose ps
bash scripts/verify-library-persistence.sh
bash scripts/test-library.sh
```

Перша перевірка читає каталог і Swagger, перевіряє відмову в записі без входу,
авторизується локальним admin та додає книгу через API. Потім перестворює
контейнери API й PostgreSQL, перевіряє збереження volume і читає ту саму книгу
через API та вебкаталог. Книга залишається у базі для демонстрації.
Стан перевірки записується в `../projectgo-artifacts/library-proof.json` без паролів і JWT.
Повторний запуск використовує вже додану книгу з цього файла.

Тести запускаються з race detector в окремій базі, кожен інтеграційний тест
використовує власну випадкову схему. Сценарій завершується помилкою за наявності
FAIL або SKIP, зберігає JSON поза checkout у `../projectgo-artifacts/library-tests.jsonl`
і запускає `go vet`.

GitHub Actions запускає ті самі сценарії для `develop`, `main` і Pull Request:
збірку образу, перевірку API та збереження даних, тести з PostgreSQL і `go vet`.
Тимчасові файли CI зберігаються поза checkout.

Для повторної перевірки без перестворення контейнерів:

```bash
python3 scripts/verify-library.py check
docker compose exec -T postgres psql -v ON_ERROR_STOP=1 \
  -U libratrack_bootstrap -d libratrack_devops < scripts/verify-library.sql
```

SQL показує версію міграцій, права ролей і додану демонстраційну книгу.
Для паузи зі збереженням даних використовується `docker compose stop`.
Зміна пароля в `.env` не змінює пароль уже ініціалізованого PostgreSQL volume.

## Локальні демо AWS

```bash
bash infra/provision/install-aws-tools.sh
docker compose -f compose.floci.yaml up -d --wait
bash scripts/demo-ec2.sh
bash scripts/build-lambda.sh
bash scripts/demo-lambda.sh
```

Floci запускає локальні EC2 та Lambda через Docker Engine гостя. Сценарії
використовують тестові AWS credentials та явний endpoint `127.0.0.1:4566`.
EC2 demo повторно використовує свій екземпляр; Lambda повертає привітання
для імені `ProjectGo` та для порожньої події. Результати зберігаються
поза checkout у `../projectgo-artifacts/ec2/` та `../projectgo-artifacts/lambda/`.

## LibraTrack у K3s

Спочатку запустити Compose через `bash scripts/start-library.sh`. Для наявного
K3s із local-path provisioner:

```bash
bash scripts/deploy-library-k3s.sh
bash scripts/verify-library-k3s-persistence.sh
```

Розгортання містить namespace `libratrack`, Deployment застосунку з однією
реплікою, StatefulSet PostgreSQL з PVC на 1 GiB та Service NodePort `30081`.
Секрети створюються під час запуску; приватна копія зберігається у зовнішній
папці `../projectgo-artifacts/k8s/`. У маніфестах немає паролів.

Під час першого запуску до порожньої бази `libratrack_k3s` відновлюється копія
бази Compose. Наступні запуски зберігають наявні дані K3s. Обидві бази працюють
незалежно, з окремими паролями й сховищами; облікові записи користувачів
LibraTrack переносяться разом із копією даних. Для повторного входу підходить
той самий локальний файл демоакаунтів.

Перевірка додає книгу через авторизований API, замінює PostgreSQL pod,
перезапускає API та повторно читає книгу, перевіряючи збереження того самого PVC.
Readiness probe API читає каталог із бази; liveness probe перевіряє HTTP сервер.
API і PostgreSQL працюють без root. Застосунок використовує одну репліку,
оскільки ключі CSRF у поточній версії зберігаються в пам’яті процесу.

Для доступу з хоста через VirtualBox NAT переспрямувати `127.0.0.1:30081`
на порт `30081` гостя. Каталог: `http://127.0.0.1:30081/catalog`.
У терміналі гостя використовується IPv4 адреса вузла:

```bash
bash scripts/verify-library-k3s.sh
./scripts/kubectl-lab.sh -n libratrack get pods,pvc
```

## HTTP demo у K3s

На новій Ubuntu VM встановити K3s, потім виконати deployment:

```bash
sudo bash infra/provision/install-k3s.sh "$USER"
bash scripts/deploy-k3s-demo.sh
bash scripts/verify-k3s.sh
```

Сценарій імпортує образ з Docker до окремого containerd K3s, застосовує
`k8s/demo-api.yaml`, чекає готовності двох реплік та перевіряє HTTP відповіді.
Service використовує NodePort `30080`. Через VirtualBox NAT порт хоста
`127.0.0.1:30080` переспрямовується на порт `30080` гостя.
Адреса з хоста: `http://127.0.0.1:30080/health`; всередині гостя слід
використовувати IPv4 адресу вузла. У K3s тут розгортається `demos/http/`;
LibraTrack із PostgreSQL має окремі маніфести у `k8s/library/`.

## Встановлення Docker на новій VM

Для чистої Ubuntu 24.04 без Docker:

```bash
sudo bash infra/provision/install-docker.sh "$USER"
```

Після встановлення потрібно повторно увійти в сесію для застосування групи
`docker`. Перевірка Engine та Compose:

```bash
docker --version
docker compose version
docker compose -f compose.smoke.yaml run --rm hello
```

## English overview

This repository runs the LibraTrack Go application and PostgreSQL with Docker
Compose inside an Ubuntu VM. Run `bash scripts/start-library.sh` from the
repository root, then open `http://127.0.0.1:8080/catalog`. With VirtualBox NAT,
forward host loopback port 8080 to guest port 8080.

`bash scripts/verify-library-persistence.sh` creates a book through the
authenticated API, recreates both containers while keeping the PostgreSQL
volume, and verifies the same book through the API and catalog.
`bash scripts/test-library.sh` runs tests with the race detector against a
separate PostgreSQL database and runs `go vet`.

Local passwords are generated once and excluded from Git and Docker build
context. Demo credentials and verification output are stored outside the checkout
in `../projectgo-artifacts/`. Reports, screenshots and measured results stay
outside Git.

`bash scripts/deploy-library-k3s.sh` deploys LibraTrack and PostgreSQL with a
persistent volume in K3s. The initial database is copied from Compose; later
deployments preserve Kubernetes data. Forward host loopback port 30081 to
guest port 30081 and open `http://127.0.0.1:30081/catalog`.
`bash scripts/verify-library-k3s-persistence.sh` checks persistence after
replacing the PostgreSQL pod and restarting the API.

The repository also includes local Floci EC2 and Lambda demos and a separate
two-replica HTTP demo for K3s. See the commands above for each workflow.
