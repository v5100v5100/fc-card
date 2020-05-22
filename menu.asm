; 该代码只适用Mapper4合卡，需要配合我画的板子才能正常使用
; 2019 By liuweihang
; Email:916316559@qq.com

;;;;;;;;;;;;;iNES Header;;;;;;;;;;;;;
  .inesprg 2   ; 2x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 4   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring / 0=Horizontal / 1=Vertical

;;;;;;;;;;;;;RAM Info;;;;;;;;;;;;;
; $0000 ~ $0001	; Background pointer
; $0200 ~ $0203	; Arrow sprit data
; $0304		; Controller pad1 data
; $0305		; ROM number
; $0306		; Game switch byte
; $0400 ~ $0409	; Game switch data

;;;;;;;;;;;;;Bank0 8000~9FFF;;;;;;;;;;;;;
  .bank 0
  ;.org $9900
  .org $8E60

;****************************Raw Data******************************

;;;;;;;;;;;;;Background data;;;;;;;;;;;;;
background_data:
  .incbin "menu.nam"

;;;;;;;;;;;;;Palette data;;;;;;;;;;;;;
palette_data:
  .incbin "menu.pal"

;;;;;;;;;;;;;Arrow sprit data;;;;;;;;;;;;;
arrow_sprit:  ;箭头的:y坐标,TitleId,Effects,x坐标
	.db $5C,$1B,$00,$30	; Vertical, Tile, Effects, Horizontal

;;;;;;;;;;;;;指示箭头的Y坐标数据;;;;;;;;;;;;;
vertical_move:
	.db $5C,$6C,$7C,$8C

;;;;;;;;;;;;;Game switch data (Run on ram $0400 ~ $0408);;;;;;;;;;;;;

game1_switch:;切换到第2个游戏
	.db $A9,$01       ; LDA #$01
	.db $8D,$01,$64   ; STA $6401
	.db $4C,$10,$F0   ; JMP $F010
	
game2_switch:;切换到第3个游戏
	.db $A9,$02		  ;LDA #$02
	.db $8D,$02,$64	  ;STA $6402
	.db $4C,$00,$FE	  ;JMP $FE00
	
game3_switch:;切换到第4个游戏
	.db $A9,$03	      ;LDA #$03
	.db $8D,$03,$64   ;STA $6403
	.db $4C,$3D,$FC   ;JMP $FC3D


;****************************主程序******************************

;;;;;;;;;;;;;初始化代码;;;;;;;;;;;;;
Init_code:
	LDX #$40
	STX $4017	; 禁用 APU frame IRQ
	LDX #$FF
	TXS		; Set up stack
	INX		; Now X = 0
 	STX $2000	; 禁用 NMI
	STX $2001	; 禁用 rendering
	STA $2005	; 设置屏幕垂直不滚动
	STA $2005   ; 设置屏幕水平不滚动
	STX $4010	; 禁用 DMC IRQs
	STX $E000	; 禁用 IRQ
	LDA #$80
	STA $A001	; Enable WRAM	

;;;;;;;;;;;;;Clear CPU ram routine;;;;;;;;;;;;;
	LDX #$00
	TXA
clear_loop:
	STA $0000,x
	STA $0100,x
	STA $0200,x
	STA $0300,x
	STA $0400,x
	STA $0500,x
	STA $0600,x
	STA $0700,x
	DEX
	BNE clear_loop

;;;;;;;;;;;;;等待vblank结束;;;;;;;;;;;;;
	LDX #$02
vblank_wait:
	BIT $2002
	BPL vblank_wait
	DEX
	BNE vblank_wait

;;;;;;;;;;;;;切换到菜单用到的CHR的bank;;;;;;;;;;;;;
	LDA #$00	; Select PPU 0000 ~ 0800
	STA $8000	
	LDA #$20	; CHR bank number1 (TLP Page down count * 4 --> Convert to hex)
	STA $8001
	LDA #$01	; Select PPU 0800 ~ 1000
	STA $8000
	LDA #$22	; CHR bank number2 (CHR bank number1 + 2h)
	STA $8001

