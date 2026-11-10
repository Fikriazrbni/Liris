$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    py -3.13 -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.13 x64 diperlukan untuk build.' }
}
& $python -m pip install --requirement requirements.lock
if ($LASTEXITCODE -ne 0) { throw 'Instalasi dependensi gagal' }
& $python -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { throw 'Tes Windows gagal' }
& $python generate_icon.py
if ($LASTEXITCODE -ne 0) { throw 'Pembuatan ikon Windows gagal' }
& $python -m PyInstaller --noconfirm --clean Liris.spec
if ($LASTEXITCODE -ne 0) { throw 'Packaging gagal' }
& $python package.py
if ($LASTEXITCODE -ne 0) { throw 'Pembuatan ZIP gagal' }
