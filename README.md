# Дача Михалыча (приватно)

3D-игра на Godot 4.6 (Android): дровосек/выживание, город в духе GTA, три героя на карте (Михалыч, Тревор, Джейсон), колесо смены героев, миссия «Волчий налог».

## Что где
- `apk/` — последняя сборка (Dacha-Mihalych-v1.33.apk). Скачать: файл → Download.
- `project/` — **весь проект Godot целиком** (открыть `project.godot` в Godot 4.6).
  - `scripts/` — игра; `mission1.gd` — миссия; `hero_rig.gd`, `char_defs.gd` — скелет и герои; `run_cycle.gd`, `walk_cycle.gd` — анимации, подогнанные по видео.
  - `tools/fit/` — Python-инструменты подгонки анимаций по референсам.
  - `tools_src/` — исходники для запекания (не попадают в APK): полноразмерный меш Джейсона, исходная сетка Михалыча. Скрипты `scripts/_bake_jason.gd`, `_decimate_jason.gd`, `_prep_jason.gd`, `_rebake_w2.gd`.
  - `relay/` — Cloudflare-реле для совместной игры (ещё не развёрнуто).
- `originals/models/` — исходные FBX из Meshy (лесоруб, Тревор, Джейсон). `originals/jason_textures/` — полноразмерные текстуры Джейсона (в игре сжаты).
- `originals/reference_videos/` — референсы анимаций.

## Сборка
`godot --headless --path project --import`, затем `--export-debug "Android" out.apk`. Ключи подписи в репозиторий не входят.
