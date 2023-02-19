
; Macrodefinitions
.EQU LED1 = PORTB0	;LED1 is connected to PORTB0 (port nr 8)
.EQU LED2 = PORTB1	;LED2 is connected to PORTB1 (port nr 9)

.EQU RESET_BUTTON = PORTB3	;RESET_BUTTON is connected to PORTB3 (port nr 11)
.EQU BUTTON1 = PORTB4		;BUTTON1_BUTTON aktivates led1 and is connected to PORTB4 (port nr 12)
.EQU BUTTON2 = PORTB5		;BUTTON2_BUTTON aktivates led2 and is connected to PORTB5 (port nr 13)

.EQU RESET_vect = 0x00			;Reset-vector: The start of the program.
.EQU PCINT0_vect = 0x06			;Interupt vector for PORTB buttons.
.EQU TIMER0_OVF_vect = 0x20		;Interupt vector for timer0 in normal mode.
.EQU TIMER1_COMPA_vect = 0x16	;Interupt vector for timer1 in CTC mode.
.EQU TIMER2_OVF_vect = 0x12		;Interupt vector for timer2 in normal mode.

.EQU TIMER0_MAX_COUNT = 6	 ;Number of interupts that it takes for 100 ms to pass
.EQU TIMER1_MAX_COUNT = 12 ;Number of interupts that it takes for 200 ms to pass
.EQU TIMER2_MAX_COUNT = 18 ;Number of interupts that it takes for 300 ms to pass

.DSEG
.ORG SRAM_START ; Allokates variables att the begining of the static RAM-memory.
led1_blink_counter: .byte 1 ; counter used to blink led1 with a dealy of 100 ms.
led2_blink_counter: .byte 1 ; counter used to blink led2 with a dealy of 200 ms.
debouncing_counter: .byte 1 ; counter used to turn of the buttons for 300 ms to prevent bouncing.

	;Start of the Program code segment. 
.CSEG 
	;Att program start or reset the prgoram jumps to main.
.ORG RESET_vect
	JMP main

	;Pin Change inpterrupt on PINB thats aktivates for PORTB 3-5.
.ORG PCINT0_vect
	RJMP ISR_PCINT0_vect

	;timer inpterrupt for timer2 that is used for debouncing on buttons on PORTB 3-5. 
.ORG TIMER2_OVF_vect 
	RJMP ISR_TIMER2_OVF_vect 

	;timer inpterrupt for timer1 that is used for blinking led2. 
.ORG TIMER1_COMPA_vect
	RJMP ISR_TIMER1_COMPA_vect

	;timer inpterrupt for timer1 that is used for blinking led1. 
.ORG TIMER0_OVF_vect 
	RJMP ISR_TIMER0_OVF_vect

;/*******************************************************************************************
; ISR_TIMER2_OVF_Vect: timer2 used is for debouncing by turning of PCI interupts on PORTB.
;							  Affter the counter has counted to TIMER2_MAX_COUNT the interupts are turned on again
;							  the counter is aktivated if R29 is set to one and once the timmer has counted
;							  to TIMER2_MAX_COUNT R29 cleared.	
;								
;								The timer keeps the PCI interupts off about 100 ms after a button has been pressed.				    			 
;
;********************************************************************************************/
ISR_TIMER2_OVF_vect:
	CPI R29,0x01
	BRLO ISR_TIMER2_OVF_vect_end
	LDS R22,debouncing_counter
	INC R22
	CPI R22,TIMER2_MAX_COUNT
	BRLO ISR_TIMER2_OVF_vect_end
	STS PCICR,R16
	CLR R22
	CLR R29
ISR_TIMER2_OVF_vect_end:
	STS debouncing_counter,R22
	RETI

;/*******************************************************************************************
; ISR_TIMER0_OVF_Vect: If timer0 is on. the timmer will ativate every 16.4 ms 
;							  and then count to TIMER0_MAX_COUNT and toogle led1
;
;********************************************************************************************/
ISR_TIMER0_OVF_vect:
	LDS R22,led1_blink_counter
	INC R22
	CPI R22,TIMER0_MAX_COUNT
	BRLO ISR_TIMER0_OVF_vect_end
	CLR R22
	OUT PINB,R16
ISR_TIMER0_OVF_vect_end:
	STS led1_blink_counter,R22
	RETI

/*******************************************************************************************
; ISR_TIMER1_OVF_Vect: If timer1 is on. the timmer will ativate every 16.4 ms 
;							  and then count to TIMER1_MAX_COUNT and toogle led2
;
;********************************************************************************************/
ISR_TIMER1_COMPA_vect:
	LDS R22,led2_blink_counter
	INC R22
	CPI R22,TIMER1_MAX_COUNT
	BRLO ISR_TIMER1_COMPA_vect_end
	CLR R22
	OUT PINB,R17
ISR_TIMER1_COMPA_vect_end:
	STS led2_blink_counter,R22
	RETI


/*******************************************************************************************
; ISR_PCINT0_vect: checks if any of the buttons on PINB 3-5 is high.
						 If no button is pressed nothing will happen.
;
;********************************************************************************************/
ISR_PCINT0_vect:

/*******************************************************************************************
; check_reset_button: checks if PINB3 is high. If the pin is high PCI-interupts and timer 0 and 1
;							 are turned off by whriting a zero to PCICR,TIMSK0 and TIMSK1. 
;							 R29 is allso sett to 1 to tell timer2 to reativate PCI interrups after about 300 ms.
;						    Led1 and Led2 is turned off and no other buttons are cheked.
;
;							 If PINB3 is low the next button is checked.
;
;********************************************************************************************/
check_reset_button:
	IN R21,PINB
	AND R21,R20
	BREQ check_button1
	CALL led1_off
	CALL led2_off
	LDI R29,0x01
	LDS R21,0x00
	STS PCICR,R21
	STS TIMSK0,R21
	STS TIMSK1,R21
	RJMP ISR_PCINT0_vect_end

