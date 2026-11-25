[CmdletBinding()]
param(
    [string]$Path,
    [string]$Repo = "DepressiveKyo/Lowkey",
    [string]$Branch = "main",
    [switch]$NoActivate
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BaseUrl = "https://raw.githubusercontent.com/$Repo/$Branch/"

function Write-Step($text) { Write-Host "  $text" }
function Write-Good($text) { Write-Host "  $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "  $text" -ForegroundColor Yellow }
function Write-Bad($text)  { Write-Host "  $text" -ForegroundColor Red }

function Test-GosRoot($candidate) {
    if (-not $candidate) { return $false }
    if (-not (Test-Path -LiteralPath $candidate)) { return $false }
    return Test-Path -LiteralPath (Join-Path $candidate "LOLEXT\Scripts")
}

function Find-GosRoots {
    $found = New-Object System.Collections.Generic.List[string]

    foreach ($proc in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*GamingOnSteroids*" })) {
        try {
            $dir = Split-Path -Parent $proc.MainModule.FileName
            while ($dir -and -not (Test-GosRoot $dir)) { $dir = Split-Path -Parent $dir }
            if (Test-GosRoot $dir) { [void]$found.Add($dir) }
        } catch {}
    }

    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($r in @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("MyDocuments"),
        (Join-Path $env:USERPROFILE "Downloads"),
        $env:LOCALAPPDATA,
        $env:APPDATA,
        ${env:ProgramFiles},
        ${env:ProgramFiles(x86)}
    )) { if ($r -and (Test-Path -LiteralPath $r)) { [void]$roots.Add($r) } }

    foreach ($d in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        if ($d.Root -and (Test-Path -LiteralPath $d.Root)) { [void]$roots.Add($d.Root) }
    }

    foreach ($root in ($roots | Select-Object -Unique)) {
        try {
            foreach ($hit in @(Get-ChildItem -LiteralPath $root -Directory -Filter "GamingOnSteroids" -Recurse -Depth 4 -ErrorAction SilentlyContinue)) {
                if (Test-GosRoot $hit.FullName) { [void]$found.Add($hit.FullName) }
            }
        } catch {}
        if ($found.Count -gt 0) { break }
    }

    return ,@($found | Select-Object -Unique)
}

function Get-Remote($relative, $destination) {
    $url = $BaseUrl + $relative
    $dir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
    } catch {
        throw "no se pudo descargar $url : $($_.Exception.Message)"
    }
    $size = (Get-Item -LiteralPath $destination).Length
    if ($size -le 0) { throw "descarga vacia: $url" }
    return $size
}

function Set-ScriptActive($iniPath, $entry) {
    $section = "[$entry]"
    if (-not (Test-Path -LiteralPath $iniPath)) {
        [IO.File]::WriteAllText($iniPath, "$section`r`nACTIVE = 1`r`nUPDATE = `r`n`r`n`r`n")
        return "creado"
    }
    $lines = [System.Collections.Generic.List[string]]([IO.File]::ReadAllLines($iniPath))
    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq $section) { $index = $i; break }
    }
    if ($index -ge 0) {
        for ($j = $index + 1; $j -lt [Math]::Min($index + 4, $lines.Count); $j++) {
            if ($lines[$j] -match '^\s*ACTIVE\s*=') { $lines[$j] = "ACTIVE = 1"; break }
        }
        [IO.File]::WriteAllLines($iniPath, $lines)
        return "actualizado"
    }
    $lines.Add("")
    $lines.Add("")
    $lines.Add($section)
    $lines.Add("ACTIVE = 1")
    $lines.Add("UPDATE = ")
    [IO.File]::WriteAllLines($iniPath, $lines)
    return "anadido"
}

Write-Host ""
Write-Host "Lowkey installer" -ForegroundColor Cyan
Write-Host "  repo: $Repo@$Branch"
Write-Host ""

$root = $null

if ($Path) {
    if (Test-GosRoot $Path) {
        $root = $Path
    } elseif (Test-GosRoot (Join-Path $Path "GamingOnSteroids")) {
        $root = Join-Path $Path "GamingOnSteroids"
    } else {
        Write-Bad "la ruta indicada no contiene LOLEXT\Scripts: $Path"
        return
    }
} else {
    Write-Step "buscando GamingOnSteroids..."
    $hits = @(Find-GosRoots)
    if ($hits.Count -eq 0) {
        Write-Bad "no lo he encontrado"
        Write-Host ""
        Write-Host "  vuelve a lanzarlo indicando la ruta:" -ForegroundColor Yellow
        Write-Host "  & ([scriptblock]::Create((irm $($BaseUrl)install.ps1))) -Path 'C:\ruta\a\GamingOnSteroids'"
        Write-Host ""
        return
    } elseif ($hits.Count -eq 1) {
        $root = $hits[0]
    } else {
        Write-Host ""
        Write-Host "  he encontrado varias instalaciones:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $hits.Count; $i++) { Write-Host "   [$($i+1)] $($hits[$i])" }
        Write-Host ""
        $pick = Read-Host "  cual uso (1-$($hits.Count))"
        $n = 0
        if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $hits.Count) {
            Write-Bad "seleccion invalida"
            return
        }
        $root = $hits[$n - 1]
    }
}

if (-not (Test-GosRoot $root)) {
    Write-Bad "ruta invalida tras la deteccion: $root"
    return
}
$root = (Resolve-Path -LiteralPath $root).Path

Write-Good "GamingOnSteroids: $root"

$scripts = Join-Path $root "LOLEXT\Scripts"
$common  = Join-Path $scripts "Common\Lowkey"
$store   = Join-Path $common "scripts"
$ini     = Join-Path $root "LOLEXT\LocalScriptDB.ini"

foreach ($dir in @($common, $store)) {
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
}

Write-Host ""
Write-Step "descargando..."

$total = 0
$total += Get-Remote "Lowkey.lua"    (Join-Path $scripts "Lowkey.lua")
Write-Good "Scripts\Lowkey.lua"
$total += Get-Remote "bootstrap.lua" (Join-Path $common "bootstrap.lua")
Write-Good "Scripts\Common\Lowkey\bootstrap.lua"

try {
    $total += Get-Remote "manifest.lua" (Join-Path $common "manifest.lua")
    Write-Good "Scripts\Common\Lowkey\manifest.lua"
} catch {
    Write-Warn "manifest.lua no disponible todavia, el loader lo bajara al arrancar"
}

Write-Host ""
if ($NoActivate) {
    Write-Warn "no activado (--NoActivate): marcalo tu en el menu de GoS"
} else {
    $what = Set-ScriptActive $ini "Lowkey.lua"
    Write-Good "LocalScriptDB.ini: [Lowkey.lua] ACTIVE = 1 ($what)"
}

Write-Host ""
Write-Host "  listo. $([math]::Round($total/1KB,1)) KB instalados." -ForegroundColor Cyan
Write-Host "  abre GoS y los scripts se descargan solos desde el repo."
Write-Host ""
