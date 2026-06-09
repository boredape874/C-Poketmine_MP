param(
    [string]$OutputDir = "var/perf/production-evidence"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$resolvedOutput = Join-Path $rootPath $OutputDir
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$outPath = Join-Path $resolvedOutput "host-network.json"

function Invoke-OptionalCommand([scriptblock]$Command){
    try{
        $value = & $Command
        return [pscustomobject]@{
            ok = $true
            value = $value
            error = $null
        }
    }catch{
        return [pscustomobject]@{
            ok = $false
            value = $null
            error = $_.Exception.Message
        }
    }
}

$netAdapters = Invoke-OptionalCommand {
    Get-NetAdapter | ForEach-Object {
        [pscustomobject]@{
            name = $_.Name
            description = $_.InterfaceDescription
            status = "$($_.Status)"
            link_speed = "$($_.LinkSpeed)"
            mac_address = $_.MacAddress
        }
    }
}
$ipConfig = Invoke-OptionalCommand {
    Get-NetIPConfiguration | ForEach-Object {
        [pscustomobject]@{
            interface_alias = $_.InterfaceAlias
            ipv4 = @($_.IPv4Address | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" })
            ipv6 = @($_.IPv6Address | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" })
            ipv4_gateway = @($_.IPv4DefaultGateway | ForEach-Object { "$($_.NextHop)" })
            dns_servers = @($_.DNSServer.ServerAddresses | ForEach-Object { "$_" })
        }
    }
}
$firewallProfiles = Invoke-OptionalCommand { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction }
$udpEndpoints = Invoke-OptionalCommand { Get-NetUDPEndpoint | Where-Object { $_.LocalPort -in @(19132, 19133) } | Select-Object LocalAddress, LocalPort, OwningProcess }
$udpGlobal = Invoke-OptionalCommand { netsh int udp show global }
$ipGlobal = Invoke-OptionalCommand { netsh int ip show global }
$osInfo = Invoke-OptionalCommand { Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture, TotalVisibleMemorySize, FreePhysicalMemory }
$cpuInfo = Invoke-OptionalCommand { Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed }

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    machine = [pscustomobject]@{
        name = [Environment]::MachineName
        processor_count = [Environment]::ProcessorCount
        os_version = [Environment]::OSVersion.VersionString
        is_64bit_os = [Environment]::Is64BitOperatingSystem
        is_64bit_process = [Environment]::Is64BitProcess
    }
    os = $osInfo
    cpu = $cpuInfo
    adapters = $netAdapters
    ip_configuration = $ipConfig
    firewall_profiles = $firewallProfiles
    udp_endpoints_19132_19133 = $udpEndpoints
    netsh_udp_global = $udpGlobal
    netsh_ip_global = $ipGlobal
    notes = @(
        "This is host-local evidence only. Final production approval still requires checking the actual deployment host and upstream firewall/NAT path.",
        "Windows is useful for local validation, but the performance plan remains Linux-first for final high-concurrency production."
    )
}

$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 7
