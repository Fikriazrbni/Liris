$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    py -3.13 -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'Building Liris requires 64-bit Python 3.13.' }
}
& $python -m pip install --requirement requirements.lock
if ($LASTEXITCODE -ne 0) { throw 'Could not install dependencies' }
& $python -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { throw 'Windows tests failed' }
& $python generate_icon.py
if ($LASTEXITCODE -ne 0) { throw 'Could not create the Windows icon' }
& $python -m PyInstaller --noconfirm --clean Liris.spec
if ($LASTEXITCODE -ne 0) { throw 'Could not package the app' }
& $python package.py
if ($LASTEXITCODE -ne 0) { throw 'Could not create the ZIP archive' }