;;;;;;;;;;;;;读取和设置调色板子程序;;;;;;;;;;;;;
	LDA $2002             ; read PPU status to reset the high/low latch
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006
	LDY #$00
	LDX #$20	; Palette data has 20h bytes
palette_loop:
	LDA palette_data,y
	STA $2007
	INY
	DEX
	BNE palette_loop

;;;;;;;;;;;;;背景文本显示和属性设置;;;;;;;;;;;;; 
;;;;;;;;;;;;;Background text print + attribute set;;;;;;;;;;;;; 
	LDA $2002	; Read PPU status to reset the high/low latch
	LDA #$20
	STA $2006	; Write the high byte of $2000 address
	LDA #$00
	STA $2006	; Write the low byte of $2000 address
	LDA #$60	; Set
	STA <$00	; Background
	LDA #$8E	; Pointer on
	STA <$01	; $00 / $01 Ram
	LDY #$00	; Small loop runs 100 times (from 00 ~ FF)
	LDX #$04	; Big loop runs 4 times (from 04 ~ 01)
background_loop:
	LDA [$00], y	; Load background data
	STA $2007
	INY
	BNE background_loop
	INC <$01
	DEX
	BNE background_loop
	LDA #$18
	STA $2001	; Show background and sprites

;;;;;;;;;;;;;Save arrow sprite data to ram $0200;;;;;;;;;;;;;
	LDX #$00
arrow_loop:
	LDA arrow_sprit,x	; Load arrow sprite data
	STA $0200,x	; Save arrow sprite data to ram
	INX
	CPX #$04
	BNE arrow_loop
	LDA #$00
	STA $0305	; On start up arrow is on the first game

;;;;;;;;;;;;;将切换游戏的代码片段加载到内存地址$0400;;;;;;;;;;;;;
;	LDX #$00
;transfer_loop:
;	LDA game_switch,x
;	STA $0400,x
;	INX
;	CPX #$09	;Total code on the ram is 09h
;	BNE transfer_loop

;;;;;;;;;;;;;Transfer Sprites to OAM;;;;;;;;;;;;;
Infinite_loop:
	LDA #$00
	STA $2003
	LDA #$02
	STA $4014
	LDX #$00
delay_loop:
vblank_wait2:
	BIT $2002
	BPL vblank_wait2
	INX
	CPX #$08
	BNE delay_loop
	JSR pad_routine
	JMP Infinite_loop

;****************************下面是子程序******************************
;;;;;;;;;;;;;按键音效;;;;;;;;;;;;;
make_sound:
	LDA #$FF
	STA $4015	; Enable sound channels
	LDA #$1F
	STA $4004
	LDA #$99
	STA $4005
	LDA #$EF
	STA $4006
	LDA #$08
	STA $4007
	RTS
;-----------------------

;;;;;;;;;;;;;手柄控制子程序;;;;;;;;;;;;;
pad_routine:
	LDX #$01
	STX $4016
	LDX #$00
	STX $4016
	LDY #$08
padRead_loop:
	LDA $4016
	LSR A
	ROL $0304
	DEY
	BNE padRead_loop
	LDA #$08	; 检测上键是否按下
	CMP $0304
	BNE down_check	; Down button check
	JSR make_sound	; 发出按键声
	LDX $0305	; 读取指示箭头的Y坐标  Current position of the arrow
	CPX #$00
	BNE wasnot_first	; Jump if arrow was not on the first game
	LDX #$04	; Arrow was on the first game + up button pressed = prepare to jump to the last game
wasnot_first:
	DEX
	STX $0305
	LDA vertical_move,x
	STA $0200
	RTS
;-----------------------

