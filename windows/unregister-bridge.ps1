$ErrorActionPreference = 'Stop'
$hostName = 'id.local.liris.bridge'
foreach ($browser in @('Google\Chrome', 'BraveSoftware\Brave-Browser', 'Microsoft\Edge')) {
    $key = "HKCU:\Software\$browser\NativeMessagingHosts\$hostName"
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key }
}
$manifest = Join-Path $env:LOCALAPPDATA 'Liris\NativeMessaging\id.local.liris.bridge.json'
if (Test-Path -LiteralPath $manifest) { Remove-Item -LiteralPath $manifest }
Write-Output 'The Liris host has been unregistered. You can remove the browser extension and cache separately.'
