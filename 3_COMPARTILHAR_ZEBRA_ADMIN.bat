@echo off
rem Rodar com botao direito > "Executar como administrador".
rem Compartilha a Zebra com o nome ZEBRA (o que a LPT1 espera).
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$z = @(Get-Printer | Where-Object { $_.Name -match 'ZDesigner|Zebra|ZD2' });" ^
 "if ($z.Count -eq 0) { Write-Host 'Nenhuma impressora Zebra instalada.' -ForegroundColor Red; exit }" ^
 "$z | Select-Object Name, PortName, Shared, ShareName, PrinterStatus | Format-Table -AutoSize;" ^
 "if ($z.Count -gt 1) { $n = Read-Host 'Mais de uma Zebra (ex.: Copia 1 apos trocar a impressora). Digite o NOME exato da que esta na USB em uso' } else { $n = $z[0].Name };" ^
 "Get-Printer | Where-Object { $_.ShareName -eq 'ZEBRA' -and $_.Name -ne $n } | ForEach-Object { Set-Printer -Name $_.Name -Shared $false; Write-Host ('Removido compartilhamento ZEBRA de: ' + $_.Name) };" ^
 "Set-Printer -Name $n -Shared $true -ShareName 'ZEBRA';" ^
 "Get-Printer -Name $n | Select-Object Name, PortName, Shared, ShareName | Format-List"
echo.
echo Agora feche esta janela e rode o 4_MAPEAR_LPT1.bat SEM ser administrador.
pause
