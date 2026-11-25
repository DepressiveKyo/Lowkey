[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Version
)

$ErrorActionPreference = "Stop"

$scriptsDir = Join-Path $RepoRoot "scripts"
if (-not (Test-Path $scriptsDir)) {
    New-Item -ItemType Directory -Force $scriptsDir | Out-Null
}

if (-not $Version) {
    $Version = (Get-Date -Format "yyyy.MM.dd.HHmm")
}

$sha = [System.Security.Cryptography.SHA256]::Create()
$entries = @()

foreach ($file in Get-ChildItem $scriptsDir -Recurse -File -Filter "*.lua" | Sort-Object FullName) {
    $rel = $file.FullName.Substring($RepoRoot.Length + 1).Replace("\", "/")
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $hash = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })

    $name = $file.BaseName
    $champion = $null
    $order = 100

    $parent = Split-Path -Leaf (Split-Path -Parent $file.FullName)
    if ($parent -eq "champions") {
        $champion = $name
        $order = 100
    } elseif ($parent -eq "core") {
        $order = 10
    }

    $entries += [PSCustomObject]@{
        Name     = $name
        File     = $rel
        Bytes    = $bytes.Length
        Sha256   = $hash
        Champion = $champion
        Order    = $order
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("return {")
[void]$sb.AppendLine("    api = 1,")
[void]$sb.AppendLine("    version = `"$Version`",")
[void]$sb.AppendLine("    scripts = {")

foreach ($e in ($entries | Sort-Object Name)) {
    $line = "        [`"$($e.Name)`"] = { file = `"$($e.File)`", bytes = $($e.Bytes), sha256 = `"$($e.Sha256)`""
    if ($e.Champion) { $line += ", champion = `"$($e.Champion)`"" }
    if ($e.Order -ne 100) { $line += ", order = $($e.Order)" }
    $line += " },"
    [void]$sb.AppendLine($line)
}

[void]$sb.AppendLine("    },")
[void]$sb.AppendLine("}")

$out = Join-Path $RepoRoot "manifest.lua"
[System.IO.File]::WriteAllText($out, $sb.ToString().Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding $false))

Write-Host "manifest.lua -> $($entries.Count) script(s), version $Version"
foreach ($e in ($entries | Sort-Object Name)) {
    $tag = if ($e.Champion) { "champion=$($e.Champion)" } else { "always" }
    Write-Host ("  {0,-22} {1,8} bytes  {2}" -f $e.Name, $e.Bytes, $tag)
}
