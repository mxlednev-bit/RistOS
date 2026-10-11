RistOS 0.1.1 - HOTFIX manifest sizes (OpenComputers / GravityCraft)

Root cause: Git normalized CRLF to LF on published text files.
Vector.lua is 2006 bytes on GitHub, but the old manifest expects 2077 bytes.
Spanish.lang in VK.app similarly changed from 4708 to 4529 bytes.

DO NOT overwrite or delete RistOS/ or other data.
1. Extract this hotfix ZIP into F:\GitHub\RistOS\ (the Git repository root).
2. MERGE Installer/ and replace files with same names.
3. In GitHub Desktop, Commit to main, then Push origin.
4. In OpenOS, download the new unique installer URL:
   wget -f https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/Installer/Install_v0_1_1.lua /tmp/ristos_install_011.lua
5. Resume: 
   /tmp/ristos_install_011.lua https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/RistOS/ lite
6. Select the same HDD and type INSTALL. Existing files with correct sizes are skipped.

The installation does not flash EEPROM and does not format the disk.
After successful file installation, do not reboot expecting RistOS to start until a bootloader has been configured.
Full installation uses the same installer with full instead of lite, requiring more disk space.
