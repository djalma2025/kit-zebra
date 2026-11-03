# Limpeza pos-golpe "falso Cloudflare" (ClickFix) - rodar como o usuario comum, sem admin.
# 1) mata e apaga os scripts do golpe no TEMP (so os que tem a assinatura dele)
# 2) lista extensoes e notificacoes permitidas do Chrome/Edge (o que pode reabrir a pagina falsa)
# 3) fecha o navegador e abre a tela "Redefinir configuracoes" (1 clique) do Chrome
# 4) inicia a verificacao rapida do Defender
param([switch]$SoTestar)   # -SoTestar: so relata, nao fecha navegador, nao apaga, nao abre telas

$saida = Join-Path $PSScriptRoot ("limpeza_" + $env:COMPUTERNAME + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")
function Log($t) { $t | Out-File $saida -Append -Encoding utf8; Write-Host $t }
$assinatura = '23\.94\.145\.243|392073715|VirtualAlloc|R964086'

Log "Limpeza em $(Get-Date)  usuario $env:USERNAME  maquina $env:COMPUTERNAME  modo: $(if ($SoTestar) {'SO TESTE'} else {'LIMPEZA'})"

Log "`r`n===== 1. SCRIPTS DO GOLPE NO TEMP ====="
$golpe = Get-ChildItem $env:TEMP -Filter *.ps1 -File -Force -ErrorAction SilentlyContinue |
    Where-Object { Select-String -Path $_.FullName -Pattern $assinatura -Quiet -ErrorAction SilentlyContinue }
if (-not $golpe) { Log "nenhum script do golpe encontrado" }
foreach ($g in $golpe) {
    $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*$($g.Name)*" -and $_.ProcessId -ne $PID }
    foreach ($p in $procs) {
        Log "processo do golpe rodando: PID $($p.ProcessId)"
        if (-not $SoTestar) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; Log "  -> finalizado" }
    }
    Log "script do golpe: $($g.FullName)  ($($g.Length) bytes, criado $($g.CreationTime))"
    if (-not $SoTestar) { Remove-Item $g.FullName -Force -ErrorAction SilentlyContinue; Log ("  -> " + $(if (Test-Path $g.FullName) {'NAO apagou'} else {'apagado'})) }
}

Log "`r`n===== 2. NAVEGADORES: EXTENSOES E NOTIFICACOES PERMITIDAS ====="
$navs = @(
    @{ Nome = 'Chrome'; Base = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
    @{ Nome = 'Edge';   Base = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" }
)
foreach ($n in $navs) {
    if (-not (Test-Path $n.Base)) { continue }
    $perfis = Get-ChildItem $n.Base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' }
    foreach ($pf in $perfis) {
        Log "--- $($n.Nome) / $($pf.Name)"
        $ext = Join-Path $pf.FullName 'Extensions'
        if (Test-Path $ext) {
            Get-ChildItem $ext -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'Temp' } | ForEach-Object {
                $mf = Get-ChildItem $_.FullName -Recurse -Filter manifest.json -ErrorAction SilentlyContinue | Select-Object -First 1
                $nome = '?'
                if ($mf) { try { $nome = (Get-Content $mf.FullName -Raw | ConvertFrom-Json).name } catch {} }
                if ($mf -and $nome -match '^__MSG_(.+)__$') {
                    $chave = $Matches[1]
                    foreach ($loc in 'pt_BR', 'en', 'en_US') {
                        $msgs = Join-Path $mf.DirectoryName "_locales\$loc\messages.json"
                        if (Test-Path $msgs) {
                            try {
                                $m = Get-Content $msgs -Raw -Encoding UTF8 | ConvertFrom-Json
                                $p = $m.PSObject.Properties | Where-Object { $_.Name -ieq $chave } | Select-Object -First 1
                                if ($p) { $nome = $p.Value.message; break }
                            } catch {}
                        }
                    }
                }
                Log ("  extensao: {0}  instalada {1:dd/MM/yyyy HH:mm}  id {2}" -f $nome, $_.CreationTime, $_.Name)
            }
        }
        $pref = Join-Path $pf.FullName 'Preferences'
        if (Test-Path $pref) {
            try {
                $j = Get-Content $pref -Raw | ConvertFrom-Json
                $notif = $j.profile.content_settings.exceptions.notifications
                if ($notif) {
                    $notif.PSObject.Properties | Where-Object { $_.Value.setting -eq 1 } | ForEach-Object { Log "  NOTIFICACAO PERMITIDA: $($_.Name)" }
                }
            } catch { Log "  (nao consegui ler Preferences: $_)" }
        }
    }
}

Log "`r`n===== 3. REDEFINIR NAVEGADOR ====="
$chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($SoTestar) { Log "modo teste: nao fecha nem abre o navegador" }
elseif ($chrome) {
    Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process $chrome 'chrome://settings/resetProfileSettings'
    Log "Chrome fechado e aberto na tela de Redefinir: clicar em 'Redefinir configuracoes'"
} else { Log "Chrome nao encontrado" }

Log "`r`n===== 4. ANTIVIRUS ====="
if ($SoTestar) { Log "modo teste: nao inicia verificacao" }
else {
    try { Start-MpScan -ScanType QuickScan -AsJob | Out-Null; Log "verificacao rapida do Defender iniciada em segundo plano" }
    catch { Start-Process 'windowsdefender://threat'; Log "sem permissao para iniciar pelo script: abri a tela, clicar em 'Verificacao rapida'" }
}

Log "`r`n===== FALTA FAZER A MAO (o script nao alcanca) ====="
Log "- WhatsApp: no CELULAR do setor > Aparelhos conectados > desconectar este PC e conectar de novo pelo QR"
Log "- Se houver senha salva no navegador (Protheus, e-mail): trocar a senha"
Log "`r`nRelatorio em: $saida"
