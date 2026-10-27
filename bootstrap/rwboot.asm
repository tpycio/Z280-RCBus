	TITLE	Z280 bootstrap - RomWBW image from CF to RAM by DMA0
	.Z280
;=====================================================================================
;  Z280 Bootstrap RomWBW loader 1.0
;  Copyright (c) 2026 by Tadeusz Pycio
;=====================================================================================
;  Build:   ZSM RWBOOT,RWBOOT=RWBOOT.ASM
;           L80 RWBOOT,RWBOOT/N/X/E

; ---- parameters ----
IMGLBA	EQU	288		; CF LBA of the first image sector (ZZRCC layout: 120h)
IMGSEC	EQU	960		; image size in sectors (480 KB, top 32 KB not loaded)
; ---- CF (I/O page 00h) ----
CF_DATA	EQU	10h		; IDE Data Port (R/W)
CF_FEAT	EQU	11h		; Features (W)
CF_SECC	EQU	12h		; Sector count (R/W)
CF_LBA0	EQU	13h		; LBA bits 0-7 (R/W, LBA mode)
CF_LBA1	EQU	14h		; LBA bits 8-15 (R/W, LBA mode)
CF_LBA2	EQU	15h		; LBA bits 16-23 (R/W, LBA mode)
CF_LBA3	EQU	16h		; LBA bits 24-27 (R/W, LBA mode)
CF_STAT	EQU	17h		; Status (R)
CF_CMD	EQU	17h		; Command (W)
; ---- Z280 (DMA registers in I/O page FFh) ----
CPU_IOPR EQU	08h
DMA0_DL	EQU	00h
DMA0_DH	EQU	01h
DMA0_SL	EQU	02h
DMA0_SH	EQU	03h
DMA0_CNT EQU	04h
DMA0_TDR EQU	05h
DMCR	EQU	1Fh
TDRRUN	EQU	0E100h		; EN, src I/O fixed, byte, continuous, flowthrough, dst mem++

;=====================================================================================
	ASEG
	ORG	0

	LD	SP,0200h	; stack in 0100h-01FFh: overwritten only by the last DMA
	CALL	CF_RDY
	LD	A,0E0h
	OUT	(CF_LBA3),A
	LD	A,1		; 8-bit transfers
	OUT	(CF_FEAT),A
	LD	A,0EFh		; SET FEATURES
	OUT	(CF_CMD),A
	CALL	CF_RDY
	; DMA0: software RDY, source = CF data port, destination = 000200h
	LD	L,0FFh
	CALL	SETIOP
	LD	C,DMCR
	LD	HL,0020h	; SR0 only (clears UART link + EOP left by bootstrap)
	OUTW	(C),HL
	LD	C,DMA0_SL
	LD	HL,0F010h	; I/O 000010h
	OUTW	(C),HL
	LD	C,DMA0_SH
	LD	HL,000Fh
	OUTW	(C),HL
	LD	C,DMA0_DL
	LD	HL,0F200h	; memory 000200h
	OUTW	(C),HL
	LD	C,DMA0_DH
	LD	HL,000Fh
	OUTW	(C),HL
	; image sectors 1..IMGSEC-1 -> 000200h.. (destination auto-increments)
	LD	DE,IMGSEC-1	; LBA starts at IMGLBA+1 (initialized DW below)
LOOP:	CALL	CFREAD
	LD	C,DMA0_CNT
	LD	HL,512
	OUTW	(C),HL
	LD	C,DMA0_TDR
	LD	HL,TDRRUN
	OUTW	(C),HL
DW1:	INW	HL,(C)
	BIT	7,H
	JR	NZ,DW1
	LD	HL,(LBA)
	INC	HL
	LD	(LBA),HL
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,LOOP
	; last: image sector 0 -> 000000h-0001FFh (overwrites this loader)
	LD	HL,IMGLBA
	LD	(LBA),HL
	CALL	CFREAD
	LD	C,DMA0_DL
	LD	HL,0F000h	; memory 000000h
	OUTW	(C),HL
	LD	C,DMA0_DH
	LD	HL,000Fh
	OUTW	(C),HL
	LD	C,DMA0_CNT
	LD	HL,512
	OUTW	(C),HL
	LD	C,DMA0_TDR
	LD	HL,TDRRUN
	JP	FINAL
; -----------------------------------------------------------------------------
; CFREAD: READ SECTOR (LBA), wait for DRQ, leave I/O page = FFh
CFREAD:	LD	L,00h
	CALL	SETIOP
	LD	HL,(LBA)
	LD	A,L
	OUT	(CF_LBA0),A
	LD	A,H
	OUT	(CF_LBA1),A
	XOR	A
	OUT	(CF_LBA2),A
	LD	A,0E0h
	OUT	(CF_LBA3),A
	LD	A,1
	OUT	(CF_SECC),A
	LD	A,20h		; READ SECTORS
	OUT	(CF_CMD),A
	CALL	CF_RDY
	BIT	3,A		; DRQ?
	JR	Z,CFREAD	; error - retry
	LD	L,0FFh

SETIOP:	LD	C,CPU_IOPR
	LDCTL	(C),HL
	RET
; -----------------------------------------------------------------------------
; CF_RDY: wait BSY=0, RDY=1, return status in A
CF_RDY:	IN	A,(CF_STAT)	; first read discarded (400 ns rule)
CFR1:	IN	A,(CF_STAT)
	AND	0C0h
	CP	040h
	JR	NZ,CFR1
	IN	A,(CF_STAT)
	RET
; current LBA: read only before the last DMA, which overwrites it
LBA:	DW	IMGLBA+1
ENDCODE:
;=====================================================================================
; ---- tail: these 17 bytes (00EFh-00FFh) must be identical in the RomWBW
;      image, so it does not matter when the DMA overwrites them ----
	ORG	00EFh
FINAL:	OUTW	(C),HL		; start last DMA (C = TDR, I/O page FFh)
DW2:	INW	HL,(C)		; wait for EN = 0
	BIT	7,H
	JR	NZ,DW2
	LD	L,0
	LD	C,CPU_IOPR
	LDCTL	(C),HL		; I/O page 00h
	JP	0000h
	END
