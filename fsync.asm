.include "sfr.i"

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
	jmp INT_BaseTimerFire
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

;    /////////////////////////////////////////////////////////////

.org $1F0 ; go back to the BIOS
Exit_BIOS:
		not1 EXT, 0
	jmpf Exit_BIOS

.org $200
.string 16 "Frame Sync"
.string 32 "By https://github.com/jvsTSX"

.org $240 ; >>> ICON HEADER
.org $260 ; >>> PALETTE TABLE
.org $280 ; >>> ICON DATA

ScreenNum    = $10
ScreenCount  = $11
Flags        = $12
KeysCurr     = $13
KeysLast     = $14
KeysDiff     = $15
RTCT_Low     = $16
RTCT_High    = $17
ScreenMode   = $18
FrameCount   = $19
FramePreset  = $1A
ImageBaseLSB = $1B
ImageBaseMSB = $1C
TotalImages  = $1D
ShowIndTime  = $1E

INT_BaseTimerFire:
  dbnz RTCT_Low,  .RTC_Not_Yet
  dbnz RTCT_High, .RTC_Not_Yet
	mov #16, RTCT_High
	set1 Flags, 5
.RTC_Not_Yet:

  dbnz ScreenCount, .VSync_Not_Yet
	mov #51, ScreenCount
	set1 Flags, 7
.VSync_Not_Yet:
  reti


;    /////////////////////////////////////////////////////////////
;   ///                       GAME CODE                       ///
;  /////////////////////////////////////////////////////////////
Start:
		mov #0, P3INT
		mov #0, BTCR
		mov #0, ScreenMode
		mov #0, FrameCount

		set1 VSEL, 4 ; autoinc on
		mov #1, VRMAD2
		mov #$FD, VRMAD1
		
		ld VTRBF
	bnz .Reset_Value
		ld VTRBF
	be #$FF, .Keep_Value

.Reset_Value:
		mov #$FD, VRMAD1
		mov #0, VTRBF
		mov #$FF, VTRBF
		clr1 VSEL, 4 ; autoinc off
		mov #$17, VTRBF
.Keep_Value:
		clr1 VSEL, 4 ; autoinc off

		mov #%11000001, Flags
		ld VTRBF
		st ScreenCount
		mov #0, RTCT_Low
		mov #16, RTCT_High

		mov #0, CNR
		mov #0, TDR

		mov #66, ACC
.Wait_Loop:
	dbnz ACC, .Wait_Loop

		mov #%10010010, OCR  ; 1MHz on, RC clock off
		mov #$5, CNR
		mov #%00100001, TDR  ; 34 scanlines (default is %00100000, the BIOS resets it on app return)
		mov #%11110100, BTCR ; fire every quartz /8

	call SUB_ProcessKeys ; call it twice to nullify any keys the user is holding when entering the app


;    /////////////////////////////////////////////////////////////
;   ///                       MAIN LOOP                       ///
;  /////////////////////////////////////////////////////////////
MainLoop:
	call SUB_ProcessKeys

	bn KeysDiff, 7, .No_Sleep_Key
	jmp BeginDelaySelect
.No_Sleep_Key:

	bn KeysDiff, 2, .No_Left_Key
		ld ScreenNum
	bz .No_Left_Key
		dec ScreenNum
.No_Left_Key:

	bn KeysDiff, 3, .No_Right_Key
		ld ScreenNum
	be TotalImages, .No_Right_Key
		inc ScreenNum
.No_Right_Key:

	bn KeysDiff, 0, .No_Up_Key
		inc ScreenMode
		ld ScreenMode
		and #%00000011
		st ScreenMode
		set1 Flags, 6
.No_Up_Key:

	bn KeysDiff, 1, .No_Down_Key
		dec ScreenMode
		ld ScreenMode
		and #%00000011
		st ScreenMode
		set1 Flags, 6
.No_Down_Key:

;  ///////////////////////////////////////////////////////////// screen copy/display
	bp Flags, 7, .Update_Screen
	jmp .No_Update
.Update_Screen:
		clr1 Flags, 7

	bn Flags, 6, .No_Screen_Setup
		clr1 Flags, 6
		mov #160, ShowIndTime

		ld ScreenMode
		add ACC
		add ACC
		st C
		mov #<BaseList, TRL
		mov #>BaseList, TRH
		ldc
		st FramePreset
		st FrameCount
		inc C
		ld C
		ldc
		st TotalImages
		inc C
		ld C
		ldc
		st ImageBaseLSB
		inc C
		ld C
		ldc
		st ImageBaseMSB

		ld ScreenNum
	be TotalImages, .Keep
	bp PSW, 7, .Keep
		ld TotalImages
		st ScreenNum
.Keep:
.No_Screen_Setup:

	dbnz FrameCount, .No_Preset
		ld FramePreset
		st FrameCount
.No_Preset:

		ld ScreenNum ; currently selected screen
		st C
		ld FramePreset ; how many screens per slide
		st B
		xor ACC
		mul

		ld FrameCount
		dec ACC
		add C
		st C
		xor ACC
		mov #192, B ; now align it with the screens
		mul

		xch C ; screen + base of that screen mode
		add ImageBaseLSB
		st TRL
		ld ImageBaseMSB
		addc C
		st TRH

		; copy image into XRAM
		mov #$80, 2
		xor ACC
		st C
		st XBNK
.Outter:
		mov #12, B
.Inner:
		ld C
		inc C
		ldc
		st @r2
		inc 2
	dbnz B, .Inner
		
		ld 2
		add #4
		st 2
	bn PSW, 7, .Outter
	bp XBNK, 0, .Loop_Exit
		inc XBNK
		set1 2, 7
	br .Outter
