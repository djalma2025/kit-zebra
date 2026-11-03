@echo off
rem Cancela todos os trabalhos presos na fila da Zebra. Duplo clique, sem admin.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$z = Get-Printer | Where-Object { $_.Name -match 'ZDesigner|Zebra|ZD2' };" ^
 "foreach ($p in $z) { $j = @(Get-PrintJob -PrinterName $p.Name); Write-Host ($p.Name + ': ' + $j.Count + ' trabalho(s) na fila'); $j | ForEach-Object { Remove-PrintJob -InputObject $_ -ErrorAction SilentlyContinue } ; Write-Host ('Restantes: ' + @(Get-PrintJob -PrinterName $p.Name).Count) }"
echo.
echo Se ainda restar trabalho na fila: desligue a Zebra, espere 10 segundos e ligue de novo.
pause
