.nolist
.include "tn4313def.inc"
.list 

;***** Pin definitions

;.equ     Xtal1     = PORTA0                     ; Crystal oscylator 
;.equ     Xtal2     = PORTA1                     ; 18,432 MHz
;.equ     RESET     = PORTA2                     ; AVR Reset

.equ      AD7       = PORTB7                     ; Output AD7 (0-bootstrap)
.equ      AD6       = PORTB6                     ; Output AD6 (1-bootstrap, 0-normal boot)
.equ      AD5       = PORTB5                     ; Output AD5 (1-multiprocessor)
.equ      AD4       = PORTB4                     ; Output AD4 (0-always)
.equ      AD3       = PORTB3                     ; Output AD3 (0-WS)
.equ      AD2       = PORTB2                     ; Output AD2 (0-WS)
.equ      AD1       = PORTB1                     ; Output AD1 (1-CLK)
.equ      AD0       = PORTB0                     ; Output AD0 (0-CLK)

.equ      RXD       = PORTD0                     ; USART Reciever
.equ      TXD       = PORTD1                     ; USART Transmiter
.equ      CLKO      = PORTD2                     ; Output System Clock
.equ      BOOT      = PORTD3                     ; Input Bootstrap Jumper (0-enable)
.equ      RSTO      = PORTD4                     ; Output /RST Sygnal
.equ      XCLK      = PORTD5                     ; Output XCLK
.equ      WAIT      = PORTD6                     ; Output /WAIT Sygnal

;******** Global register variables
.def      rblock    = R2
.def      rblocki   = R3
.def      rcksum    = R4
.def      tmp       = R16                        ; temporary storage register
.def      mode      = R17                        ; mode register
.def      cksum     = R18
.def      xblock    = R19
.def      spmcrval  = R20
.def      response  = R21
.def      ee_adr    = R22                        ; Address EEPROM
.def      ee_data   = R23                        ; Data EEPROM
.def      looplo    = R24
.def      loophi    = R25

;*****    mode register R17 ->                     Z280 BITR Register
.equ      sw_clk0   = 0                          ; AD0 - Bus clock=CPU clock
.equ      sw_clk1   = 1                          ; AD1 - ^ 00-1/2, 01=same, 10-1/4, 11-reserverd
.equ      sw_ws0    = 2                          ; AD2 - Wait States for Lower 8MB memory
.equ      sw_ws1    = 3                          ; AD3 - ^ 00-0WS, 01-1WS, 10-2WS, 11-3WS
.equ      sw_rsv    = 4                          ; AD4 - Reserved (always 0)
.equ      sw_mpm    = 5                          ; AD5 - Multiprocesor mode (1-enable, 0-disable)
.equ      sw_boot   = 6                          ; AD6 - Bootstrap mode (1-enable, 0-disable)
.equ      sw_val    = 7                          ; AD7 - Valid data on bus (0-valid)

.equ      RAMEND1   = 0x00df

;------------------ Code Segment ---------------------------------
.cseg

;------------------ Interrupt Vectors ----------------
.org 0              rjmp      Start              ; Boot
.org INT0addr       reti                         ; External Interrupt 0
.org INT1addr       rjmp      Firmware           ; External Interrupt 1
.org ICP1addr       reti                         ; Timer/Counter1 Capture Event
.org OC1Aaddr       reti                         ; Timer/Counter1 Compare Match A
.org OVF1addr       reti                         ; Timer/Counter1 Overflow
.org OVF0addr       reti                         ; Timer/Counter0 Overflow
.org URXCaddr       reti                         ; USART, Rx Complete
.org UDREaddr       reti                         ; USART Data Register Empty
.org UTXCaddr       reti                         ; USART, Tx Complete
.org ACIaddr        reti                         ; Analog comparator
.org PCIaddr        reti                         ; Pin change Interrupt Request B (0)
.org OC1Baddr       reti                         ; Timer/Counter1 Compare Match B
.org OC0Aaddr       reti                         ; Timer/Counter0 Compare Match A
.org OC0Baddr       reti                         ; Timer/Counter0 Compare Match B
.org USI_STARTaddr  reti                         ; USI START
.org USI_OVFaddr    reti                         ; USI Overflow
.org ERDYaddr       reti                         ; EEPROM Ready
.org WDTaddr        reti                         ; Watchdog Time-out
.org PCIAaddr       reti                         ; Pin Change Interrupt Request A (1)
.org PCIDaddr       rjmp      Error              ; Pin Change Interrupt Request D (2)


;******** START OF THE PROGRAMME

