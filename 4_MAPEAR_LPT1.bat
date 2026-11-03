@echo off
rem Rodar com DUPLO CLIQUE, como o usuario que usa o Protheus (NAO admin):
rem o net use vale por usuario, e o mapeamento feito como admin nao aparece para o usuario comum.
net use LPT1 /delete /y >nul 2>&1
net use LPT1 \\localhost\ZEBRA /persistent:yes
echo.
net use | findstr /i LPT1
echo.
echo Depois rode o 2_TESTE_LPT1.bat.
pause
