@echo off
chcp 866 >nul
title Обновление сборки Minecraft Pack 1.20.1
setlocal enabledelayedexpansion
rem Терпеливый режим: больше попыток и таймаутов, чем у тихого предзапуска.
set "PL_PATIENT=1"
cd /d "%~dp0"
if not exist "minecraft\_packwiz_update.cmd" (
  echo Не найден minecraft\_packwiz_update.cmd - переустанови сборку из архива.
  pause
  exit /b 0
)
cd /d "%~dp0minecraft"
call "_packwiz_update.cmd" %*
echo.
echo Готово. Синхронизация завершена, можно запускать игру.
pause
exit /b 0
