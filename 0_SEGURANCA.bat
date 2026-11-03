@echo off
rem Verificacao de seguranca - SOMENTE LEITURA, nao altera nada. Duplo clique, sem admin.
echo Verificando... pode levar 1 a 3 minutos.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0seguranca.ps1"
pause
