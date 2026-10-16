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
$fxc = Join-Path $raw "shader_bin\shader_src\fxc.exe"
if (!(Test-Path $fxc -PathType Leaf)) {
    throw "Missing HLSL compiler: $fxc. Install fxc.exe before building the HUD."
}
Push-Location (Join-Path $raw "shader_bin")
try {
    New-Item -ItemType Directory -Force "backups" | Out-Null
    $started = [DateTime]::UtcNow
    # Shader Tool v0.1 may return 0 even when its child fxc.exe fails.
    $output = & $compiler pv_shell_fill 2>&1
    $compileExit = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($compileExit -ne 0 -or
        ($output -join "`n") -match '(?im)\berror\b|\bfailed\b|not recognized|cannot find') {
        throw "HUD shader compilation failed; do not run linker."
    }
    # Shader Tool v0.1 only builds SM3. The sm2 techset also needs genuine
    # vs_2_0 / ps_2_0 bytecode; renaming SM3 files is NOT a valid substitute.
    foreach ($stage in @("vs", "ps")) {
        $inputFile = Join-Path $PWD "shader_src\${stage}_2_0_pv_shell_fill.hlsl"
        if (!(Test-Path $inputFile -PathType Leaf)) {
            throw "Missing SM2 source: $inputFile"
        }
        $tempFile = [IO.Path]::GetTempFileName()
        try {
            & $fxc /nologo /T "${stage}_2_0" /E "${stage}_main" /Fo $tempFile $inputFile
            if ($LASTEXITCODE -ne 0) { throw "SM2 $stage compilation failed; do not run linker." }
            [byte[]]$bytecode = [IO.File]::ReadAllBytes($tempFile)
            if ($bytecode.Length -lt 8 -or ($bytecode.Length % 4) -ne 0) {
                throw "Invalid SM2 $stage compiler output"
            }
            $versionHex = if ($stage -eq "vs") { "FFFE0200" } else { "FFFF0200" }
            if ([BitConverter]::ToUInt32($bytecode, 0) -ne [Convert]::ToUInt32($versionHex, 16)) {
                throw "Wrong shader profile for SM2 $stage"
            }
            # CoD4 shader_bin format: uint32 little-endian bytecode length,
            # followed by the unmodified D3D9 bytecode (including CTAB).
            [byte[]]$wrapped = New-Object byte[] ($bytecode.Length + 4)
            [BitConverter]::GetBytes([uint32]$bytecode.Length).CopyTo($wrapped, 0)
            $bytecode.CopyTo($wrapped, 4)
            $destination = Join-Path $PWD "${stage}_2_0_c853756d"
            [IO.File]::WriteAllBytes($destination, $wrapped)
            Write-Host ("{0}, {1} bytes" -f (Split-Path $destination -Leaf), $wrapped.Length)
        } finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }
    # These names are reported by Shader Tool for pv_shell_fill (hash 37AC8A92).
    # Never accept missing, empty, or stale bytecode as a successful compilation.
    foreach ($name in @("vs_3_0_c853756d", "ps_3_0_c853756d", "vs_2_0_c853756d", "ps_2_0_c853756d")) {
        if (!(Test-Path $name -PathType Leaf)) {
            throw "Compiler produced no $name; do not run linker."
        }
        $built = Get-Item $name
        if ($built.Length -eq 0 -or $built.LastWriteTimeUtc -lt $started.AddSeconds(-2)) {
            throw "Compiler produced empty or stale $name; do not run linker."
        }
    }
} finally { Pop-Location }
[IO.File]::WriteAllBytes((Join-Path $raw "materials\pv_reload"), $material)
$properties = Join-Path $raw "material_properties\tank_shell"
if (Test-Path $properties) {
    Copy-Item $properties (Join-Path $raw "material_properties\pv_reload") -Force
}
Write-Host "Reload HUD built. Rebuild cobra_pilot.ff with linker_pc.exe."
