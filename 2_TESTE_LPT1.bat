@echo off
rem Manda uma etiqueta ZPL crua para a LPT1, o mesmo caminho que o Protheus usa.
rem Rodar como o usuario comum (NAO admin).
echo Mapeamento atual da LPT1:
net use | findstr /i LPT1
echo.
copy /b "%~dp0teste.zpl" LPT1
echo.
echo Se apareceu "1 arquivo(s) copiado(s)" e a etiqueta NAO saiu: o problema esta no compartilhamento ou no driver.
echo Se deu erro de rede ou de dispositivo: a LPT1 nao esta mapeada para este usuario (rodar 4_MAPEAR_LPT1.bat).
pause
