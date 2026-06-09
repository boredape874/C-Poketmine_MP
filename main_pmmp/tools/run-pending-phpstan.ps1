param(
    [switch]$IncludeTooling,
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outRoot = Join-Path $rootPath "var/perf/pending-phpstan/$stamp"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$outRootPath = (Resolve-Path $outRoot).Path
$phpstanOutputPath = Join-Path $outRootPath "phpstan.txt"
$drive = "P:"
$mapped = $false
$existing = & subst

if(($existing -join "`n") -notmatch "^P:\\"){
    & subst $drive $root
    $mapped = $true
}

try{
    $php = "P:\bin\php\php.exe"
    $phpstan = "P:\vendor\bin\phpstan"
    $config = "P:\phpstan.neon.dist"
    $files = @(
        "P:\src\Server.php",
        "P:\src\scheduler\AsyncPool.php",
        "P:\src\entity\AttributeMap.php",
        "P:\src\entity\Entity.php",
        "P:\src\entity\effect\EffectCollection.php",
        "P:\src\entity\Human.php",
        "P:\src\entity\Living.php",
        "P:\src\entity\Squid.php",
        "P:\src\entity\object\AreaEffectCloud.php",
        "P:\src\entity\object\ExperienceOrb.php",
        "P:\src\entity\object\ItemEntity.php",
        "P:\src\network\mcpe\InventoryManager.php",
        "P:\src\network\mcpe\compression\CompressBatchPromise.php",
        "P:\src\network\mcpe\NetworkBroadcastUtils.php",
        "P:\src\network\mcpe\handler\InGamePacketHandler.php",
        "P:\src\network\mcpe\handler\ResourcePacksPacketHandler.php",
        "P:\src\network\mcpe\NetworkSession.php",
        "P:\src\network\mcpe\cache\ChunkCache.php",
        "P:\src\network\mcpe\cache\CraftingDataCache.php",
        "P:\src\network\mcpe\convert\BlockStateDictionary.php",
        "P:\src\network\mcpe\StandardEntityEventBroadcaster.php",
        "P:\src\inventory\BaseInventory.php",
        "P:\src\inventory\CreativeInventory.php",
        "P:\src\inventory\PlayerOffHandInventory.php",
        "P:\src\inventory\SimpleInventory.php",
        "P:\src\player\Player.php",
        "P:\src\entity\projectile\Arrow.php",
        "P:\src\entity\projectile\Projectile.php",
        "P:\src\entity\projectile\SplashPotion.php",
        "P:\src\entity\object\FireworkRocket.php",
        "P:\src\entity\utils\ExperienceUtils.php",
        "P:\src\player\SurvivalBlockBreakHandler.php",
        "P:\src\world\format\Chunk.php",
        "P:\src\world\format\SubChunk.php",
        "P:\src\world\format\io\data\BedrockWorldData.php",
        "P:\src\world\format\io\FastChunkSerializer.php",
        "P:\src\world\format\io\leveldb\LevelDB.php",
        "P:\src\world\format\io\region\RegionLocationTableEntry.php",
        "P:\src\world\Explosion.php",
        "P:\src\world\generator\FlatGeneratorOptions.php",
        "P:\src\world\generator\Gaussian.php",
        "P:\src\world\generator\PopulationTask.php",
        "P:\vendor\pocketmine\bedrock-protocol\src\PacketPool.php",
        "P:\vendor\pocketmine\bedrock-protocol\src\serializer\PacketBatch.php",
        "P:\src\world\World.php"
    )

    if($IncludeTooling){
        $files += @(
            "P:\tools\bench-hotpaths.php",
            "P:\tools\bench-native-extension.php",
            "P:\tools\rak-ping-burst.php"
        )
    }

    Push-Location "P:\"
    try{
        & $php "-dmemory_limit=512M" $phpstan analyse -c $config @files --no-progress --error-format=raw > $phpstanOutputPath 2>&1
        $exit = $LASTEXITCODE
    }finally{
        Pop-Location
    }

    [pscustomobject]@{
        root = $rootPath
        run_dir = $outRootPath
        output = $phpstanOutputPath
        files = $files
        include_tooling = [bool]$IncludeTooling
        phpstan_exit = $exit
    } | ConvertTo-Json -Depth 4

    if(-not $NoExitCode){
        exit $exit
    }
}finally{
    if($mapped){
        & subst $drive /D
    }
}
