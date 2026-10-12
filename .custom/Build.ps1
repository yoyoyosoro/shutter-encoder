param([Parameter(Mandatory=$true)][string]$JdkHome,[Parameter(Mandatory=$true)][string]$OutputJar,[string]$RepoRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$build = Join-Path (Split-Path $OutputJar -Parent) ('compile-' + [Guid]::NewGuid().ToString('N'))
$classes = Join-Path $build 'classes'
New-Item -ItemType Directory -Path $classes -Force | Out-Null
$files = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'src\shutterencoder') -Filter '*.java' -Recurse | ForEach-Object { '"' + $_.FullName.Replace('\','/') + '"' })
$list = Join-Path $build 'sources.txt'
[IO.File]::WriteAllLines($list, [string[]]$files, [Text.UTF8Encoding]::new($false))
& (Join-Path $JdkHome 'bin\javac.exe') -encoding UTF-8 --release 25 -cp (Join-Path $RepoRoot 'src\libs\*') -d $classes "@$list"
if ($LASTEXITCODE -ne 0) { throw 'Source compilation failed' }
& (Join-Path $JdkHome 'bin\java.exe') (Join-Path $PSScriptRoot 'JarRepack.java') (Join-Path $RepoRoot 'Shutter Encoder.jar') $OutputJar $classes
if ($LASTEXITCODE -ne 0) { throw 'Jar packaging failed' }
& (Join-Path $PSScriptRoot 'Test-NoDonateBytecode.ps1') -JdkHome $JdkHome -JarPath $OutputJar
if (!(Test-Path -LiteralPath $OutputJar)) { throw 'Build produced no application' }
