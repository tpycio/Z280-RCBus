# Z280 serial bootstrap code

Example bootstrap code, loading the CP/M 2.2 operating system from a CF disk with the structure used in SCM. You can also use bootstrap code from the [ZZRCC](https://www.retrobrewcomputers.org/doku.php?id=builderpages:plasmo:zzrcc) project to load RomWBW, the bootstrap procedure is available on the [retro-comp](https://groups.google.com/g/retro-comp/c/29DOV4eO6MU/m/IofuysixAgAJ) group. 

The plan is to build software to load RomWBW without intermediate steps.

The development environment for compiling the code is available in the [RomWBW](https://github.com/wwarthen/RomWBW) project in the /Tools folder.

`tasm.exe -t280 -a -g0 bootstrap.z80`