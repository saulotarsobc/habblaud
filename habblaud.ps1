param(
    [ValidateSet('Install', 'Start', 'Stop', 'Status', 'Logs', 'Bridge', 'RemoveStartup')]
    [string]$Action = 'Start'
)
$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$taskName = 'Habblaud-Codex-Bridge'
$logDir = Join-Path $projectDir '.local'
Set-Location -LiteralPath $projectDir

function Invoke-Npm {
    & npm @args
    if ($LASTEXITCODE -ne 0) { throw "npm falhou: $args" }
}

switch ($Action) {
    'Install' {
        & docker info --format '{{.ServerVersion}}'
        if ($LASTEXITCODE -ne 0) { throw 'Abra o Docker Desktop e tente novamente.' }
        if (!(Test-Path 'node_modules/tsx')) { Invoke-Npm ci }
        & node --import tsx scripts/codex-windows.ts install
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar os hooks.' }
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        # Caminhos resolvidos no momento da instalação, sem depender do PATH do Agendador.
        @{
            node = (Get-Command node.exe).Source
            codex = (Get-Command codex.exe).Source
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logDir 'runtime.json') -Encoding UTF8
        $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Action Bridge' -f $PSCommandPath) -WorkingDirectory $projectDir
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
        $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        & $PSCommandPath -Action Start
    }
    'Start' {
        Invoke-Npm run docker:up
        Start-ScheduledTask -TaskName $taskName
        Write-Host 'Habblaud: http://localhost:4747'
    }
    'Stop' {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Invoke-Npm run docker:down
    }
    'Status' {
        & docker compose ps
        & node --import tsx scripts/codex-windows.ts status
        Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State
        if (Test-Path (Join-Path $logDir 'bridge.log')) { Get-Content (Join-Path $logDir 'bridge.log') -Tail 8 }
    }
    'Logs' { & docker compose logs --tail 100 -f habblaud }
    'RemoveStartup' {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    'Bridge' {
        $mutex = New-Object System.Threading.Mutex($false, 'Local\HabblaudCodexBridge')
        if (!$mutex.WaitOne(0)) { exit 0 }
        try {
            $runtime = Get-Content -LiteralPath (Join-Path $logDir 'runtime.json') -Raw | ConvertFrom-Json
            $env:HABBLAUD_CODEX_BIN = $runtime.codex
            $env:PATH = (Split-Path $runtime.node) + ';' + (Split-Path $runtime.codex) + ';' + $env:PATH
            while ($true) {
                # Limita o log entre reinicializações do auxiliar.
                $logFile = Join-Path $logDir 'bridge.log'
                if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 5MB) {
                    Move-Item -LiteralPath $logFile -Destination ($logFile + '.old') -Force
                }
                & $runtime.node --import tsx scripts/codex-bridge.ts *>> $logFile
                Start-Sleep -Seconds 5
            }
        } finally {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }
}
