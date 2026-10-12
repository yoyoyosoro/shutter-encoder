param(
    [Parameter(Mandatory=$true)][string]$InstallRoot,
    [Parameter(Mandatory=$true)][string]$CandidateRoot,
    [scriptblock]$ValidateInstalled = { param($path) }
)
$ErrorActionPreference = 'Stop'
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
$CandidateRoot = [IO.Path]::GetFullPath($CandidateRoot).TrimEnd('\')
$components = @('app','runtime','Shutter Encoder.exe','Shutter Encoder (OpenGL).exe')
foreach ($part in $components) {
    if (!(Test-Path -LiteralPath (Join-Path $CandidateRoot $part))) { throw "Incomplete candidate: $part" }
}
if (!(Test-Path -LiteralPath (Join-Path $InstallRoot 'app\Shutter Encoder.jar'))) { throw 'Installation not found' }
$backup = Join-Path $InstallRoot ('maintenance\backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
$prepared = Join-Path $InstallRoot ('maintenance\work\deploy-' + [Guid]::NewGuid().ToString('N'))
foreach ($path in @($backup,$prepared)) {
    if (![IO.Path]::GetFullPath($path).StartsWith($InstallRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe deployment path' }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}
foreach ($part in $components) { Copy-Item -LiteralPath (Join-Path $CandidateRoot $part) -Destination $prepared -Recurse -Force }
foreach ($relative in @('app\LUTs','app\Library\models')) {
    $previous = Join-Path $InstallRoot $relative
    if (Test-Path -LiteralPath $previous) {
        $destination = Join-Path $prepared $relative
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Get-ChildItem -LiteralPath $previous -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force }
    }
}
if (Test-Path -LiteralPath (Join-Path $InstallRoot 'settings.xml')) {
    Copy-Item -LiteralPath (Join-Path $InstallRoot 'settings.xml') -Destination (Join-Path $backup 'settings.xml')
}
$moved = @()
$activated = @()
try {
    foreach ($part in $components) {
        $current = Join-Path $InstallRoot $part
        if (Test-Path -LiteralPath $current) {
            Move-Item -LiteralPath $current -Destination (Join-Path $backup $part)
            $moved += $part
        }
        Move-Item -LiteralPath (Join-Path $prepared $part) -Destination $current
        $activated += $part
    }
    & $ValidateInstalled $InstallRoot
    "DEPLOY_OK backup=$backup"
} catch {
    $failure = $_
    foreach ($part in @($activated)) {
        Move-Item -LiteralPath (Join-Path $InstallRoot $part) -Destination (Join-Path $prepared $part)
    }
    foreach ($part in @($moved)) {
        Move-Item -LiteralPath (Join-Path $backup $part) -Destination (Join-Path $InstallRoot $part)
    }
    throw $failure
}
