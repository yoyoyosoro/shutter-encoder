# Shutter Encoder custom

This fork keeps the upstream application's copyright and license and removes the exit donation prompt for local use. The product patch is limited to `Utils.exitApp(boolean)`; settings saving and cleanup remain intact. The original binary JAR in the repository is a dependency/resource packaging input, and must be rebuilt to obtain the modified application.

## Updating

1. Open this fork's **Actions → Merge upstream into custom → Run workflow**, using the default `master` branch for the workflow. Wait for the green success indicator. Conflicts, compilation failures, or a donation call in the compiled exit method stop the workflow before it pushes `custom`.
2. Close Shutter Encoder and double-click the local **Shutter Encoder 更新（无捐款弹窗）** shortcut. It downloads `custom`, compiles it, uses the vendor's exact-version Windows portable runtime and dependencies, and performs three real desktop exit tests and an H.264 dependency test before replacing the local application.

The local installation stays in `C:\Program Files (x86)\Shutter Encoder`. Its settings, personal Functions, LUTs and local model files are preserved. Backups and logs stay inside its `maintenance` folder. Official updates replace this modification, so the updater keeps official update checks disabled.

GitHub verification inspects the compiled exit method; real GUI tests happen locally, where a desktop is available. A successful cloud build alone does not install anything. No scheduled updates, tokens stored locally, or changes to the upstream author's repository are required.

## Building manually

From a Windows PowerShell session with a Java 25 JDK:

```powershell
./.custom/Build.ps1 -JdkHome 'C:\path\to\jdk25' -OutputJar 'C:\build\Shutter Encoder.jar'
```

The updater requires the retained JDK under `maintenance\tools\jdk25`. New upstream Java requirements or a changed exit-button interface may require updating the maintenance tools. Stop on a failure and keep using the previously installed version.
