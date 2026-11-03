@echo off
rem Rodar com DUPLO CLIQUE, como o usuario comum (NAO "executar como administrador")
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnostico.ps1"
pause
