# Smart Garden Watering System

A [Home Assistant Blueprint](https://www.home-assistant.io/docs/blueprint/) for an automatic, weather-aware garden watering system with up to 4 independent zones.

---

## Features

| Feature | Detail |
|---|---|
| **Sunrise-based trigger** | Starts at a configurable offset after sunrise |
| **Rain skip** | Skips all watering when today's forecast precipitation ≥ a threshold |
| **Temperature-adaptive durations** | Cool / warm / hot day durations per zone |
| **Interval scheduling** | Waters every N days, tracked via `input_datetime` helpers |
| **Soil moisture integration** | Optional per-zone sensors to skip or force watering |
| **4 independent zones** | Each zone has its own valve, sensor, and settings |

---

## Installation

### Option A — One-click import

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint pre-filled.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fgithub.com%2Fwilman-labs%2FSmart-Garden-watering-system%2Fblob%2Fmain%2Fblueprints%2Fautomation%2Fsmart_garden_watering.yaml)

### Option B — Manual

1. Copy `blueprints/automation/smart_garden_watering.yaml` into your Home Assistant
   config directory at:
   ```
   config/blueprints/automation/wilman-labs/smart_garden_watering.yaml
   ```
2. Reload blueprints: **Settings → Automations & Scenes → Blueprints → Reload**.

---

## Pre-requisites

1. **Weather integration** — any integration that provides daily forecasts works
   (OpenWeatherMap, Met.no, AccuWeather, etc.).

2. **`input_datetime` helpers** — one per zone for interval tracking.
   Create them at **Settings → Helpers → Add Helper → Date and/or time → Date and
   time**. You will select them in the blueprint UI under each zone's
   *"Last Watered Tracker"* field.  
   Leaving this field empty treats the zone as never watered (always due).

3. **Valve entities** — `switch`, `valve`, or `input_boolean` entities that
   control each water valve.

4. **Soil moisture sensors** *(optional)* — any `sensor` entity reporting
   moisture as a percentage (0–100 %).

---

## Configuration

All settings are configured through the Home Assistant UI when you create an
automation from this blueprint.

### General Settings

| Input | Default | Description |
|---|---|---|
| Offset After Sunrise | 00:30:00 | Delay after sunrise before the cycle starts |
| Weather Entity | — | Weather entity for forecast data |
| Rain Skip Threshold | 3 mm | Skip all watering if forecast rain ≥ this value |
| Cool Day Max Temp | 15 °C | High temp below this → use Cool durations |
| Hot Day Min Temp | 28 °C | High temp at/above this → use Hot durations |
| Watering Interval | 2 days | Days between watering runs |

### Per-Zone Settings (repeated for Zones 1–4)

| Input | Default | Description |
|---|---|---|
| Enable | true (Z1) / false (Z2–4) | Enable or disable the zone |
| Valve | — | Valve/switch entity for this zone |
| Last Watered Tracker | *(empty)* | `input_datetime` helper to track last run |
| Soil Moisture Sensor | *(empty)* | Optional moisture sensor |
| Skip if Moisture Above | 70 % | Skip zone if soil is already wet |
| Force Water if Moisture Below | 30 % | Water immediately if soil is too dry |
| Cool Day Duration | 300 s | Valve open time on a cool day |
| Warm Day Duration | 600 s | Valve open time on a warm day |
| Hot Day Duration | 900 s | Valve open time on a hot day |

---

## Logic Flow

```
Sunrise + offset
       │
       ▼
  Fetch daily forecast
       │
       ▼
  Precipitation ≥ rain threshold?  ──YES──▶  STOP (skip all zones)
       │ NO
       ▼
  Classify day: cool / warm / hot
       │
  ┌────┴──────────────┐
  │  For each zone:   │
  │                   │
  │  Zone enabled?    │
  │  Valve selected?  │
  │       │           │
  │  Interval due?    │
  │  OR moisture      │
  │  below threshold? │
  │       │           │
  │  Moisture ABOVE   │
  │  skip threshold?  │──YES──▶ skip zone
  │       │ NO        │
  │  Open valve       │
  │  Wait (duration)  │
  │  Close valve      │
  │  Update tracker   │
  └───────────────────┘
```

---

## Minimum Home Assistant Version

**2024.6.0** — required for collapsible input sections in the blueprint UI and
for the `weather.get_forecasts` service (introduced in 2023.9).