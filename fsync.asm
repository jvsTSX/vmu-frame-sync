	.org 0   ; entry point
  jmpf Start
	.org $03 ; External int. (INT0)                 - I01CR
  reti
	.org $0B ; External int. (INT1)                 - I01CR
  reti
	.org $13 ; External int. (INT2) and Timer 0 low - I23CR and T0CNT
  reti
	.org $1B ; External int. (INT3) and base timer  - I23CR and BTCR
	clr1 BTCR, 3
  jmp BaseTmEx
	.org $23 ; Timer 0 high                         - T0CNT
  reti
	.org $2B ; Timer 1 Low and High                 - T1CNT
  reti
	.org $33 ; Serial IO 1                          - SCON0
  reti
	.org $3B ; Serial IO 2                          - SCON1
  reti
	.org $43 ; Maple                                - $160 and $161
  reti
	.org $4B ; Port 3 interrupt                     - P3INT
	clr1 P3INT, 1
  reti

 	.org	$1F0 ; exit app mode
Exit_BIOS:	
	not1	EXT, 0
	jmpf	Exit_BIOS

.org $200
.string 16 "Frame Sync"
.string 32 "By https://github.com/jvsTSX"

.org $240 ; >>> ICON HEADER
.org $260 ; >>> PALETTE TABLE
.org $280 ; >>> ICON DATA

.include "sfr.i"

ScreenNum    = $10
ScreenCount  = $11
Flags        = $12
KeysCurr     = $13
KeysLast     = $14
KeysDiff     = $15
RTCT_Low     = $16
RTCT_High    = $17

BaseTmEx:
  dbnz RTCT_Low,  .RTCNotYet
  dbnz RTCT_High, .RTCNotYet
	mov #16, RTCT_High
	set1 Flags, 5
.RTCNotYet:

  dbnz ScreenCount, .NotYet
	mov #51, ScreenCount
	set1 Flags, 7
.NotYet:
  reti


;    /////////////////////////////////////////////////////////////
;   ///                       GAME CODE                       ///
;  /////////////////////////////////////////////////////////////
Start:
		mov #0, P3INT

		mov #%10000001, Flags
		mov #25, ScreenCount
		mov #0, RTCT_Low
		mov #16, RTCT_High
		mov #0, ScreenNum

		mov #0, BTCR
		mov #0, CNR
		mov #0, TDR

		mov #66, ACC
.WaitLoop2:
	dbnz ACC, .WaitLoop2

		mov #%10010010, OCR  ; 1MHz on, RC clock off
		mov #$5, CNR
		mov #%00100001, TDR  ; 34 scanlines (default is %00100000, the BIOS resets it on app return)
		mov #%11110100, BTCR ; fire every quartz /8

	call SUB_ProcessKeys ; call it twice to nullify any keys the user is holding when entering the app

;  /////////////////////////////////////////////////////////////
MainLoop:
	call SUB_ProcessKeys

	bn KeysDiff, 2, .NoLeft
		ld ScreenNum
	bz .NoLeft
		dec ScreenNum
.NoLeft:

	bn KeysDiff, 3, .NoRight
		ld ScreenNum
	be #6, .NoRight
		inc ScreenNum
.NoRight:

	bn KeysDiff, 6, .NoMode
		mov #%01110010, BTCR ; reset to halfsec mode because the BIOS don't reset BTCR
	jmpf Exit_BIOS
.NoMode:

;  ///////////////////////////////////////////////////////////// screen copy/display
	bn Flags, 7, .NoUpdate
		clr1 Flags, 7
		not1 Flags, 0 ; parity flag

		; calculate offset from current screen
		ld ScreenNum
		add ACC
	bn Flags, 0, .EvenFrame
		inc ACC
.EvenFrame:

		st C
		xor ACC
		mov #192, B
		mul
		
		st B
		mov #<ImageBase, ACC
		add C
		st TRL
		mov #>ImageBase, ACC
		addc B
		st TRH
		
		; copy image
		mov #$80, 2
		xor ACC
		st C
		st XBNK
.CopyLoop:
		mov #12, B
.InnerLoop:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .InnerLoop
		
		ld 2
		add #4
		st 2
	bn PSW, 7, .CopyLoop
	bp XBNK, 0, .LoopExit
		inc XBNK
		set1 2, 7
	br .CopyLoop
.LoopExit:
		
.NoUpdate:


;  ///////////////////////////////////////////////////////////// seconds indicator
	bn Flags, 5, .NoSecond
		clr1 Flags, 5
		mov #2, XBNK
		not1 $183, 2
.NoSecond:

;  ///////////////////////////////////////////////////////////// main end
		set1 PCON, 0
	jmp MainLoop



;    /////////////////////////////////////////////////////////////
;   ///                     SUBROUTINES                       ///
;  /////////////////////////////////////////////////////////////
SUB_ProcessKeys:
		ld KeysCurr
		st KeysLast
		
		ld P3
		xor #$FF
		st KeysCurr
		xor KeysLast
		and KeysCurr
		st KeysDiff
	ret



;    /////////////////////////////////////////////////////////////
;   ///                     DATA SECTION                      ///
;  /////////////////////////////////////////////////////////////
ImageBase:

.include sprite "vmu_img0.png" header="no"
.include sprite "vmu_img1.png" header="no"
.include sprite "vmu_img2.png" header="no"
.include sprite "vmu_img3.png" header="no"
.include sprite "vmu_img4.png" header="no"
.include sprite "vmu_img5.png" header="no"
.include sprite "vmu_img6.png" header="no"

.cnop 0, $200 ;