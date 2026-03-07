# Sniffbot
Bot lelegramowy do serwowania pomiarów z węszącego sensora nad śmietnikami.

  _________      .__  _____  _______________        __
 /   _____/ ____ |__|/ ____\/ ____\______   \ _____/  |_
 \_____  \ /    \|  \   __\\   __\ |    |  _//  _ \   __\
 /        \   |  \  ||  |   |  |   |    |   (  <_> )  |
/_______  /___|  /__||__|   |__|   |______  /\____/|__|
        \/     \/                         \/


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
 │  ├── START_TIME  :: Ref{DateTime}                           │
 │  └── LOG_DIR     :: String                                  │
 │                                                             │
 │  logging.jl                                                 │
 │  └── setup_logging()                                        │
 │                                                             │
 │  ┌──────────────────┐   ┌─────────────────────────────────┐ │
 │  │ module MQTTLayer │   │ module TelegramLayer            │ │
 │  │                  │   │  ┌─────────────────────────┐    │ │
 │  │  start_mqtt()    │   │  │ formatting.jl (included) │   │ │
 │  │                  │   │  │ format_*, with_cache,    │   │ │
 │  │  imports:        │   │  │ read_logs, HELP_TEXT     │   │ │
 │  │  CACHE           │   │  └─────────────────────────┘    │ │
 │  │  MQTT_STATE      │   │                                 │ │
 │  │  SensorReading   │   │  start_telegram()               │ │
 │  └──────────────────┘   │                                 │ │
 │                         │  imports: CACHE, MQTT_STATE,    │ │
 │                         │  START_TIME, LOG_DIR,           │ │
 │                         │  SensorReading, BME280Data,     │ │
 │                         │  PMS5003Data                    │ │
 │                         └─────────────────────────────────┘ │
 └─────────────────────────────────────────────────────────────┘
```

### Struktura projektu

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
- **/logs [N]** — Ostatnie N ostrzeżeń/błędów (domyślnie 20)
- **/help** — Wyświetla pomoc

## Pomysły na przyszłość 
- Utrzymywanie historycznych wyników w lekkiej bazie danych 
- Odpytywanie tych danych
- Rysowanie wykresów z tych danych
