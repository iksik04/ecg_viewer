@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

:: Укажите пути к папкам внутри кавычек
set "INPUT_DIR=C:\Users\Public\Work\ECG_DB\VFDB\mit_data"
set "OUTPUT_DIR=C:\Users\Public\Work\ecg_viewer\assets\data\VFDB"

:: Переход в папку с файлами (кавычки обязательны)
cd /d "%INPUT_DIR%"

:: Цикл по файлам. Замените *.hea на ваше расширение, если нужно
for %%F in (*.hea) do (
    echo Обработка: "%%~nF"
    rdsamp.exe -r "%%~nF" -c -p > "%OUTPUT_DIR%\%%~nF.csv"
)

echo Готово!
pause