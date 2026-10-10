# Дневник смен водителя

Мини-проект: сервер (FastAPI + SQLite) отдаёт поездки и сводку за день, клиент на Flutter показывает их по дням. Поездку можно добавить, повторная отправка той же поездки не создаёт дубль.

> README будет дописан на этапе 5: клиент, скриншоты, допущения, чек-лист.

## Backend

Нужен Python 3.11+.

```bash
cd backend
python -m venv .venv
# Windows (PowerShell): .venv\Scripts\Activate.ps1
# macOS / Linux:        source .venv/bin/activate
pip install -r requirements.txt
pytest                         # тесты
uvicorn app.main:app --reload  # сервер на http://localhost:8000, Swagger: /docs
```

При старте сервер создаёт `backend/trips.db` и загружает в неё `data/trips.json`. Повторный запуск дублей не создаёт. Пути можно поменять через переменные окружения `TRIPS_DB_PATH` и `TRIPS_SEED_PATH`.

## API

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/api/days` | даты, за которые есть поездки |
| GET | `/api/trips?date=YYYY-MM-DD` | поездки за день, по времени начала |
| GET | `/api/summary?date=YYYY-MM-DD` | сводка за день |
| POST | `/api/trips` | 201 — создана, 200 — такая уже есть, 409 — id занят другими данными, 422 — ошибка данных |
| GET | `/health` | `{"status": "ok"}` |

### Примеры curl

Команды для bash (macOS / Linux / Git Bash). Вывод ниже — реальный, сервер запущен на свежей БД.

Дни с поездками:

```bash
curl -s http://localhost:8000/api/days
```
```json
["2026-10-01","2026-10-02","2026-10-03","2026-10-04"]
```

Сводка за день:

```bash
curl -s "http://localhost:8000/api/summary?date=2026-10-01"
```
```json
{"date":"2026-10-01","trips_count":8,"revenue":25600,"commission":3840,"net":21760,"cash":{"amount":14900,"count":5},"card":{"amount":10700,"count":3}}
```

Поездки за день (`t18` — поездка через полночь 02.10 23:40 → 03.10 00:15, она попадает в 02.10):

```bash
curl -s "http://localhost:8000/api/trips?date=2026-10-02"
```
```json
[{"id":"t9","start":"2026-10-02T08:10:00+05:00","end":"2026-10-02T08:28:00+05:00","amount":1700,"payment":"cash","commission":255,"day":"2026-10-02"},
 ...,
 {"id":"t18","start":"2026-10-02T23:40:00+05:00","end":"2026-10-03T00:15:00+05:00","amount":4200,"payment":"card","commission":630,"day":"2026-10-02"}]
```

Добавить поездку → **201**:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://localhost:8000/api/trips \
  -H "Content-Type: application/json" \
  -d '{"id":"demo-1","start":"2026-10-05T08:10:00+05:00","end":"2026-10-05T08:32:00+05:00","amount":2400,"payment":"card","commission":360}'
```
```
{"id":"demo-1","start":"2026-10-05T08:10:00+05:00","end":"2026-10-05T08:32:00+05:00","amount":2400,"payment":"card","commission":360,"day":"2026-10-05"}
HTTP 201
```

Та же команда ещё раз → **200**, дубль не создан. Тот же момент, записанный в UTC (`"start":"2026-10-05T03:10:00Z","end":"2026-10-05T03:32:00Z"`), — тоже **200**: это та же поездка.

Тот же id, другие данные → **409**:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://localhost:8000/api/trips \
  -H "Content-Type: application/json" \
  -d '{"id":"demo-1","start":"2026-10-05T08:10:00+05:00","end":"2026-10-05T08:32:00+05:00","amount":3000,"payment":"card","commission":450}'
```
```
{"detail":"Trip with id 'demo-1' already exists with different data"}
HTTP 409
```

Ошибка данных → **422** (здесь окончание раньше начала):

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://localhost:8000/api/trips \
  -H "Content-Type: application/json" \
  -d '{"id":"demo-2","start":"2026-10-05T08:10:00+05:00","end":"2026-10-05T08:00:00+05:00","amount":2400,"payment":"card","commission":360}'
```
```
{"detail":[{"type":"end_not_after_start","loc":["body","end"],"msg":"end must be later than start","input":"2026-10-05T08:00:00+05:00"}]}
HTTP 422
```

Все проверки 422 (поле из `loc` → текст `msg`):

| Что отправили | `loc` | `msg` |
|---|---|---|
| `amount: 0` или `-100` | `amount` | Input should be greater than 0 |
| `amount: "2400"` или `2400.5` | `amount` | Input should be a valid integer |
| `end` равен `start` или раньше | `end` | end must be later than start |
| `commission` больше `amount` | `commission` | commission must not exceed amount |
| `commission: -1` | `commission` | Input should be greater than or equal to 0 |
| `payment: "crypto"` | `payment` | Input should be 'cash' or 'card' |
| `id: "   "` | `id` | String should have at least 1 character |
| `id` длиннее 64 символов | `id` | String should have at most 64 characters |
| время без оффсета `2026-10-05T08:10:00` | `start` / `end` | Input should have timezone info |
| лишнее поле `note` | `note` | Extra inputs are not permitted |
| нет поля `payment` | `payment` | Field required |
| `GET /api/summary?date=2026-13-01` | `date` | Input should be a valid date or datetime, month value is outside expected range of 1-12 |

**Windows PowerShell:** вместо `curl` пишите `curl.exe`. JSON удобнее передавать из файла: `curl.exe -X POST http://localhost:8000/api/trips -H "Content-Type: application/json" -d "@trip.json"`.
