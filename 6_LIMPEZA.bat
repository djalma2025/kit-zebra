@echo off
rem Limpeza pos-golpe. Duplo clique, sem admin. FECHA O CHROME - salve o que estiver aberto.
echo Este script vai FECHAR o Chrome. Salve o que estiver aberto no navegador.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0limpeza.ps1"
pause
