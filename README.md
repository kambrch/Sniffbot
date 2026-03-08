# Sniffbot
buforaot lelegramowy do serwowania pomiarów z węszącego sensora nad śmietnikami.

```
 _____         _   __   __ ______          _   
/  ___|       (_) / _| / _|| ___ \       | |  
\ `--.  _ __   _ | |_ | |_ | |_/ /  ___  | |_ 
 `--. \| '_ \ | ||  _||  _|| ___ \ / _ \ | __|
/\__/ /| | | || || |  | |  | |_/ /| (_) || |_ 
\____/ |_| |_||_||_|  |_|  \____/  \___/  \__|
                                              
```                                              


## Architektura

### Przepływ danych

```
 ┌────────────────┐                         ┌───────────────┐
 │    Tasmota     │                         │   Telegram    │
 │ BME280+PMS5003 │                         │     user      │
 └───────┬────────┘                         └──────┬────────┘
         │ MQTT publish                   /command │   ▲ 
         ▼                                         ▼   │ reply
 ┌────────────────┐                         ┌────────────────┐
 │    mqtt.jl     │                         │  telegram.jl   │
 │                │                         │                │
 └───────┬────────┘                         └───────┬────────┘
         │ write        ┌────────────┐         read │
         └────────────► │  cache.jl  │ ◄────────────┘
                        │    Ref     │
                        └────────────┘

 @async (mqtt.jl) — scheduler Julli zarządza odpytywaniem API telegrama i nasłuchiwaniem MQTT
 logging.jl — przekrojowe (wszystkie warstwy)
```

### Granice modułów

```
 ┌─────────────────────────────────────────────────────────────┐
 │ module Sniffbot                                             │
 │                                                             │
 │  cache.jl — shared state                                    │
 │  ├── CACHE       :: Ref{Union{Nothing,SensorReading}}       │
 │  ├── MQTT_STATE  :: Ref{Symbol}                             │
 │  └── START_TIME  :: Ref{DateTime}                           │
 │                                                             │
 │  logging.jl                                                 │
 │  └── setup_logging()                                        │
 │                                                             │
 │  ┌──────────────────┐   ┌─────────────────────────────────┐ │
 │  │ module MQTTLayer │   │ module TelegramLayer            │ │
 │  │                  │   │  ┌─────────────────────────┐    │ │
 │  │  start_mqtt()    │   │  │ formatting.jl (included) │   │ │
 │  │                  │   │  │ format_*, with_cache,    │   │ │
 │  │  imports:        │   │  │ HELP_TEXT                │   │ │
 │  │  CACHE           │   │  └─────────────────────────┘    │ │
 │  │  MQTT_STATE      │   │                                 │ │
 │  │  SensorReading   │   │  start_telegram()               │ │
 │  └──────────────────┘   │                                 │ │
 │                         │  imports: CACHE, MQTT_STATE,    │ │
 │                         │  START_TIME, SensorReading,     │ │
 │                         │  BME280Data,                    │ │
 │                         │  PMS5003Data                    │ │
 │                         └─────────────────────────────────┘ │
 └─────────────────────────────────────────────────────────────┘
```

### Struktura projektu

```
 .
├──  assets
│   └──  slop_logo.png    -- tymczosowe logo z AI slopu
├──  logs
├── 󰣞 src
│   ├──  cache.jl         -- przechowywanie ostatniego odebranego stanu
│   ├──  logging.jl       -- logowanie (revolting logs)
│   ├──  mqtt.jl          -- warstwa integracji z MQTT
│   ├──  formatting.jl    -- formatowanie wyjścia bota
│   ├──  telegram.jl      -- obsługa komend i pętla bota
│   └──  Sniffbot.jl      -- główny plik modułu
├──  .env                 -- plik z sekretami (patrz: .env_template)
```````

## Format danych z urządzenia

```
tele/tasmota_F847F7/SENSOR = {"Time":"2026-03-07T12:54:34","BME280":{"Temperature":20.7,"Humidity":24.4,"DewPoint":-0.4,"Pressure":1013.4},"PMS5003":{"CF1":22,"CF2.5":32,"CF10":49,"PM1":22,"PM2.5":32,"PM10":49,"PB0.3":4146,"PB0.5":934,"PB1":153,"PB2.5":48,"PB5":8,"PB10":2},"PressureUnit":"hPa","TempUnit":"C"}
```

## Komendy bota

Bot subskrybuje temat MQTT i buforuje ostatni odczyt. Komendy odczytują dane z bufora.

### Przegląd

- **/env** — Parametry środowiskowe (temp, wilgotność, punkt rosy, ciśnienie)
- **/pm** — Pyły zawieszone (PM1, PM2.5, PM10)
- **/all** — Wszystkie pomiary naraz

### Pojedyncze czujniki

- **/temperature** — Temperatura powietrza
- **/humidity** — Wilgotność względna
- **/dew_point** — Temperatura punktu rosy
- **/pressure** — Ciśnienie atmosferyczne
- **/pm1** — Pyły PM1
- **/pm25** — Pyły PM2.5
- **/pm10** — Pyły PM10

### System

- **/status** — Stan MQTT, ostatni odczyt, czas pracy
- **/help** — Wyświetla pomoc

## Konfiguracja

**Wymagania:** Julia ≥ 1.9

Zainstaluj zależności:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

Utwórz plik `.env` na podstawie szablonu i uzupełnij sekrety:

```bash
cp .env_template .env
$EDITOR .env
```

Wymagane zmienne: `MQTT_USERNAME`, `MQTT_PASSWORD`, `MQTT_TOPIC`, `TELEGRAM_TOKEN`, `TELEGRAM_ALLOWED_IDS`.
`TELEGRAM_ALLOWED_IDS` musi zawierać co najmniej jeden identyfikator czatu — pusta wartość blokuje wszystkich użytkowników.

## Uruchomienie

### Standardowe

```bash
julia -e 'using Sniffbot; Sniffbot.run()'
```

### Z sysimage (eliminuje opóźnienie przy pierwszym zapytaniu)

Jednorazowe zbudowanie obrazu (kilka minut):

```bash
julia --project=build build/build_sysimage.jl
```

Uruchomienie z obrazem:

```bash
julia --sysimage sniffbot.so -e 'using Sniffbot; Sniffbot.run()'
```

Obraz wymaga przebudowania po każdej zmianie kodu źródłowego.

## Wdrożenie (unattended)

Gotowe pliki serwisów w katalogu `deploy/`:

### Linux (systemd)

```bash
sudo cp deploy/sniffbot.service /etc/systemd/system/
# Edytuj WorkingDirectory i ExecStart w pliku
sudo systemctl daemon-reload
sudo systemctl enable --now sniffbot
```

### macOS (launchd)

```bash
cp deploy/com.sniffbot.plist ~/Library/LaunchAgents/
# Edytuj WorkingDirectory i ProgramArguments w pliku
launchctl load ~/Library/LaunchAgents/com.sniffbot.plist
```

Oba warianty automatycznie restartują proces po awarii i uruchamiają go przy starcie systemu.

## Pomysły na przyszłość 
- Utrzymywanie historycznych wyników w lekkiej bazie danych 
- Odpytywanie tych danych
- Rysowanie wykresów z tych danych
