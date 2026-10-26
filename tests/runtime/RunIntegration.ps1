param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExtensionPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [int]$TimeoutSeconds = 45
)
$ErrorActionPreference = 'Stop'
$Godot = (Resolve-Path -LiteralPath $GodotPath).Path
$Extension = (Resolve-Path -LiteralPath $ExtensionPath).Path
$Output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $Output | Out-Null
Copy-Item -LiteralPath $Extension -Destination (Join-Path $Output 'godot_luau.dll')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Integration.gd') -Destination (Join-Path $Output 'Integration.gd')
@'
config_version=5
[application]
config/name="GodotLuauRuntimeQualification"
config/use_custom_user_dir=true
config/custom_user_dir_name="GodotLuauRuntimeQualification"
[threading]
worker_pool/max_threads=2
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $Output 'project.godot') -Encoding ASCII
@'
[configuration]
entry_symbol="luau_extension_init"
compatibility_minimum="4.3"
[libraries]
windows.debug.x86_64="res://godot_luau.dll"
windows.release.x86_64="res://godot_luau.dll"
'@ | Set-Content -LiteralPath (Join-Path $Output 'godot_luau.gdextension') -Encoding ASCII
if (-not ('GodotLuauQualification.NativeErrors' -as [type])) {
    Add-Type -Namespace GodotLuauQualification -Name NativeErrors -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint SetErrorMode(uint Mode);
'@
}
$OldMode = [GodotLuauQualification.NativeErrors]::SetErrorMode(0x8003)
try {
    $Arguments = '--headless --single-threaded-scene --path "' + $Output + '" --script res://Integration.gd'
    $Process = Start-Process -FilePath $Godot -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Output 'stdout.log') -RedirectStandardError (Join-Path $Output 'stderr.log')
    $null = $Process.Handle
    if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $Process.Id -Force
        throw '[Runtime:Integration] Headless integration timed out; only the task-owned process was stopped.'
    }
    $ExitCode = $Process.ExitCode
    Get-Content -LiteralPath (Join-Path $Output 'stdout.log')
    Get-Content -LiteralPath (Join-Path $Output 'stderr.log')
    if ($null -eq $ExitCode -or $ExitCode -ne 0) { throw ('[Runtime:Integration] Exit code ' + $ExitCode) }
    if (-not (Select-String -LiteralPath (Join-Path $Output 'stdout.log') -SimpleMatch '[Runtime:Integration] PASS' -Quiet)) {
        throw '[Runtime:Integration] Required PASS marker missing.'
    }
    if (-not (Select-String -LiteralPath (Join-Path $Output 'stdout.log') -SimpleMatch '[Runtime:Wait] Infinite yield possible' -Quiet)) {
        throw '[Runtime:Integration] Expected unbounded child-wait diagnostic missing.'
    }
} finally {
    [GodotLuauQualification.NativeErrors]::SetErrorMode($OldMode) | Out-Null
}
