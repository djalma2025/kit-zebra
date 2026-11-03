# Coleta o estado da cadeia de impressao Zebra (Protheus -> WebAgent -> LPT1 -> compartilhamento -> driver -> USB)
# Rodar como o USUARIO COMUM (nao admin): o net use vale por usuario.
$saida = Join-Path $PSScriptRoot ("diag_" + $env:COMPUTERNAME + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")

function Bloco($titulo, $script) {
    "`r`n===== $titulo =====" | Out-File $saida -Append -Encoding utf8
    try { & $script 2>&1 | Out-String -Width 250 | Out-File $saida -Append -Encoding utf8 }
    catch { "ERRO: $_" | Out-File $saida -Append -Encoding utf8 }
}

Bloco "MAQUINA / USUARIO / ELEVADO" {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adm = (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    "Computador: $env:COMPUTERNAME"; "Usuario: $($id.Name)"; "Elevado (admin): $adm"
    (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber | Format-List | Out-String).Trim()
}
Bloco "NET USE (LPT1 tem de apontar para \\localhost\ZEBRA)" { net use }
Bloco "IMPRESSORAS" { Get-Printer | Select-Object Name, DriverName, PortName, Shared, ShareName, PrinterStatus, Default | Format-Table -AutoSize }
Bloco "PORTAS USB / LPT" { Get-PrinterPort | Where-Object { $_.Name -match 'USB|LPT' } | Select-Object Name, Description | Format-Table -AutoSize }
Bloco "DRIVERS ZEBRA" { Get-PrinterDriver | Where-Object { $_.Name -match 'Zebra|ZDesigner|ZD2' } | Select-Object Name, MajorVersion, DriverVersion, Manufacturer | Format-Table -AutoSize }
Bloco "FILA DE IMPRESSAO (trabalhos travados)" { Get-Printer | Where-Object { $_.Name -match 'Zebra|ZDesigner|ZD2' } | ForEach-Object { "--- $($_.Name)"; Get-PrintJob -PrinterName $_.Name | Select-Object Id, DocumentName, JobStatus, SubmittedTime | Format-Table -AutoSize } }
Bloco "SERVICO SPOOLER" { Get-Service Spooler | Select-Object Status, StartType | Format-List }
Bloco "DISPOSITIVO USB ZEBRA (Gerenciador de Dispositivos)" { Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match 'Zebra|ZDesigner|ZD2|Impress|Printer|USB Printing' } | Select-Object Status, Class, FriendlyName | Format-Table -AutoSize }
Bloco "WEBAGENT (processo e porta em escuta)" {
    $procs = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'web-?agent' }
    if (-not $procs) { "NENHUM processo WebAgent rodando" }
    $escuta = netstat -ano | Select-String LISTENING
    foreach ($p in $procs) {
        "PID $($p.ProcessId)  $($p.CommandLine)"
        $portas = $escuta | Where-Object { [int](($_.Line.Trim() -split '\s+')[-1]) -eq $p.ProcessId } | ForEach-Object { ($_.Line.Trim() -split '\s+')[1] }
        if ($portas) { "  em escuta: $($portas -join ', ')" } else { "  SEM porta em escuta (webapp fechado, ou agente vivo sem listener)" }
    }
    Get-ChildItem "$env:LOCALAPPDATA\Programs\web-agent*\package.json" -ErrorAction SilentlyContinue | ForEach-Object {
        $v = (Get-Content $_.FullName -Raw | ConvertFrom-Json).version
        "Instalado: $($_.DirectoryName)  versao $v  (release 2510 exige 1.1.1)"
    }
}
Bloco "COMPARTILHAMENTO DE ARQUIVOS E IMPRESSORAS (servico Server)" { Get-Service LanmanServer | Select-Object Status, StartType | Format-List }

Write-Host ""
Write-Host "Diagnostico gravado em:" -ForegroundColor Green
Write-Host $saida
