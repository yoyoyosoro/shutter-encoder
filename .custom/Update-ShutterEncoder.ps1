param([switch]$ValidateOnly,[switch]$Force,[string]$InstallRoot=(Split-Path $PSScriptRoot -Parent),[string]$Repository='yoyoyosoro/shutter-encoder',[string]$SourceArchive,[string]$JdkHome=(Join-Path $PSScriptRoot 'tools\jdk25'))
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid repository name' }
$maintenance = Join-Path $InstallRoot 'maintenance'
$run = Join-Path $maintenance ('work\update-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run,(Join-Path $maintenance 'cache') -Force | Out-Null
$updateLock = [IO.File]::Open((Join-Path $maintenance 'update.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$log = Join-Path $run 'update.log'
Start-Transcript -Path $log | Out-Null
try {
    if (!(Test-Path -LiteralPath (Join-Path $InstallRoot 'Shutter Encoder.exe'))) { throw 'Existing installation not found' }
    $running = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($InstallRoot + '\',[StringComparison]::OrdinalIgnoreCase) -and $_.Name -like 'Shutter Encoder*.exe' })
    if ($running.Count -gt 0) { throw 'Please close Shutter Encoder before updating' }
    if (!(Test-Path -LiteralPath (Join-Path $JdkHome 'bin\javac.exe'))) { throw 'Retained JDK not found' }
    $archive = Join-Path $run 'custom-source.zip'
    if ($SourceArchive) { Copy-Item -LiteralPath $SourceArchive -Destination $archive }
    else {
        Write-Host 'Downloading verified custom branch. Run Merge upstream into custom on GitHub first to include newer upstream releases.'
        Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repository/zip/refs/heads/custom" -OutFile $archive
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $bytes = [IO.File]::ReadAllBytes($archive)
    $sourceCommit = ''
    for ($i=$bytes.Length-22; $i -ge [Math]::Max(0,$bytes.Length-65557); $i--) {
        if ([BitConverter]::ToUInt32($bytes,$i) -eq 0x06054b50) {
            $length = [BitConverter]::ToUInt16($bytes,$i+20)
            $sourceCommit = [Text.Encoding]::ASCII.GetString($bytes,$i+22,$length)
            break
        }
    }
    if ($sourceCommit -notmatch '^[a-f0-9]{40}$' -and !$SourceArchive) { throw 'Cannot identify source commit' }
    $statePath = Join-Path $maintenance 'installed-state.json'
    if (!$Force -and !$SourceArchive -and (Test-Path -LiteralPath $statePath)) {
        $state = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
        if ($state.sourceCommit -eq $sourceCommit -and $state.jarSha256 -eq (Get-FileHash -LiteralPath (Join-Path $InstallRoot 'app\Shutter Encoder.jar') -Algorithm SHA256).Hash) {
            Write-Host "Already current: $sourceCommit"; return
        }
    }
    $sourceDir = Join-Path $run 'source'
    [IO.Compression.ZipFile]::ExtractToDirectory($archive,$sourceDir)
    $repo = (Get-ChildItem -LiteralPath $sourceDir -Directory | Select-Object -First 1).FullName
    $source = [IO.File]::ReadAllText((Join-Path $repo 'src\shutterencoder\ui\main\Shutter.java'))
    $versionMatch = [regex]::Match($source,'actualVersion\s*=\s*"([0-9]+\.[0-9]+)"')
    if (!$versionMatch.Success) { throw 'Cannot identify source application version' }
    $version = $versionMatch.Groups[1].Value
    $compiled = Join-Path $run 'Shutter Encoder.jar'
    & (Join-Path $PSScriptRoot 'Build.ps1') -JdkHome $JdkHome -OutputJar $compiled -RepoRoot $repo
    $officialZip = Join-Path $maintenance "cache\official-$version.zip"
    if (!(Test-Path -LiteralPath $officialZip)) {
        $partial = Join-Path $run 'official-download.zip'
        $fileName = [Uri]::EscapeDataString("Shutter Encoder $version Windows 64bits.zip")
        Write-Host "Downloading official runtime and dependencies for $version..."
        & curl.exe --fail --location --retry 3 --connect-timeout 20 --max-time 600 -o $partial "https://www.shutterencoder.com/$fileName"
        if ($LASTEXITCODE -ne 0) { throw 'Matching official archive unavailable or download failed' }
        $zip = [IO.Compression.ZipFile]::OpenRead($partial); $zip.Dispose()
        Move-Item -LiteralPath $partial -Destination $officialZip
    }
    $portable = Join-Path $run 'portable'
    [IO.Compression.ZipFile]::ExtractToDirectory($officialZip,$portable)
    $candidate = Join-Path $portable 'Shutter Encoder'
    $cfg = [IO.File]::ReadAllText((Join-Path $candidate 'app\Shutter Encoder.cfg'))
    if ($cfg -notmatch ('jpackage.app-version=' + [regex]::Escape($version) + '(\r?\n|$)')) { throw 'Official dependencies do not match source version' }
    Copy-Item -LiteralPath (Join-Path $candidate 'app\Shutter Encoder.jar') -Destination (Join-Path $candidate 'app\Shutter Encoder.original.jar')
    Copy-Item -LiteralPath $compiled -Destination (Join-Path $candidate 'app\Shutter Encoder.jar') -Force
    New-Item -ItemType Directory -Path (Join-Path $candidate 'Functions') -Force | Out-Null
    foreach ($name in @('Shutter Encoder.cfg','Shutter Encoder (OpenGL).cfg')) {
        Add-Content -LiteralPath (Join-Path $candidate "app\$name") -Value 'java-options=--enable-native-access=ALL-UNNAMED'
    }
    & (Join-Path $PSScriptRoot 'Test-AppExit.ps1') -JdkHome $JdkHome -CandidateRoot $candidate -RunRoot (Join-Path $run 'tests')
    if ($ValidateOnly) { Write-Host "VALIDATED_ONLY source=$sourceCommit version=$version"; return }
    $running = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($InstallRoot + '\',[StringComparison]::OrdinalIgnoreCase) -and $_.Name -like 'Shutter Encoder*.exe' })
    if ($running.Count -gt 0) { throw 'Please close Shutter Encoder before installation' }
    $settingsPath = Join-Path $InstallRoot 'settings.xml'
    $settings = $null
    if (Test-Path -LiteralPath $settingsPath) { [xml]$settings = [IO.File]::ReadAllText($settingsPath) }
    $hash = (Get-FileHash -LiteralPath $compiled -Algorithm SHA256).Hash
    & (Join-Path $PSScriptRoot 'Install-Candidate.ps1') -InstallRoot $InstallRoot -CandidateRoot $candidate -ValidateInstalled {
        param($path)
        if ((Get-FileHash -LiteralPath (Join-Path $path 'app\Shutter Encoder.jar') -Algorithm SHA256).Hash -ne $hash) { throw 'Installed application hash differs' }
        $check = [Diagnostics.Process]::new()
        $check.StartInfo.FileName = Join-Path $path 'runtime\bin\java.exe'
        $check.StartInfo.Arguments = '-version'
        $check.StartInfo.UseShellExecute = $false
        $check.StartInfo.CreateNoWindow = $true
        $check.StartInfo.RedirectStandardError = $true
        $null = $check.Start()
        $versionTask = $check.StandardError.ReadToEndAsync()
        if (!$check.WaitForExit(15000)) { $check.Kill(); throw 'Installed runtime check timed out' }
        [IO.File]::WriteAllText((Join-Path $run 'installed-runtime.stderr.log'),$versionTask.GetAwaiter().GetResult())
        if ($check.ExitCode -ne 0) { throw 'Installed runtime does not start' }
    }
    if ($settings) {
        $setting = $settings.SelectSingleNode("//Component[Name='btnDisableUpdate']/Value")
        if ($setting) { $setting.InnerText='true'; $settings.Save($settingsPath) }
    }
    @{sourceCommit=$sourceCommit; version=$version; jarSha256=$hash; repository=$Repository; installedAt=(Get-Date -Format o); log=$log} | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    Write-Host "UPDATE_OK version=$version source=$sourceCommit"
} finally { Stop-Transcript | Out-Null; $updateLock.Dispose() }
