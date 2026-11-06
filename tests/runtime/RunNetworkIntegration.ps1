param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectDirectory,
    [ValidateSet('Dedicated', 'Listen', 'Editor')][string]$Mode = 'Dedicated',
    [int]$TimeoutSeconds = 30
)
$ErrorActionPreference = 'Stop'
$Godot = (Resolve-Path -LiteralPath $GodotPath).Path
$Project = (Resolve-Path -LiteralPath $ProjectDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $Project 'godot_luau.dll'))) { throw 'RunIntegration must prepare this isolated project first.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'NetworkIntegration.gd') -Destination (Join-Path $Project 'NetworkIntegration.gd')
$Probe = New-Object System.Net.Sockets.UdpClient(0)
$Port = $Probe.Client.LocalEndPoint.Port
$Probe.Dispose()
if ($Mode -eq 'Editor') {
    $Probe = New-Object System.Net.Sockets.UdpClient(25575)
    $Probe.Dispose()
    $Port = 25575
}
if (Test-Path -LiteralPath (Join-Path $Project 'server.ready')) { Remove-Item -LiteralPath (Join-Path $Project 'server.ready') }
if (-not ('GodotLuauNetworkQualification.NativeErrors' -as [type])) {
    Add-Type -Namespace GodotLuauNetworkQualification -Name NativeErrors -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint SetErrorMode(uint Mode);
'@
}
$OldMode = [GodotLuauNetworkQualification.NativeErrors]::SetErrorMode(0x8003)
$Processes = @()
function StartFixture([string]$Role, [string]$Label, [string]$Extra) {
    $Arguments = '--headless --single-threaded-scene --path "' + $Project + '" --script res://NetworkIntegration.gd -- --fixture-role ' + $Role + ' --fixture-port ' + $Port + ' ' + $Extra
    $Process = Start-Process -FilePath $Godot -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Project ($Label + '.stdout.log')) -RedirectStandardError (Join-Path $Project ($Label + '.stderr.log'))
    $null = $Process.Handle
    return [pscustomobject]@{Process=$Process; Label=$Label; Role=$Role}
}
try {
    if ($Mode -eq 'Listen') {
        $Processes += StartFixture 'listen' 'listen' ''
    } else {
        $ServerArguments = if ($Mode -eq 'Editor') { '--glindex 1 --glcount 2 --gldevice PC' } else { '--glserver ' + $Port }
        $Processes += StartFixture 'server' 'server' $ServerArguments
        $Deadline = (Get-Date).AddSeconds(10)
        while (-not (Test-Path -LiteralPath (Join-Path $Project 'server.ready'))) {
            if ($Processes[0].Process.HasExited -or (Get-Date) -gt $Deadline) { throw '[Runtime:NetworkTest] Server failed to become ready.' }
            Start-Sleep -Milliseconds 100
        }
        $Client1Arguments = if ($Mode -eq 'Editor') { '--glindex 2 --glcount 2 --gldevice PC' } else { '--glconnect 127.0.0.1:' + $Port }
        $Client2Arguments = if ($Mode -eq 'Editor') { '--glindex 3 --glcount 2 --gldevice PC' } else { '--glconnect 127.0.0.1:' + $Port }
        $Processes += StartFixture 'client' 'client1' $Client1Arguments
        $Processes += StartFixture 'client' 'client2' $Client2Arguments
    }
    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    foreach ($Entry in $Processes) {
        $Remaining = [Math]::Max(0, [int](($Deadline - (Get-Date)).TotalMilliseconds))
        if (-not $Entry.Process.WaitForExit($Remaining)) { throw ('[Runtime:NetworkTest] Timeout: ' + $Entry.Label) }
        Get-Content -LiteralPath (Join-Path $Project ($Entry.Label + '.stdout.log'))
        Get-Content -LiteralPath (Join-Path $Project ($Entry.Label + '.stderr.log'))
        if ($Entry.Process.ExitCode -ne 0) { throw ('[Runtime:NetworkTest] Failed: ' + $Entry.Label + ' Exit=' + $Entry.Process.ExitCode) }
        $Marker = '[Runtime:NetworkTest] ' + $Entry.Role + ' PASS'
        if (-not (Select-String -LiteralPath (Join-Path $Project ($Entry.Label + '.stdout.log')) -SimpleMatch $Marker -Quiet)) { throw ('[Runtime:NetworkTest] Missing result: ' + $Entry.Label) }
    }
} finally {
    foreach ($Entry in $Processes) { if (-not $Entry.Process.HasExited) { Stop-Process -Id $Entry.Process.Id -Force } }
    [GodotLuauNetworkQualification.NativeErrors]::SetErrorMode($OldMode) | Out-Null
}
