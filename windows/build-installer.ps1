param(
    [string]$Bundle = (Join-Path $PSScriptRoot 'dist\Liris-Windows'),
    [string]$Compiler = $env:ISCC_PATH,
    [ValidatePattern('^\d+(\.\d+){1,3}$')]
    [string]$Version = '0.1.0'
)

$ErrorActionPreference = 'Stop'
$bundlePath = (Resolve-Path -LiteralPath $Bundle).Path
foreach ($required in @('Liris.exe', 'LirisBridge.exe', 'LirisWorker.exe', '_internal\python313.dll', '_internal\Extension\manifest.json', 'THIRD-PARTY-LICENSES\INVENTORY.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundlePath $required) -PathType Leaf)) {
        throw "Windows bundle is incomplete: $required"
    }
}

if (-not $Compiler) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) { $Compiler = $command.Source }
}
if (-not $Compiler) {
    $Compiler = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
        "$env:ProgramFiles\Inno Setup 7\ISCC.exe"
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $Compiler) { throw 'Install Inno Setup or pass the path to ISCC.exe with -Compiler.' }
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path

& $compilerPath "/DBundleDir=$bundlePath" "/DAppVersion=$Version" (Join-Path $PSScriptRoot 'Liris.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE" }
