# Run from the game root after copying this repository over CoD4 + Mod Tools.
# A CoD4-compatible HLSL shader_tool must be installed in raw\shader_bin.
param([string]$GameRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = "Stop"
$raw = Join-Path $GameRoot "raw"
$source = Join-Path $raw "materials\tank_shell"
if (!(Test-Path $source)) { throw "Missing stock Mod Tools material: $source" }
# Preserve all render states, sampler settings and the ORIGINAL tank_shell image.
# Both replacement strings fit their original slots: no binary offsets change.
[byte[]]$material = [IO.File]::ReadAllBytes($source)
if ($material.Length -lt 76) { throw "Unsupported tank_shell material header" }
$nameOffset = [BitConverter]::ToInt32($material, 0)
$techOffset = [BitConverter]::ToInt32($material, 52)
function Read-CString([byte[]]$bytes, [int]$offset) {
    if ($offset -lt 0 -or $offset -ge $bytes.Length) { throw "Bad material string offset" }
    $end = $offset
    while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
    if ($end -eq $bytes.Length) { throw "Unterminated material string" }
    return [Text.Encoding]::ASCII.GetString($bytes, $offset, $end - $offset)
}
if ((Read-CString $material $nameOffset) -ne "tank_shell" -or
    (Read-CString $material $techOffset) -ne "2d" -or
    [BitConverter]::ToInt32($material, 60) -ne $techOffset) {
    throw "Unsupported stock tank_shell layout; no files were written"
}
# 'pf' = playervehicle fill; short techset name is deliberate (same size as '2d').
[Array]::Clear($material, $nameOffset, 11)
[Text.Encoding]::ASCII.GetBytes("pv_reload").CopyTo($material, $nameOffset)
[Text.Encoding]::ASCII.GetBytes("pf").CopyTo($material, $techOffset)
$compiler = Join-Path $raw "shader_bin\shader_tool.exe"
if (!(Test-Path $compiler)) { throw "Install CoD4 HLSL shader_tool.exe in raw\shader_bin first" }
Push-Location (Join-Path $raw "shader_bin")
try {
    New-Item -ItemType Directory -Force "backups" | Out-Null
    & $compiler pv_shell_fill
    if ($LASTEXITCODE -ne 0) { throw "HUD shader compilation failed" }
} finally { Pop-Location }
[IO.File]::WriteAllBytes((Join-Path $raw "materials\pv_reload"), $material)
$properties = Join-Path $raw "material_properties\tank_shell"
if (Test-Path $properties) {
    Copy-Item $properties (Join-Path $raw "material_properties\pv_reload") -Force
}
Write-Host "Reload HUD built. Rebuild cobra_pilot.ff with linker_pc.exe."
