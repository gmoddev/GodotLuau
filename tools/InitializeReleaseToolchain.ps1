$ErrorActionPreference = 'Stop'
$TaskVsWhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$TaskInstallation = & $TaskVsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $TaskInstallation) { throw '[Release:Toolchain] MSVC unavailable' }
$TaskBatch = Join-Path $env:RUNNER_TEMP 'PrepareReleaseToolchain.cmd'
$TaskVcVars = Join-Path $TaskInstallation 'VC/Auxiliary/Build/vcvars64.bat'
[IO.File]::WriteAllText($TaskBatch, "@echo off`r`ncall `"$TaskVcVars`" >nul`r`nif errorlevel 1 exit /b 1`r`nset`r`n")
$TaskEnvironment = & cmd.exe /d /c $TaskBatch
if ($LASTEXITCODE -ne 0) { throw '[Release:Toolchain] MSVC environment initialization failed' }
$TaskAllowed = @('PATH','INCLUDE','LIB','LIBPATH','VCToolsInstallDir','VCToolsVersion','VSINSTALLDIR','WindowsSdkDir','WindowsSDKVersion','VSCMD_ARG_TGT_ARCH')
foreach ($TaskLine in $TaskEnvironment) {
    if ($TaskLine -notmatch '^([^=]+)=(.*)$') { continue }
    $TaskName = $Matches[1]; $TaskValue = $Matches[2]
    if ($TaskName -notin $TaskAllowed) { continue }
    if ($TaskValue -match '[\r\n]') { throw '[Release:Toolchain] Invalid toolchain environment value' }
    if ($TaskName -eq 'PATH') {
        $TaskRuntime = Get-ChildItem -Path "$TaskInstallation/VC/Redist/MSVC/*/debug_nonredist/x64/Microsoft.VC*.DebugCRT" -Directory | Sort-Object FullName | Select-Object -Last 1
        if (-not $TaskRuntime) { throw '[Release:Toolchain] Installed MSVC Debug CRT unavailable' }
        $TaskValue = "$($TaskRuntime.FullName);$TaskValue"
    }
    "$TaskName=$TaskValue" | Out-File -LiteralPath $env:GITHUB_ENV -Append -Encoding utf8
}
Write-Output '[Release:Toolchain] Existing MSVC x64 environment and Debug CRT selected'
