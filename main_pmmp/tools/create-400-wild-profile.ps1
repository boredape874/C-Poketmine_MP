param(
    [string]$OutputDir = "var/perf/profiles/wild-400",
    [int]$Port = 19132,
    [switch]$OfflineAuth,
    [switch]$Korean
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$profileRoot = Join-Path $root $OutputDir
New-Item -ItemType Directory -Force -Path $profileRoot | Out-Null

$language = if ($Korean) { "kor" } else { "eng" }
$xboxAuth = if ($OfflineAuth) { "false" } else { "true" }
$verifyXuid = if ($OfflineAuth) { "false" } else { "true" }

@"
motd=PMMP Wild 400 Target
server-port=$Port
server-portv6=0
enable-ipv6=false
white-list=false
max-players=400
gamemode=survival
force-gamemode=false
hardcore=false
pvp=true
difficulty=1
level-name=world
level-seed=
level-type=DEFAULT
enable-query=false
auto-save=true
view-distance=4
xbox-auth=$xboxAuth
language=$language
"@ | Set-Content -LiteralPath (Join-Path $profileRoot "server.properties") -Encoding ASCII

@"
settings:
  async-workers: auto
  enable-dev-builds: true
  enable-profiling: true
  profile-report-trigger: 18

network:
  compression-level: 1
  async-compression: true
  async-compression-threshold: 4096
  max-mtu-size: 1492
  enable-encryption: true
  raklib-packet-limit: 1200

debug:
  level: 1

player:
  save-player-data: true
  verify-xuid: $verifyXuid

level-settings:
  default-format: leveldb

chunk-sending:
  per-tick: 2
  spawn-radius: 2

chunk-ticking:
  tick-radius: 2
  blocks-per-subchunk-per-tick: 1
  disable-block-ticking: []

chunk-generation:
  population-queue-size: 8

ticks-per:
  autosave: 6000

anonymous-statistics:
  enabled: false

auto-updater:
  enabled: false

timings:
  host: timings.pmmp.io

console:
  enable-input: false
  title-tick: false

plugins:
  legacy-data-dir: false
"@ | Set-Content -LiteralPath (Join-Path $profileRoot "pocketmine.yml") -Encoding ASCII

@"
# PMMP Wild 400 Profile

This profile is an aggressive starting point for high-concurrency survival testing.
Do not treat it as a final production config without benchmark results.

Generated files:
- server.properties
- pocketmine.yml

Recommended first test:
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-source-baseline.ps1 -AcceptLgpl -Port $Port -DurationSeconds 300
"@ | Set-Content -LiteralPath (Join-Path $profileRoot "README.md") -Encoding ASCII

Write-Output $profileRoot
