# Z280 serial bootstrap code

Example bootstrap code `BOOTSTRAP.ASM`, loading the CP/M 2.2 operating system from a CF disk with the structure used in SCM.

# Loading RomWBW Using the Z280 Bootstrap in a ROM-less Environment

<mark>PLEASE NOTE</mark>: From RomWBW version 3.7.0-dev.16 onwards, there is an `RCZ280_RCBUS_STD` profile which includes the fixes described. Simply build RomWBW and save the `RCZ280_rcbus_std_hd1k_combo.img` image to a CF card.



Procedure for loading RomWBW using the Z280 bootstrap in a ROM-less environment with a CF card, IO=0x10.

1. Build the bootstrap program `RWBOOT.ASM` and load it into the microcontroller's EEPROM.

2. Modify the RomWBW package file `RCZ280_zzrcc_std.asm` in the `/Source/HBIOS/Config` folder to ensure compatibility with the modules:
   
   ```asm
   ; -CPUOSC .SET 29491200 ; CPU OSC FREQ IN HZ
   +CPUOSC .SET 18432000 ; CPU OSC FREQ IN HZ
   ```
   
   ```asm
   ; -Z2UOSC .SET (CPUOSC / 16) ; Z2U: OSC FREQUENCY IN MHZ
   ; -Z2U0HFC .SET TRUE ; Z2U0: ENABLE HARDWARE FLOW CONTROL
   ```

3. Build RomWBW for RCZ280 ZZRCC.

4. Modify the resulting disk image, `/Binary/RCZ280_zzrcc_std_hd1k_combo.img`, using a hex editor. Replace the bytes at addresses `0x240EF–0x240FF`, which are filled with `0xFF`, with the following:
   
   ```text
   ED BF ED B7 CB 7C 20 FA 2E 00 0E 08 ED 6E C3 00 00
   ```
   
   This is the hexadecimal representation of the compiled `FINAL` routine from the `RWBOOT.ASM` bootloader.

5. Write the prepared disk image to the storage medium.

6. Start the system.
