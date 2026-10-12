param([Parameter(Mandatory=$true)][string]$JdkHome,[Parameter(Mandatory=$true)][string]$CandidateRoot,[Parameter(Mandatory=$true)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$jar = Join-Path $CandidateRoot 'app\Shutter Encoder.jar'
$classes = Join-Path $RunRoot 'probe-classes'
$profile = Join-Path $RunRoot 'profile'
New-Item -ItemType Directory -Path $classes,$profile -Force | Out-Null
& (Join-Path $JdkHome 'bin\javac.exe') -encoding UTF-8 --release 25 -cp $jar -d $classes (Join-Path $PSScriptRoot 'ExitPopupProbe.java')
if ($LASTEXITCODE -ne 0) { throw 'Exit regression probe compilation failed' }
$seed = '<Settings><Component><Type>JCheckBox</Type><Name>btnDisableUpdate</Name><Value>true</Value><Enable>true</Enable><Visible>true</Visible></Component></Settings>'
foreach ($scenario in @('close','alternate','email')) {
    [IO.File]::WriteAllText((Join-Path $CandidateRoot 'settings.xml'), $seed, [Text.UTF8Encoding]::new($false))
    $stdout = Join-Path $RunRoot "$scenario.stdout.log"
    $stderr = Join-Path $RunRoot "$scenario.stderr.log"
    $arguments = @('-Xmx4G','--enable-native-access=ALL-UNNAMED',('"-Duser.home=' + $profile + '"'),'-Duser.language=en','-Duser.country=US','-Djavax.accessibility.assistive_technologies=','-cp',('"' + $classes + ';' + $jar + '"'),'ExitPopupProbe',$scenario)
    $child = Start-Process -FilePath (Join-Path $CandidateRoot 'runtime\bin\java.exe') -ArgumentList $arguments -WorkingDirectory $CandidateRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (!$child.WaitForExit(45000)) { $child.Kill(); throw "Exit regression timed out: $scenario" }
    $child.Refresh()
    $output = [IO.File]::ReadAllText($stdout)
    $errors = [IO.File]::ReadAllText($stderr)
    if ($child.ExitCode -ne 0 -or $output -notmatch 'STARTUP_OK' -or $output -notmatch 'CLOSE_TRIGGERED' -or $errors -match 'Exception|FAIL:') {
        throw "Exit regression failed: $scenario (exit $($child.ExitCode)). $errors"
    }
    [xml]$settings = [IO.File]::ReadAllText((Join-Path $CandidateRoot 'settings.xml'))
    if ($settings.DocumentElement.Name -ne 'Settings') { throw 'Settings were not saved' }
    "EXIT_TEST_OK $scenario"
}
& (Join-Path $CandidateRoot 'app\Library\ffmpeg.exe') -hide_banner -loglevel error -f lavfi -i 'testsrc=size=192x108:rate=25' -t 1 -c:v libx264 -pix_fmt yuv420p -y (Join-Path $RunRoot 'smoke.mp4')
if ($LASTEXITCODE -ne 0) { throw 'H.264 dependency smoke test failed' }
$probe = (& (Join-Path $CandidateRoot 'app\Library\ffprobe.exe') -v error -show_entries 'stream=codec_name,width,height:format=duration' -of json (Join-Path $RunRoot 'smoke.mp4')) -join "`n" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $probe.streams[0].codec_name -ne 'h264' -or $probe.streams[0].width -ne 192 -or $probe.format.duration -ne '1.000000') { throw 'Encoded output validation failed' }
'ENCODING_TEST_OK'