down_check:
	LDA #$04	;检查下键是否按下
	CMP $0304
	BNE start_button	;开始键按键检查
	JSR make_sound	; Make sound
	LDX $0305	; Current position of the arrow
	CPX #$03
	BNE wasnot_last	; 如果不是最后一个游戏就向下切换
	LDX #$FF		; Arrow was on the last game + down button pressed = prepare to jump to the first game
wasnot_last:
	INX
	STX $0305
	LDA vertical_move,x
	STA $0200
	RTS
;-----------------------

start_button:
	LDA #$10	;检查开始键是否按下
	CMP $0304
	BEQ game_run	; If start button was pressed then time to run a game!
	LDA #$C0	; Check for A button press	
	BIT $0304
	BNE game_run	; If A button was pressed then time to run a game!
	RTS
;-----------------------

game_run:
	LDA #$00
	STA $2000	; 禁用 NMI 中断
	STA $2001	; 禁用绘制屏幕
	STA $4004	; 重置声道
	STA $4005	; 重置声道
	STA $4006	; 重置声道
	STA $4007	; 重置声道
	STA $4015	; 禁用声道
	LDA $0305
	CMP #$00
	BNE game2	;
	JMP $FFE0   ;跳转到宿主游戏的起始向量
game2:
	CMP #$01
	BNE game3	; Next check
	;;;;将切换游戏的代码加载到$400内存处
	LDX #$00
g1Transfer_loop:
	LDA game1_switch,x
	STA $0400,x
	INX
	CPX #$08	;Total code on the ram is 08h
	BNE g1Transfer_loop
	;;;;
	JMP $0400	;
game3:
	CMP #$02
	BNE game4	; Next check
	;;;;将切换游戏的代码加载到$400内存处
	LDX #$00
g2Transfer_loop:
	LDA game2_switch,x
	STA $0400,x
	INX
	CPX #$08	;Total code on the ram is 08h
	BNE g2Transfer_loop
	;;;;
	JMP $0400	;
game4:
	CMP #$03
	;;;;将切换游戏的代码加载到$400内存处
	LDX #$00
g3Transfer_loop:
	LDA game3_switch,x
	STA $0400,x
	INX
	CPX #$08	;Total code on the ram is 08h
	BNE g3Transfer_loop
	;;;;
	JMP $0400	;跳转到切换游戏的子程序


;;;;;;;;;;;;;Bank1 A000~BFFF;;;;;;;;;;;;;
  .bank 1
  .org $A000 
;;;Empty

;;;;;;;;;;;;;Bank2 C000~DFFF;;;;;;;;;;;;;
  .bank 2
  .org $C000 
;;;Empty

;;;;;;;;;;;;;Bank3 E000~FFFF;;;;;;;;;;;;;
  .bank 3
  ;.org $FFE0
  .org $FF80

;;;;;;;;;;;;;PRG bank 切换;;;;;;;;;;;;;
RESET:
	SEI		; 禁用 IRQs 中断
	CLD		; 禁用十进制模式
	;;;;2020.1.11添加的想试试兼容性
	LDX #$FF
	TXS
	LDA #$00
	STA $2000
	STA $2001
_FFD0:
	LDA $2002
	BPL _FFD0
_FFD5:
	LDA $2002
	BMI _FFD5
	LDA #$00
	STA $E000
	LDA #$80
	STA $A001
	;;;;2020.1.11添加的想试试兼容性 end
	LDA #$06	; 选择内存地址 8000 ~ 9FFF 作为 bank 切换的空间
	STA $8000
	LDA #$05	;切换到菜单用到的PRG的bankNo, bankNo=菜单PRG在ROM文件中的起始地址/2000
	STA $8001
	JMP Init_code

;;;;;;;;;;;;;Vectors;;;;;;;;;;;;;
  .org $FFFA
  .dw 0
  .dw RESET
  .dw 0

;;;;;;;;;;;;;CHR数据;;;;;;;;;;;;;
  .bank 4
  .org $0000
  .incbin "menu.chr"