Start:    ldi       tmp, LOW(RAMEND)             ; load low byte of RAMEND
          out       SPL, tmp                     ; store in stack pointer low
          ldi       tmp, HIGH(RAMEND)            ; load high byte of RAMEND
          out       SPH, tmp                     ; store r16 in stack pointer high

          ; Init I/O Ports - Control
          ldi       tmp, 0b01110100              ; output pins
          out       DDRD, tmp                    ; port D output
          ldi       tmp, (1<<BOOT)               ; pull-up BOOT jumper, set low RST, WAIT
          out       PORTD, tmp

          ; Init Timer 0  (Z280 USART Clock)
          ldi       tmp, 0x04                    ; FCLK/10
          out       OCR0A, tmp
          out       OCR0B, tmp
          clr       tmp
          out       TCNT0, tmp
          ldi       tmp, (1<<CS00)               ; preskaler = FSCK
          out       TCCR0B, tmp
          ldi       tmp, (1<<COM0B0)|(1<<WGM01)  ; CTC mode, out enable
          out       TCCR0A, tmp

          ; Check Boot jumper
          ldi       mode, (1<<sw_clk0)           ; set normal boot
          sbis      PIND, BOOT                   ; check Boot Jumper
          ldi       mode, (1<<sw_clk0)|(1<<sw_boot)  ; set bootstrap mode

          ; Init I/O Ports - (AD)
          ser       tmp
          out       DDRB, tmp                    ; port B output
          out       PORTB, mode                  ; put on AD mode

          ; Check current mode
          sbrs      mode, sw_boot                ; check bootstrap mode
          rjmp      Release                      ; normal 

          ; Init USART 
          ldi       tmp, 9
          out       UBRRL, tmp                   ; Set baud rate 115200
          ldi       tmp, (1<<TXEN)               ; Enable transmitter
          out       UCSRB, tmp
          ldi       tmp, (3<<UCSZ0)|(3<<UPM0)    ; Set frame format: 8data, odd parity, 1stop bit
          out       UCSRC, tmp

          ; Read EEPROM
          clr       ee_adr                       ; Set address EEPROM
          rcall     EERead                       ; read first byte

          ; Set interrupt on Error transmision
          ldi       tmp, (1<<PCIE2)  
          out       GIMSK, tmp                   ; enable interrupt pin change D (2)
          ldi       tmp, (1<<PCINT11)
          out       PCMSK2, tmp                  ; mask interrupt on RX pin

          ; Release RST
Release:  sbi       PORTD, RSTO
          ldi       tmp, 2
          rcall     Delay
          ; Release WAIT
;          in        tmp, PORTD
;          ori       tmp, 0b01000000              ; release WAIT
;          out       PORTD, tmp
          sbi       PORTD, WAIT

          ; Set PortB (AD) in tri-state (Hi-Z)
          clr       tmp
          out       DDRB, tmp                    ; make PORTB all inputs 
          out       PORTB, tmp                   ; disable pull-ups and make all pins tri-state

          ; Set pin WAIT (PortD.6) in tri-state (Hi-Z)
          ldi       tmp, 0b00110100              ; set WAIT Hi-Z
          out       DDRD, tmp                    ; port D
          nop                                    ; sync
          cbi       PORTD, WAIT
          ; Check current mode
          sbrs      mode, sw_boot                ; check bootstrap mode
          rjmp      Loop                         ; normal 
          ldi       tmp, 10
          rcall     Delay                        ; wait for Z280 UART ready
          sei                                    ; Enable interrupt
          ; Send EEPROM data from USART
Transmit: sbis      UCSRA, UDRE                  ; wait for empty transmit buffer
          rjmp      Transmit
          out       UDR, ee_data                 ; send 
          inc       ee_adr
          tst       ee_adr                       ; all bytes transfer?
          breq      EndBoot                      ; end transmision
          rcall     EERead
          rjmp      Transmit
          ; Set GPIO USART Tri-State
EndBoot:  cli                                    ; disable interrupt
          cbi       PCMSK2, PCINT11
;          in        tmp, PORTD
;          ldi       tmp, (0<<PCIE2)
          clr       tmp
          out       GIMSK, tmp
          cbi       UCSRB, TXEN                  ; disable transmiter
          ldi       tmp, 0b00110100              ; set TX Hi-Z
          out       DDRD, tmp

Loop:     ldi       tmp, (1<<ISC10)              ; Logical change on pin Boot (INT1)
          out       MCUCR, tmp
          ldi       tmp, (1<<INT1)               ; INT1 request enable
          out       GIMSK, tmp
;          sei                                    ; Enable interrupt
          ; Entering Idle mode
          ldi       tmp, (1<<SE)                 ; Set Sleep Enable
          out       MCUCR, tmp
          sleep
          ; Continus loop
          rjmp     Loop
          ; End & wait to Reset


;******** Bootstrap firmware update procedure
Firmware:
;TODO
          ; check baudrate
          ; hexload
          ; save to EEPROM
          reti
; ### end of new firmware


;******* Bootstrap process transmission error
Error:    clr       ee_adr                       ; Set address EEPROM
          rcall     EERead                       ; read first byte
          reti

;******** EEPROM memory handling procedures

EERead:
          out       EEARL, ee_adr                ; Setting the EEPROM memory address
          sbi       EECR, EERE                   ; Reading instruction
          in        ee_data, EEDR                ; Read data from data register
          ret  

          ;---------------------------------------------------------------------------------
EEWrite:  sbic      EECR, EEPE                   ; Waiting for write cycle to finish
          rjmp      EEWrite

          ldi       tmp, (0<<EEPM1)|(0<<EEPM0)   ; set programming mode
          out       EECR, tmp

          out       EEARL, ee_adr                ; EEPROM memory address
          out       EEDR, ee_data                ; byte to write

          sbi       EECR, EEMPE                  ; enter 1 to EEMPE
          sbi       EECR, EEPE                   ; Start EEPROM writing via EEPE
          ret

;/***********************
; delay time destroy tmp
;/***********************
Delay1:   ldi       tmp, 10                     ;1 ((n-1)*3 + 5)+5 = 2us
Delay:    dec       tmp                         ;1
          brne      Delay                       ;2
          ret                                   ;4
;
