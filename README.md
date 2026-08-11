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
| **Post-cycle summary notification** | Sends a per-zone summary (moisture, duration, skip reason) after every cycle, and notifies immediately on rain-skip |
| **Hot day evening check** | On hot days, a second moisture check runs at a configurable evening time (default 8 PM) using the stored morning forecast classification; zones whose soil is still below the skip threshold water briefly |
| **Reduced water consumption mode** | Toggle an `input_boolean` from any HA dashboard; food zones water at a configurable percentage of normal duration 2.5 hours before sunrise; non-food zones are skipped entirely |

---

## Installation

### Option A — One-click import

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint pre-filled.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fgithub.com%2Fwilman-labs%2FSmart-Garden-watering-system%2Fblob%2Fmain%2Fblueprints%2Fautomation%2Fsmart_garden_watering.yaml)

### Option B — Manual

1. Copy `blueprints/automation/smart_garden_watering.yaml` into your Home Assistant config directory at:
   ```
   config/blueprints/automation/wilman-labs/smart_garden_watering.yaml
   ```
2. Reload blueprints: **Settings → Automations & Scenes → Blueprints → Reload**.

---

## Pre-requisites

1. **Weather integration** — any integration that provides daily forecasts works
   (OpenWeatherMap, Met.no, AccuWeather, etc.).

2. **`input_datetime` helpers** — one per zone for interval tracking.
   Create them at **Settings → Helpers → Add Helper → Date and/or time → Date and time**.
   You will select them in the blueprint UI under each zone's *"Last Watered Tracker"* field.  
   Leaving this field empty treats the zone as never watered (always due).

3. **Valve entities** — `switch`, `valve`, or `input_boolean` entities that control each water valve.

4. **Morning forecast cache helper** *(optional but recommended for evening checks)* —
   an `input_text` helper used to persist the morning forecast classification so
   the evening hot-day cycle can use the morning weather report instead of
   re-checking temperatures later in the day. When not configured, the blueprint
   falls back to the live evening forecast.

5. **Soil moisture sensors** *(optional)* — any `sensor` entity reporting moisture as a percentage (0–100%).

