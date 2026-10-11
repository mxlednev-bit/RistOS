RistOS 0.1.2 — исправление скачивания ярлыков (OpenOS / GravityCraft)

При установке 0.1.1 CDN возвращает 9 байт вместо 25 байт файла
Users/Rist/Desktop/Finder.lnk. Это не повод удалять HDD или OpenOS.

Версия 0.1.2 создаёт три штатных ярлыка рабочего стола локально:
  Finder.lnk
  MineCode IDE.lnk
  Rist Control.lnk
Для прочих файлов продолжает загрузку по HTTPS с проверкой размера.
Использует исправленный манифест FilesLite_v0_1_1.lua, уже опубликованный.

УСТАНОВКА:
1. Распакуй ZIP в корень своего GitHub-репозитория F:\GitHub\RistOS\.
   Итоговый путь: F:\GitHub\RistOS\Installer\Install_v0_1_2.lua
2. GitHub Desktop: Commit to main -> Push origin.
3. Проверь файл на github.com/mxlednev-bit/RistOS/blob/main/Installer/Install_v0_1_2.lua
4. В OpenOS:
   wget -f https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/Installer/Install_v0_1_2.lua /tmp/ristos012.lua
   /tmp/ristos012.lua https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/RistOS/ lite
5. Выбери HDD 1 и введи INSTALL. Установленные файлы с верным размером будут пропущены.

Скрипт не форматирует HDD и не перепрошивает EEPROM. Не удаляет
существующие OpenOS-файлы; совпадающие по пути файлы может перезаписать.
После окончания НЕ перепрошивай EEPROM до отдельной проверки загрузчика.
