param([Parameter(Mandatory=$true)][string]$JdkHome,[Parameter(Mandatory=$true)][string]$JarPath)
$ErrorActionPreference = 'Stop'
$bytecode = (& (Join-Path $JdkHome 'bin\javap.exe') -c -p -classpath $JarPath shutterencoder.utils.Utils) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect compiled application' }
$method = [regex]::Match($bytecode, '(?ms)^  public static void exitApp\(boolean\);\r?\n(.*?)(?=^  \S|\z)')
if (!$method.Success) { throw 'Cannot find exitApp; upstream exit flow needs review' }
if ($method.Value -match 'ui/others/Donate|checkMailAddress|showDonateWindow') { throw 'Donation code remains in compiled exit flow' }
foreach ($required in @('Settings.saveSettings','killProcesses','java/lang/System.exit')) {
    if (!$method.Value.Contains($required)) { throw "Exit contract missing: $required" }
}
'BYTECODE_NO_DONATE_OK'