6. **Reduced water consumption mode switch** *(optional)* — an `input_boolean` helper that acts as the GUI toggle for reduced-mode. See [Reduced Water Consumption Mode](#reduced-water-consumption-mode) below.

---

## Configuration

All settings are configured through the Home Assistant UI when you create an automation from this blueprint.

### General Settings

| Input | Default | Description |
|---|---|---|
| Offset After Sunrise | 00:30:00 | Delay after sunrise before the cycle starts |
| Weather Entity | — | Weather entity for forecast data |
| Rain Skip Threshold | 3 mm | Skip all watering if forecast rain ≥ this value |
| Cool Day Max Temp | 15 °C | High temp below this → use Cool durations |
| Hot Day Min Temp | 28 °C | High temp at/above this → use Hot durations |
| Hot Day Evening Check Time | 20:00:00 | Time to run the evening moisture check on hot days |
| Morning Forecast Cache Helper | *(empty)* | Optional `input_text` helper that stores the morning forecast classification for the evening cycle; when unset, the blueprint falls back to the live evening forecast |
| Watering Interval | 2 days | Days between watering runs |
| Notification Service | *(empty)* | Optional notify service (e.g. `notify.mobile_app_my_phone`). If set, cycle-complete and rain-skip summaries are also sent via this service in addition to a persistent notification |
| **Reduced Water Consumption Mode Switch** | *(empty)* | Optional `input_boolean` helper. When this is ON, reduced mode is active (see below) |
| **Reduced Mode — Food Zone Duration (%)** | 50% | Percentage of normal duration used for food zones in reduced mode (10–100%) |

### Per-Zone Settings (repeated for Zones 1–4)

| Input | Default | Description |
|---|---|---|
| Enable | true (Z1) / false (Z2–4) | Enable or disable the zone |
| Valve | — | Valve/switch entity for this zone |
| Last Watered Tracker | *(empty)* | `input_datetime` helper to track last run |
| Soil Moisture Sensor | *(empty)* | Optional moisture sensor |
| Skip if Moisture Above | 70% | Skip zone if soil is already wet |
| Force Water if Moisture Below | 30% | Water immediately if soil is too dry |
| Cool Day Duration | 5 min | Valve open time on a cool day |
| Warm Day Duration | 10 min | Valve open time on a warm day |
| Hot Day Duration | 15 min | Valve open time on a hot day |
| Hot Day Evening Duration | 8 min | Valve open time for the evening hot-day check (default ≈ half of hot morning duration) |
| Water if No Sensor (evening) | true | Water in the evening even when no moisture sensor is fitted or the sensor is not responding |
| **Food Zone** | false | Mark this zone as a food-producing area (vegetable bed, herb garden, etc.). Used by reduced water consumption mode |

---

## Reduced Water Consumption Mode

### What it does

When the mode switch is turned **ON**:

| Zone type | Behaviour |
|---|---|
| **Food zone** (checkbox ticked) | Watered at **`Food Zone Duration %`** of its normal cool/warm/hot duration (minimum 1 minute) |
| **Non-food zone** | Skipped entirely |

Additional effects while the mode is active:
- The watering cycle fires **2.5 hours before sunrise** instead of at the normal sunrise offset.
- The **evening hot-day check is disabled**.
- The normal sunrise-offset cycle is **suppressed** so zones are not watered twice.
- All notifications carry a 🌿 header and show the percentage applied.

### Step 1 — Create the helper

1. Go to **Settings → Devices & Services → Helpers → + Create Helper**.
2. Choose **Toggle** (i.e. `input_boolean`).
3. Name it, e.g. **"Garden Reduced Water Mode"** — Home Assistant will create the entity `input_boolean.garden_reduced_water_mode`.

### Step 2 — Link the helper to the blueprint

Open your automation (or create a new one from the blueprint) and, under **General Settings**, set **"Reduced Water Consumption Mode Switch"** to the helper you just created.

Also tick the **"Food Zone"** checkbox for every zone that grows edible plants. Optionally adjust **"Reduced Mode — Food Zone Duration (%)"** (default 50%).

### Step 3 — Add a toggle to your dashboard

#### Option A — Lovelace card (recommended)

Add an **Entity** card (or a **Button** card) pointing at your helper:

```yaml
type: entity
entity: input_boolean.garden_reduced_water_mode
name: Reduced Water Mode
icon: mdi:water-minus
```

Tap the card to toggle the mode on or off instantly.

#### Option B — via the Helper UI

Go to **Settings → Devices & Services → Helpers**, find the helper, and toggle it with the switch shown on the right.

#### Option C — via voice assistant

If you use Google Home, Alexa, or Siri Shortcuts, expose the `input_boolean` through your chosen integration and simply say *"Turn on garden reduced water mode"*.

---

## Water Usage Tracking *(Optional Add-On)*

### Overview

The water tracking system provides a general impression of water consumption across all four irrigation zones. It automatically accounts for **parallel zone operation** — when multiple valves open simultaneously, per-zone flow is reduced due to pressure drop in the shared 15 mm supply.

Tracking works for **automated blueprint cycles** and can optionally include **manual valve use**.

### What You Get

The repository includes:

| File | Purpose |
|---|---|
| `configuration/water_tracking.yaml` | `input_number` helpers and template sensors used by the blueprint tracking inputs, plus Riemann Sum integral sensors for cumulative totals |
| `automations/manual_watering_log.yaml` | Optional: four automations (one per zone) that log litres when a valve is closed manually, outside of the blueprint automation |
| `configuration/lovelace_water_card.yaml` | Ready-to-paste Lovelace card showing flow rates, 7-day history graph, and running totals |

### How to Enable Water Tracking (Blueprint UI)

1. Install and include `configuration/water_tracking.yaml` (steps below), then reload Home Assistant.
2. Open your automation created from this blueprint.
3. Expand **Water Usage Tracking (optional)**.
4. For each zone, link the three helper inputs from `water_tracking.yaml`:
   - **Flow Rate Helper** → `input_number.zone_X_flow_rate`
   - **Last Litres Helper** → `input_number.zone_X_last_litres`
   - **Total Litres Helper** → `input_number.zone_X_total_litres`
5. Save the automation.

When linked, the blueprint writes litres after each zone closes using:
`duration_minutes × zone_flow_rate × sensor.flow_multiplier`.

Tracking requires the **Flow Rate Helper** and **Last Litres Helper** for a zone. If either is empty, blueprint tracking is skipped for that zone; the **Total Litres Helper** is optional and only controls cumulative updates.

### Quick Start — Manual Installation

These three files are in the GitHub repository, but Home Assistant only reads files from **your own HA config directory**. You must download them and place them there manually.

#### Step 1: Download the files from GitHub

Click each link below, then click **Raw**, and save the file to your computer:
- [`configuration/water_tracking.yaml`](https://github.com/wilman-labs/Smart-Garden-watering-system/blob/main/configuration/water_tracking.yaml)
- [`automations/manual_watering_log.yaml`](https://github.com/wilman-labs/Smart-Garden-watering-system/blob/main/automations/manual_watering_log.yaml)
- [`configuration/lovelace_water_card.yaml`](https://github.com/wilman-labs/Smart-Garden-watering-system/blob/main/configuration/lovelace_water_card.yaml)

#### Step 2: Place files in your HA config directory

Copy the downloaded files into your Home Assistant config directory (the folder that contains `configuration.yaml`):

```
homeassistant/                              (your HA config directory)
├── configuration/
│   ├── water_tracking.yaml                 ← Paste here
│   └── lovelace_water_card.yaml            ← Paste here
├── automations/
│   └── manual_watering_log.yaml            ← Paste here
├── automations.yaml
├── configuration.yaml
└── blueprints/
```

If the `configuration/` or `automations/` directories don't exist, create them.

#### Step 3: Replace placeholder valve entity IDs

Open both files and replace all occurrences of `switch.zone_X_valve` with your **actual valve/switch entity IDs**.

**In `configuration/water_tracking.yaml`** (lines 146–150, 169+, 182+, 195+, 208+):
```yaml
# Change from:
is_state('switch.zone_1_valve', 'on')

# To your actual valve entity (example):
is_state('switch.my_garden_zone_1', 'on')
```

**In `automations/manual_watering_log.yaml`** (lines 44, 86, 128, 170):
```yaml
# Change from:
entity_id: switch.zone_1_valve

# To your actual valve entity:
entity_id: switch.my_garden_zone_1
```

#### Step 4: (Optional) Update the automation entity ID for manual logging

Only required if you want manual valve usage included.
In `automations/manual_watering_log.yaml`, find `automation.smart_garden_watering` (lines 52, 93, 134, 175) and replace with your **actual blueprint automation entity ID**.

Find it in HA:
1. Go to **Settings → Automations & Scenes → Automations**
2. Click your watering automation
3. Note the entity ID from the URL or info icon (e.g., `automation.garden_watering_system`)

#### Step 5: Add to configuration.yaml

Edit your `homeassistant/configuration.yaml` and add:

```yaml
homeassistant:
  packages:
    water_tracking: !include configuration/water_tracking.yaml

automation: !include automations/manual_watering_log.yaml
```

`automation: !include automations/manual_watering_log.yaml` is optional (manual tracking only).

> **If you already have an `automation:` line**, merge it instead of replacing it. For example, if you have `automation: !include_dir_merge_list automations/`, place `manual_watering_log.yaml` in the `automations/` directory and it will be picked up automatically.

#### Step 6: Reload Home Assistant

Go to **Settings → Developer Tools → YAML → Reload All YAML** (or restart HA completely).

✅ **Done!** Helper/sensor entities are active; then link them in the blueprint UI section above.

### Flow Reduction Model

When multiple zones run simultaneously, pressure drop in the shared 15 mm supply reduces per-zone flow. A simple lookup-table multiplier is applied automatically:

| Zones Active | Per-Zone Multiplier | Per-Zone Flow |
|---|---|---|
| 1 | 1.00 | ~5.0 L/min |
| 2 | 0.84 | ~4.2 L/min |
| 3 | 0.70 | ~3.5 L/min |
| 4 | 0.62 | ~3.1 L/min |

The `sensor.flow_multiplier` template sensor reads the active zone count and applies the correct coefficient automatically. All per-zone flow sensors inherit this multiplier, so Riemann Sum integrals accumulate the right volume whether one or all four zones are running.

### Energy Dashboard Integration

The Riemann Sum sensors (`sensor.zone_1_water_total_litres` through `sensor.zone_4_water_total_litres`) can be added to the HA **Energy dashboard** under the **Water** section for historical graphing and statistics. They accumulate automatically for both automated and manual valve use.

### Dashboard Card

Paste the contents of `configuration/lovelace_water_card.yaml` into a **Manual card** on any Lovelace dashboard (**Edit → + Add Card → Manual**). It shows:
- Live current flow per zone (accounting for parallel pressure reduction)
- 7-day history graph of per-run litres
- Running total litres per zone

---

## Logic Flow

```
Sunrise − 2:30:00  ← reduced_morning trigger (fires daily; stops unless mode switch is ON)
       │
       ▼
  Reduced water mode ON?  ──NO──▶  STOP (normal cycle handles today)
       │ YES
       ▼
  Fetch daily forecast
       │
       ▼
  Precipitation ≥ rain threshold?  ──YES──▶  STOP (skip + notify)
       │ NO
       ▼
  ┌────┴──────────────────────────┐
  │  For each zone:               │
  │                               │
  │  Zone enabled?                │
  │  Valve selected?              │
  │  Is food zone? ──NO──▶ skip   │
  │       │ YES                   │
  │  Interval due?                │
  │  OR moisture below threshold? │
  │  Moisture ABOVE skip?──YES──▶ │
  │       │ NO                    │
  │  Open valve                   │
  │  Wait (base_dur × food_pct %) │
  │  Close valve                  │
  │  Update tracker               │
  └───────────────────────────────┘
       │
       ▼
  Send 🌿 Reduced Mode summary notification

═══ Normal morning cycle (suppressed when reduced mode is ON) ═══

Sunrise + offset
       │
       ▼
  Reduced water mode ON?  ──YES──▶  STOP
       │ NO
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
       │
       ▼
  Send morning summary notification

═══ Evening hot-day check (disabled when reduced mode is ON) ═══

Evening check time (default 20:00)
       │
       ▼
  Reduced water mode ON?  ──YES──▶  STOP
       │ NO
       ▼
  Read stored morning forecast
       │
       ├── unavailable or not configured? ──▶ Fetch live evening forecast
       │
       ▼
  Hot day?  ──NO──▶  STOP (no evening watering)
       │ YES
       ▼
  Forecast precipitation ≥ rain threshold?  ──YES──▶  STOP
       │ NO
       ▼
  ┌────┴──────────────┐
  │  For each zone:   │
  │                   │
  │  Zone enabled?    │
  │  Valve selected?  │
  │       │           │
  │  Sensor reading?  │
  │  ├─ YES: moisture │
  │  │  above skip    │
  │  │  threshold?    │
  │  │  ──YES──▶ skip │
  │  │  │ NO          │
  │  │  Open valve    │
  │  └─ NO:           │
  │     "Water if no  │
  │     sensor"       │
  │     enabled?      │
  │     ──NO──▶ skip  │
  │     │ YES         │
  │     Open valve    │
  │  Wait (evening    │
  │  duration)        │
  │  Close valve      │
  └───────────────────┘
       │
       ▼
  Send evening summary notification
```

---

## Minimum Home Assistant Version

**2024.6.0** — required for collapsible input sections in the blueprint UI and
for the `weather.get_forecasts` service (introduced in 2023.9).
