;=====================================================================================
;  Z280 Bootstrap Loader 1.1
;  Copyright (c) 2023,2026 by Tadeusz Pycio
;=====================================================================================

; Setings for IDE CF
;
; CF registers
CFBASE        .equ   010h
CF_DATA       .equ   CFBASE + 00h      ; IDE Data Port (R/W)
CF_FEATURES   .equ   CFBASE + 01h      ; Features (W)
CF_ERROR      .equ   CFBASE + 01h      ; Error register (R)
CF_SECCOUNT   .equ   CFBASE + 02h      ; Sector count (R/W)
CF_SECTOR     .equ   CFBASE + 03h      ; Sector (R/W, CHS mode)
CF_CYL_LOW    .equ   CFBASE + 04h      ; Cylinder LOW (R/W, CHS mode)
CF_CYL_HI     .equ   CFBASE + 05h      ; Cylinder HIGH (R/W, CHS mode)
CF_HEAD       .equ   CFBASE + 06h      ; Head (R/W, CHS mode)
CF_STATUS     .equ   CFBASE + 07h      ; Status (R)
CF_COMMAND    .equ   CFBASE + 07h      ; Command (W)
CF_LBA0       .equ   CFBASE + 03h      ; LBA bits 0-7 (R/W, LBA mode)
CF_LBA1       .equ   CFBASE + 04h      ; LBA bits 8-15 (R/W, LBA mode)
CF_LBA2       .equ   CFBASE + 05h      ; LBA bits 16-23 (R/W, LBA mode)
CF_LBA3       .equ   CFBASE + 06h      ; LBA bits 24-27 (R/W, LBA mode)

;CF Features
CF_8BIT       .equ   1
CF_NOCACHE    .equ   082h

;CF Commands
CF_READ_SEC   .equ  020h
CF_WRITE_SEC  .equ  030h
CF_IDENTIFY   .equ  0ECh
CF_SET_FEAT   .equ  0EFh

;
; Z280 CPU control registers (via LDCTL)
CPU_IOPR      .equ  08h                ; I/O PAGE REG
CPU_CCR       .equ  12h                ; CACHE CONTROL REG
;
; Z280 page 0xFF register addresses
RRREG         .equ  0E8h               ; Z280 REFRESH RATE REG


;=============================================================================
              .org  0
              ld    sp, 0C000h          ; initialize stack pointer
;-----------------------------------------------------------------------------
; Init CF
              call  cf_ready           ; card ready after power-up
              ld    A,0E0h             ; set LBA mode
              out   (CF_LBA3),A
              ld    a, CF_8BIT         ; set feature to 8-bit interface
              out   (CF_FEATURES), a   ; store feature code
              ld    a, CF_SET_FEAT     ; get set features command
              out   (CF_COMMAND), a    ; perform set features
              call  cf_ready

cf_wait:      in    a,(CF_STATUS)      ; status register.
              and   80h                ; checking bit 7: BSY, "1" means the drive is busy.
              jp    nz, cf_wait
;-----------------------------------------------------------------------------
; Disk OS loader
;
NumSectors    .equ  24
LoadAddr      .equ  0D000h


bootcf:       ld    e,NumSectors       ;Number of physical sectors
              ld    d,0                ;First sector number
              ld    hl,LoadAddr        ;Code from compact flash loads here
; Read sectors where one sector is 4 x 128 byte blocks = 512 bytes
readSec:      ld    a,d                ;Get sector number
              out   (CF_LBA0),a        ;Set sector number
              xor   a                  ;Set up LBA parameters
              out   (CF_LBA1),a
              out   (CF_LBA2),a
              ld    a,0E0h
              out   (CF_LBA3),a
              ld    a,1                ;Get number if sectors to read
              out   (CF_SECCOUNT),a    ;Store sector count
              ld    a,CF_READ_SEC      ;Get read sectors command
              out   (CF_COMMAND),a     ;Perform sector(s) read
              call  cf_ready           ; A = status, BSY=0
              bit   3,a                ; DRQ?
              jr    z,readSec          ; error (ERR, no data) - retry sector
              ld    c,CF_DATA          ;Compact flash data register
              ld    b,0                ; sector has 512 8-bit data
              inir                     ;(HL)=(C), HL=HL+1, B=B-1, repeat
              inir
              inc   d                  ;Increment sector number
              dec   e
              jr    nz,readSec         ;Repeat for all required sectors
;-----------------------------------------------------------------------------
              ld    c,CPU_IOPR         ; reg C points to I/O page register
              ld    l,0FFh             ; Page I/O is 0xFF
              ldctl (c),hl             ; write to I/O page register
              xor   a
              out   (RRREG),a          ; disable refresh

;              ld    c, CPU_CCR         ; reg C points to Cache Control Register
;              ld    l,0E0h             ; disable cache memory
;              ldctl (c),hl             ; write to Cache Control Register
              ld    c, CPU_CCR         ; reg C points to Cache Control Register
              ldctl hl,(c)
              ld    a,l
              or    01100000b          ; disable instruction and data cache
              ld    l,a
              ldctl (c),hl             ; write to Cache Control Register


              ld    c,CPU_IOPR         ; reg C points to I/O page register
              ld    l,0                ; Page I/O is 0x00
              ldctl (c),hl             ; write to I/O page register

;-----------------------------------------------------------------------------
; Start CP/M using entry at top of BIOS
              ld    hl,(0FFFEh)        ;Get start up address
              jp    (hl)               ;Run code downloaded from compact flash

;-----------------------------------------------------------------------------
; wait for BSY=0 and RDY=1, returns current status in A
cf_ready:     in    a,(CF_STATUS)      ; first read discarded (400 ns rule)
cf_rdy1:      in    a,(CF_STATUS)
              and   0C0h
              cp    040h
              jr    nz,cf_rdy1
              in    a,(CF_STATUS)
              ret
;-----------------------------------------------------------------------------
endload:     .equ  $
         .IF  endload <= 0100h
              .fill  (0100h - endload),0FFh        ; Pad bootstrap buffer to 256B in length.
         .ELSE
              .echo  "*** Bootstap code is "
              .echo  (endload - 0100h)
              .echo  " byte(s) too long. MUST BE EXACTLY 256 bytes long ***\n"
         .ENDIF
              .end
