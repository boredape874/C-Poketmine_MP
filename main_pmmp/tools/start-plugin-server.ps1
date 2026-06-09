param(
    [int]$Port = 19132,
    [int]$MaxPlayers = 400,
    [string]$DataDir = "plugin-server-data",
    [switch]$Background
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$dataPath = Join-Path $root $DataDir
$pluginsPath = Join-Path $root "plugins"
$php = Join-Path $root "bin/php/php.exe"
New-Item -ItemType Directory -Force -Path $dataPath | Out-Null

$serverProperties = Join-Path $dataPath "server.properties"
@"
motd=PMMP Plugin Server
server-port=$Port
server-portv6=0
enable-ipv6=false
white-list=false
max-players=$MaxPlayers
gamemode=survival
force-gamemode=false
hardcore=false
pvp=true
difficulty=1
level-name=world
level-seed=
level-type=DEFAULT
enable-query=true
auto-save=true
view-distance=4
xbox-auth=false
language=eng
"@ | Set-Content -LiteralPath $serverProperties -Encoding ASCII

$pocketmineYml = Join-Path $dataPath "pocketmine.yml"
if(-not (Test-Path -LiteralPath $pocketmineYml)){
    $content = Get-Content -LiteralPath (Join-Path $root "resources/pocketmine.yml") -Raw
    $content = $content.Replace("  enable-dev-builds: false", "  enable-dev-builds: true")
    $content = $content.Replace("  async-compression: false", "  async-compression: true")
    $content = $content.Replace("  compression-level: 6", "  compression-level: 1")
    $content | Set-Content -LiteralPath $pocketmineYml -Encoding UTF8
}

$args = @(
    (Join-Path $root "src/PocketMine.php"),
    "--no-wizard",
    "--disable-ansi",
    "--data=$dataPath",
    "--plugins=$pluginsPath"
)

if($Background){
    $runDir = Join-Path $root "var/plugin-server"
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    $stdout = Join-Path $runDir "stdout.log"
    $stderr = Join-Path $runDir "stderr.log"
    $process = Start-Process -FilePath $php -ArgumentList $args -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    [pscustomobject]@{
        pid = $process.Id
        port = $Port
        data_dir = $dataPath
        plugins_dir = $pluginsPath
        stdout = $stdout
        stderr = $stderr
        server_log = Join-Path $dataPath "server.log"
    } | ConvertTo-Json -Depth 4
    exit 0
}

& $php @args