.Loop_Exit:

		; draw the mode indicator on top if needed
		ld ShowIndTime
	bz .No_Update
		dec ShowIndTime
		mov #1, XBNK
		ld ScreenMode
		add #16
		mov #$D0, 2
		mov #<NumbersBase, TRL
		mov #>NumbersBase, TRH
	call SUB_DispNum
.No_Update:


;  ///////////////////////////////////////////////////////////// seconds indicator
	bn Flags, 5, .No_Second
		clr1 Flags, 5
		mov #2, XBNK
		not1 $183, 2
.No_Second:

;  ///////////////////////////////////////////////////////////// main end
		set1 PCON, 0
	jmp MainLoop


;    /////////////////////////////////////////////////////////////
;   ///                       CONF LOOP                       ///
;  /////////////////////////////////////////////////////////////
BeginDelaySelect:
		clr1 VSEL, 4 ; autoinc off
		mov #<NumbersBase, TRL
		mov #>NumbersBase, TRH

		mov #0, XBNK
		mov #$80, 2
.Outter:
		mov #12, B
		xor ACC
.Inner:
		st @r2
		inc 2
	dbnz B, .Inner
		ld 2
		add #4
		st 2
	bn PSW, 7, .Outter
	bp XBNK, 0, .Done
		inc XBNK
		set1 2, 7
	br .Outter
.Done:

;  ///////////////////////////////////////////////////////////// simple number display to select initial sync wait
DelaySelectLoop:

	call SUB_ProcessKeys
	bn KeysDiff, 7, .No_Sleep_Key
	jmp MainLoop
.No_Sleep_Key:

	bn KeysDiff, 0, .No_Up_Key
		ld VTRBF
		add #$10
		st VTRBF
.No_Up_Key:

	bn KeysDiff, 1, .No_Down_Key
		ld VTRBF
		sub #$10
		st VTRBF
.No_Down_Key:

	bn KeysDiff, 2, .No_Left_Key
		dec VTRBF
.No_Left_Key:

	bn KeysDiff, 3, .No_Right_Key
		inc VTRBF
.No_Right_Key:

	bn Flags, 7, .No_Update
		clr1 Flags, 7

		ld VTRBF ; display high digit
		ror
		ror
		ror
		ror
		and #$0F
		mov #$80, 2
		mov #0, XBNK
	call SUB_DispNum
		ld VTRBF ; display low digit
		and #$0F
		mov #$81, 2
	call SUB_DispNum

.No_Update:

	bn Flags, 5, .No_Second
		clr1 Flags, 5
		mov #2, XBNK
		not1 $183, 2
.No_Second:

		set1 PCON, 0
	jmp DelaySelectLoop



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

	bn KeysDiff, 6, .No_Mode_Key
		mov #%01110010, BTCR ; reset to halfsec mode because the BIOS don't reset BTCR
	jmpf Exit_BIOS
.No_Mode_Key:
	ret


SUB_DispNum:
		mov #6, B
		st C
		xor ACC
		mul
		mov #3, B
.Loop:
		ld C
		inc C
		ldc
		st @r2
		
		ld 2
		add #6
		st 2
		
		ld C
		inc C
		ldc
		st @r2
		
		ld 2
		add #10
		st 2
		
	dbnz B, .Loop
	ret


;    /////////////////////////////////////////////////////////////
;   ///                     DATA SECTION                      ///
;  /////////////////////////////////////////////////////////////
NumbersBase:
.include sprite "num_font.png" header="no"

ModeNumbers:
.byte 0
.byte %11001100 ; 3-shade progressive
.byte %00101010
.byte %11001100
.byte %00101000
.byte %11001000

.byte 0
.byte %11000110 ; 3-shade checkerboarded
.byte %00101000
.byte %11001000
.byte %00101000
.byte %11000110

.byte 0
.byte %11101100 ; 5-shade progressive
.byte %10001010
.byte %11101100
.byte %00101000
.byte %11001000

.byte 0
.byte %11100110 ; 5-shade checkerboarded
.byte %10001000
.byte %11101000
.byte %00101000
.byte %11000110

BaseList:
.byte 2, 6
.word ImageBase_3P

.byte 2, 6
.word ImageBase_3C

.byte 4, 3
.word ImageBase_5P 

.byte 4, 3
.word ImageBase_5C

ImageBase_3P:
.include sprite "images_3p/vmu_img0.png" header="no"
.include sprite "images_3p/vmu_img1.png" header="no"
.include sprite "images_3p/vmu_img2.png" header="no"
.include sprite "images_3p/vmu_img3.png" header="no"
.include sprite "images_3p/vmu_img4.png" header="no"
.include sprite "images_3p/vmu_img5.png" header="no"
.include sprite "images_3p/vmu_img6.png" header="no"

ImageBase_3C:
.include sprite "images_3c/vmu_img0.png" header="no"
.include sprite "images_3c/vmu_img1.png" header="no"
.include sprite "images_3c/vmu_img2.png" header="no"
.include sprite "images_3c/vmu_img3.png" header="no"
.include sprite "images_3c/vmu_img4.png" header="no"
.include sprite "images_3c/vmu_img5.png" header="no"
.include sprite "images_3c/vmu_img6.png" header="no"

ImageBase_5P:
.include sprite "images_5p/vmu_img0.png" header="no"
.include sprite "images_5p/vmu_img1.png" header="no"
.include sprite "images_5p/vmu_img2.png" header="no"
.include sprite "images_5p/vmu_img3.png" header="no"

ImageBase_5C:
.include sprite "images_5c/vmu_img0.png" header="no"
.include sprite "images_5c/vmu_img1.png" header="no"
.include sprite "images_5c/vmu_img2.png" header="no"
.include sprite "images_5c/vmu_img3.png" header="no"
.cnop 0, $200 ;