/*******************************************************************************************
; check_button1: checks if PINB4 is high. If the pin is high PCI-interupts are turned off and timer0 is toggled. 
;					  If timer0 is on it will blink led1 every 100 ms. 
;					  R29 is sett to one to so that timer2 reaktivates PCI-interupts after about 300 ms.
;					  Led1 is turned off and no other interuppts are checked.
;
;					  If PINB4 is low the next button is checked.
;
;********************************************************************************************/
check_button1:
	IN R21,PINB
	AND R21,R18
	BREQ check_button2
	LDI R29,0x01
	LDS R21,TIMSK0
	EOR R21,R16
	STS TIMSK0,R21
	LDI R21,0x00
	STS PCICR,R21
	CALL led1_off
	RJMP ISR_PCINT0_vect_end
/*******************************************************************************************
; check_button1: checks if PINB5 is high. If the pin is high PCI-interupts are turned off and timer1 is toggled.
;					  If timer0 is on it will blink led1 every 200 ms.  
;					  R29 is sett to one to so that timer2 reaktivates PCI-interupts after about 300 ms.
;					  Led2 is turned off and no other interuppts are checked.
;
;					  If PINB5 is low no other interuppts are checked.
;
;********************************************************************************************/
check_button2:
	IN R21,PINB
	AND R21,R19
	BREQ ISR_PCINT0_vect_end
	LDI R29,0x01
	LDS R21,TIMSK1
	EOR R21,R17
	STS TIMSK1,R21
	LDI R21,0x00
	STS PCICR,R21
	CALL led2_off
ISR_PCINT0_vect_end:
	RETI

;/*******************************************************************************************
; setup: initiation directives that runs att the start of the prgoram.
;
;********************************************************************************************/
setup:

;/*******************************************************************************************
; setup_init_inputs_and_outputs: Initiates PORTB 8-9 ass Outputs for usage of LED1 and LED2.
;							Initiates PORTB 11-13 ass Inputs for usage of BUTTON inputs.
;
;********************************************************************************************/
setup_init_inputs_and_outputs:
	LDI R16,(1 << LED1)|(1 << LED2)
	LDI R17,(1 << BUTTON1)|(1 << BUTTON2)|(1 << RESET_BUTTON)
	OUT DDRB,R16
	OUT PORTB,R17
;/*******************************************************************************************
; setup_init_pci_interupts: Initiates Interupts on pin 11-13 and 
;							aktivates interupts in general.
;
;********************************************************************************************/
setup_init_pci_interupts:
	LDI R16,(1 << PCIE0)
	STS PCMSK0,R17
	STS PCICR, R16
	SEI
;/*******************************************************************************************
; setup_init_timer0: Initiates Interupts for timer-0 in normal mode
;					 The interupt is trigered every 16.4 ms.
;
;********************************************************************************************/
setup_init_timer0:
	LDI R16, (1 << CS02)|(1 << CS00)
	OUT TCCR0B,R16

;/*******************************************************************************************
; setup_init_timer1: Initiates Interupts for timer-1 in CTC mode. resest avfer counting to 256
;					 The interupt is trigered every 16.4 ms.
;
;********************************************************************************************/
setup_init_timer1:
	LDI R16,(1 << WGM12)|(1 << CS12)|(1 << CS10)
	STS TCCR1B,R16
	LDI R17, 0x00
	LDI R18, 0x01
	STS OCR1AH,R18
	STS OCR1AL,R17
	
;/*******************************************************************************************
; setup_init_timer2: Initiates Interupts for timer-2 in normal mode
;					 The interupt is trigered every 16.4 ms.
;
;********************************************************************************************/
setup_init_timer2:
	LDI R16, (1 << CS22)|(1 << CS21)|(1 << CS20) 
	STS TCCR2B,R16
	LDI R17,(1 << TOIE2)
	STS  TIMSK2,R17
;/*******************************************************************************************
; setup_init_load_memory:Loads R16 to R20 with LED1,LED2,RESET_BUTTON,BUTTON1 and BUTTON2
;						 so they only needs to be loaded once.
;
;********************************************************************************************/
setup_init_load_memory:
	LDI R16,(1 << LED1)
	LDI R17,(1 << LED2)
	LDI R18,(1 << BUTTON1)
	LDI R19,(1 << BUTTON2)
	LDI R20,(1 << RESET_BUTTON)
	LDI R30,0x00
	LDI R31,0x00
setup_end:
	RJMP main_loop
main: 
	JMP setup
main_loop:
	JMP main_loop

;/*******************************************************************************************
; led1_off: turns of the led on PORTB0 by loading the status off PORTB,
;				And seting only the bit PORTB0 to zero. 				 
;
;********************************************************************************************/
led1_off:
	IN R25,PORTB
	ANDI R25,~(1 << LED1)
	OUT PORTB,R25
	RET
;/*******************************************************************************************
; led2_off: turns of the led on PORTB1 by loading the status off PORTB,
;				And seting only the bit PORTB1 to zero. 				 
;
;********************************************************************************************/
led2_off:
	IN R25,PORTB
	ANDI R25,~(1 << LED2)
	OUT PORTB,R25
	RET
	

