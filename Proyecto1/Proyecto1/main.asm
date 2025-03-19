/*******************/
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Lab3.asm
;
; Created: 2/19/2025 4:00:23 PM
; Author : Matheo
; Hardware ATMega 328P

.include "M328PDEF.inc"  ; Incluir definiciones de ATmega328P

.dseg	// GUARDAR VARIABLES EN SRAM
.org	SRAM_START // APUNTA A 0x0100
UNI_MIN:		.byte	1
DEC_MIN:		.byte	1
UNI_HOR:		.byte	1
DEC_HOR:		.byte	1

UNI_DIA:		.byte	1
DEC_DIA:		.byte	1
UNI_MES:		.byte	1
DEC_MES:		.byte	1

UNI_MIN_ALARM:	.byte	1
DEC_MIN_ALARM:	.byte	1
UNI_HOR_ALARM:	.byte	1
DEC_HOR_ALARM:	.byte	1


MODE:		.byte	1

.cseg
.org 0x0000
    JMP START

.org 0x0006   ; Dirección del vector de interrupción PCINT0
    JMP PCINT0_ISR

.org 0x001A
	JMP	TIMR1_ISR

.org 0x0020  ; Vector de interrupción del Timer0 Overflow
	JMP TIMR0_ISR



tabla7seg: .DB  0x81, 0xCF, 0x92, 0x86, 0xCC, 0xA4, 0xA0, 0x8F, 0x80, 0x84

tablameses_uni: .DB 1, 8, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1
tablameses_dec: .DB 3, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3

.equ TIMER0_INICIAL = 178 // 178
.equ MODES = 8
.equ ONE_MINUTE = 60
.equ TIMER1_INICIAL = 0xC2F7

.def CONTADOR_500MS = R0
.def CONTADOR_1MIN = R1
.def CONTADOR2_500MS = R2
.def MES = R3
.def FLAG_SUMAR = R4
.def FLAG_RESTAR = R5
.def FLAG_ALARM = R10
.def ALARM_MIN = R6
.def ALARM_HOR = R7
.def ALARM_MIN_CONFIGURE = R8
.def ALARM_HOR_CONFIGURE = R9
.def ALARM_OFF = R11

.def TRANSISTORES  = R19
.def DISPLAY1 = R20
.def DISPLAY2 = R21
.def DISPLAY3 = R22
.def DISPLAY4 = R23

 

// Configuración de la pila
START:
	LDI     R16, LOW(RAMEND)
	OUT     SPL, R16
	LDI     R16, HIGH(RAMEND)
	OUT     SPH, R16

SETUP:
	CLI		// DESACTICAR INTERRUPCIONES GLOBALES
	
	//	CONFIGURA EL CLOCK GENERAL CON UN PRESCALER DE 16 (1MHz)
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16 // Habilitar cambio de PRESCALER
	LDI R16, 0b00000100
	STS CLKPR, R16 // Configurar Prescaler a 16 F_cpu = 1MHz

	// Configurar PORTD como salida (para mostrar display de 7 segmentos)
    LDI     R16, 0xFF
    OUT     DDRD, R16  ; PORTD como salida

	// Configurar PORTC como salida (para LEDS)
    LDI     R16, 0xFF
    OUT     DDRC, R16  ; PORTC como salida

	// Configurar PORTB PB3 | PB4 | PB5 como salida (para LEDS)
	SBI		DDRB, PB3
    SBI		DDRB, PB4
	SBI		DDRB, PB5
	// Configurar PB0, PB1, PB2 entrada con pull-ups activados
	CBI		DDRB, PB0
  	CBI		DDRB, PB1
	CBI		DDRB, PB2
	// ACTIVAR PULL-UPS
	SBI		PORTB, PB0
	SBI		PORTB, PB1
	SBI		PORTB, PB2

	//HABILITAR INTERRUPCIONES EN PCINT0
	LDI		R16, (1 << PCIE0)
	STS		PCICR, R16			//HABILITAR INTERRUPCIONES EN PORTB

	LDI		R16, (1 << PCINT0) | (1 << PCINT1) | (1 << PCINT2) | (1 << PCINT5)
	STS		PCMSK0, R16			// HABILITAR INTERRUPCIONES EN PINES 0 ,1, 2 Y 5 DE PORTB

	// INICIALIZAR TIMER0 EN 5ms
	LDI		R16, (1 << CS01) | (1 << CS00)	// CONFIGURAR PRESCALER EN 64
	OUT		TCCR0B, R16
	LDI		R16, TIMER0_INICIAL	// CARGAR VALOR INICIAL DE TCNT0
	OUT		TCNT0, R16
	// HABILITAR INTERRUPCIONES TOV0
	LDI		R16, (1 << TOIE0)
	STS		TIMSK0, R16

	// INICIALIZAR TIMER1 EN 60 SEGUNDOS
	LDI		R16, (1 << CS01) | (1 << CS00)	// CONFIGURAR PRESCALER EN 64
	STS		TCCR1B, R16

	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16					// ACTIVAR INTERRUPCIONES DE OVERFLOW DEL TIMER1

	LDI		R16, HIGH(TIMER1_INICIAL)   ; Cargar la parte alta (0xC2)
    STS		TCNT1H, R16					; Escribir en TCNT1H
    LDI		R16, LOW(TIMER1_INICIAL)    ; Cargar la parte baja (0xF7)
    STS		TCNT1L, R16					; Escribir en TCNT1L

	

 
    // INICIALIZAR VARIABLES
	LDI		R16, 0x00
	OUT		PORTD, R16  ; Asegurar que PORTD inicia en un estado bajo
	LDI		R16, 0x0F
	OUT		PORTC, R16

	LDI		ZL, LOW(tabla7seg << 1)
	LDI		ZH, HIGH(tabla7seg << 1)

	LPM		DISPLAY1, Z
	LPM		DISPLAY2, Z
	LPM		DISPLAY3, Z
	LPM		DISPLAY4, Z

	CLR		TRANSISTORES

	CLR		MES

	LDI		R16, 0
	STS		UNI_MIN, R16	
	STS		DEC_MIN, R16
	STS		UNI_HOR, R16	
	STS		DEC_HOR, R16
		
	STS		DEC_DIA, R16	
	STS		DEC_MES, R16

	STS		UNI_MIN_ALARM, R16	
	STS		DEC_MIN_ALARM, R16	
	STS		UNI_HOR_ALARM, R16	
	STS		DEC_HOR_ALARM, R16	

	STS		MODE, R16		
	
	LDI		R16, 1
	STS     UNI_DIA, R16
	STS		UNI_MES, R16

	CLR		FLAG_SUMAR
	CLR		FLAG_RESTAR
	CLR		FLAG_ALARM

	CLR		ALARM_MIN
	CLR		ALARM_HOR

	CLR		ALARM_MIN_CONFIGURE
	CLR		ALARM_HOR_CONFIGURE

	 ; Activar solo el transistor del display actual
    LDI     R18, 0x00    
    OUT     PORTC, R18

	SEI		// HABILITAR INTERRUPCIONES GLOBALES

	
MAIN_LOOP:
// Verificar si han pasado 500 ms (100 interrupciones de 5 ms)
	LDI		R16, 100
    CP		CONTADOR_500MS, R16
    BRNE    CONTINUAR_LOOP
    // Alternar el estado de PB4
	SBI		PINB, PB4
    // Reiniciar el contador de 500 ms
    CLR     CONTADOR_500MS

CONTINUAR_LOOP:
	LDS		R16, MODE
	
	CPI		R16, 0
	BREQ	SALTAR_CLOCK_STATE
	
	CPI		R16, 1
	BREQ	SALTAR_CALENDAR_STATE
	
	CPI		R16, 2
	BREQ	SALTAR_CONFIGURE_CLOCK_HOURS
	
	CPI		R16, 3
	BREQ	SALTAR_CONFIGURE_CLOCK_MINUTES
	
	CPI		R16, 4
	BREQ	SALTAR_CONFIGURE_CALENDAR_MES
	
	CPI		R16, 5
	BREQ	SALTAR_CONFIGURE_CALENDAR_DIA

	CPI		R16, 6
	BREQ	SALTAR_CONFIGURE_ALARM_HOUR

	CPI		R16, 7
	BREQ	SALTAR_CONFIGURE_ALARM_MIN

	CPI		R16, 8
	BREQ	SALTAR_ON_OFF_ALARM
	
// SALTOS SEGUN EL MODO
SALTAR_CLOCK_STATE:
	RJMP	CLOCK_STATE

SALTAR_CALENDAR_STATE:
	RJMP	CALENDAR_STATE

SALTAR_CONFIGURE_CLOCK_MINUTES:
	RJMP	CONFIGURE_CLOCK_MINUTES

SALTAR_CONFIGURE_CLOCK_HOURS:
	RJMP	CONFIGURE_CLOCK_HOURS

SALTAR_CONFIGURE_CALENDAR_DIA:
	RJMP	CONFIGURE_CALENDAR_DAY

SALTAR_CONFIGURE_CALENDAR_MES:
	RJMP	CONFIGURE_CALENDAR_MES

SALTAR_CONFIGURE_ALARM_HOUR:
	RJMP	CONFIGURE_ALARM_HOUR

SALTAR_CONFIGURE_ALARM_MIN:
	RJMP	CONFIGURE_ALARM_MIN

SALTAR_ON_OFF_ALARM:
	RJMP	ON_OFF_ALARM

CLOCK_STATE:
	CBI		PORTC, PC4
	CBI		PORTC, PC5
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL RELOJ
	LDS		R16, UNI_MIN
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY1, Z

	LDS		R16, DEC_MIN
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY2, Z

	LDS		R16, UNI_HOR
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY3, Z

	LDS		R16, DEC_HOR
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY4, Z
//  -----------------------------------------------------------------------------------------------

    LDI     R16, ONE_MINUTE         // Cargar 200 en R16 (1 minuto)
    CP      CONTADOR_1MIN, R16		// Comparar CONTADOR_1MIN con ONE_MINUTE
    BREQ	FOLLOW_CLOCK_STATE
	RJMP	EXIT_LOOP
FOLLOW_CLOCK_STATE:
	CALL	ONE_MINUTE_SUM
	RJMP	EXIT_LOOP		    


CALENDAR_STATE:
	SBI		PORTC, PC4
	CBI		PORTC, PC5
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL CALENDARIO
	LDS		R16, UNI_DIA
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY1, Z

	LDS		R16, DEC_DIA
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY2, Z

	LDS		R16, UNI_MES
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY3, Z

	LDS		R16, DEC_MES
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY4, Z
//  -----------------------------------------------------------------------------------------------
    LDI     R16, ONE_MINUTE         // Cargar 200 en R16 (1 minuto)
    CP      CONTADOR_1MIN, R16		// Comparar CONTADOR_1MIN con 200
    BREQ    FOLLOW_CALENDAR_STATE            
    RJMP	EXIT_LOOP

FOLLOW_CALENDAR_STATE:
	CALL	ONE_MINUTE_SUM
	RJMP	EXIT_LOOP



CONFIGURE_CLOCK_MINUTES:
	CBI		PORTC, PC4
	SBI		PORTC, PC5
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL RELOJ
	LDS		R16, UNI_MIN
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY1, R17

	LDS		R16, DEC_MIN
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY2, R17

	LDS		R16, UNI_HOR
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY3, Z

	LDS		R16, DEC_HOR
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY4, Z
//  -----------------------------------------------------------------------------------------------
	LDI		R16, 1
	CP		FLAG_SUMAR, R16
	BREQ	SUM_MINUTES
	CP		FLAG_RESTAR, R16
	BREQ	REST_MINUTES
	RJMP	EXIT_LOOP

SUM_MINUTES:
	CLR		FLAG_SUMAR
	INC		ALARM_MIN
	LDS     R16, UNI_MIN          // Cargar el valor de UNI_MIN en R16
    CPI     R16, 9                // Comparar UNI_MIN con 9
    BREQ    SUMAR_DEC_MIN_CONFIGURE         // Si es 9, saltar a SUMAR_DEC_MIN

    INC     R16                   // Incrementar UNI_MIN
    STS     UNI_MIN, R16          // Guardar el nuevo valor de UNI_MIN

	RJMP	EXIT_LOOP

SUMAR_DEC_MIN_CONFIGURE:
	//	ACTUALIZAR DISPLAY1 A CERO
    CLR     R16                   // Reiniciar UNI_MIN a 0
    STS     UNI_MIN, R16          // Guardar el nuevo valor de UNI_MIN
	//	--------------------------------

	LDS     R16, DEC_MIN          // Cargar el valor de DEC_MIN en R16
    CPI     R16, 5                // Comparar DEC_MIN con 5
    BREQ    OVERFLOW_MIN_CONFIGURE			// Si es 5, saltar a OVERFLOW_MIN_CONFIGURE

    INC     R16                   // Incrementar DEC_MIN
    STS     DEC_MIN, R16          // Guardar el nuevo valor de DEC_MIN

	RJMP	EXIT_LOOP

OVERFLOW_MIN_CONFIGURE:
	CLR		R16
	STS		DEC_MIN, R16
	STS		UNI_MIN, R16

	CLR		ALARM_MIN

	RJMP	EXIT_LOOP

REST_MINUTES:
	CLR		FLAG_RESTAR
	DEC		ALARM_MIN
	LDS     R16, UNI_MIN          // Cargar el valor de UNI_MIN en R16
    CPI     R16, 0                // Comparar UNI_MIN con 0
    BREQ    RESTAR_DEC_MIN_CONFIGURE         // Si es 0, saltar a RESTAR_DEC_MIN

    DEC     R16                   // Incrementar UNI_MIN
    STS     UNI_MIN, R16          // Guardar el nuevo valor de UNI_MIN

	RJMP	EXIT_LOOP

RESTAR_DEC_MIN_CONFIGURE:
    LDI     R16, 9                // Reiniciar UNI_MIN a 0
    STS     UNI_MIN, R16          // Guardar el nuevo valor de UNI_MIN
	//	--------------------------------

	LDS     R16, DEC_MIN          // Cargar el valor de DEC_MIN en R16
    CPI     R16, 0                // Comparar DEC_MIN con 0
    BREQ    UNDERFLOW_MIN_CONFIGURE			// Si es 0, saltar a UNDERFLOW_MIN_CONFIGURE

    DEC     R16                   // DECREMENTAR DEC_MIN
    STS     DEC_MIN, R16          // Guardar el nuevo valor de DEC_MIN

	RJMP	EXIT_LOOP

UNDERFLOW_MIN_CONFIGURE:
	LDI		R16, 5
	STS		DEC_MIN, R16
	LDI		R16, 9
	STS		UNI_MIN, R16
	LDI		R16, 59
	MOV		ALARM_MIN, R16

	RJMP	EXIT_LOOP

// ESTADO DE CONFIGURAR HORAS DEL RELOJ
CONFIGURE_CLOCK_HOURS:
	CLR		CONTADOR_1MIN
	CBI		PORTC, PC4
	SBI		PORTC, PC5

// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL RELOJ
	LDS		R16, UNI_MIN
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY1, Z


	LDS		R16, DEC_MIN
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY2, Z


	LDS		R16, UNI_HOR
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY3, R17

	LDS		R16, DEC_HOR
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY4, R17
//  -----------------------------------------------------------------------------------------------
	LDI		R16, 1
	CP		FLAG_SUMAR, R16
	BREQ	SUM_HOR
	CP		FLAG_RESTAR, R16
	BREQ	REST_HOR

	RJMP	EXIT_LOOP

SUM_HOR:
	CLR		FLAG_SUMAR
	INC		ALARM_HOR
	LDS		R16, DEC_HOR
	CPI		R16, 2
	BREQ	CHECK_UNI_HOR_CONFIGURE

	LDS     R16, UNI_HOR          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 9                // Comparar UNI_HOR con 9
    BREQ    SUMAR_DEC_HOR_CONFIGURE		  // Si es 9, saltar a SUMAR_UNI_HOR
	
FOLLOW_ROUTINE_UNI_HOR_CONFIGURE:
    INC     R16                   // Incrementar DEC_MIN
    STS     UNI_HOR, R16          // Guardar el nuevo valor de DEC_MIN
	RJMP	EXIT_LOOP

CHECK_UNI_HOR_CONFIGURE:
	LDS     R16, UNI_HOR          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 3
	BREQ	OVERFLOW_HOR
	RJMP	FOLLOW_ROUTINE_UNI_HOR_CONFIGURE       

SUMAR_DEC_HOR_CONFIGURE:
    // ACTUALIZAR DISPLAY3 A CERO
    CLR     R16                   // Reiniciar UNI_HOR a 0
    STS     UNI_HOR, R16          // Guardar el nuevo valor de UNI_HOR

    LDS     R16, DEC_HOR          // Cargar el valor de DEC_HOR en R16

    // INCREMENTAR DEC_HOR
    INC     R16                   // Incrementar DEC_HOR
    STS     DEC_HOR, R16          // Guardar el nuevo valor de DEC_HOR

	RJMP	EXIT_LOOP

OVERFLOW_HOR:
	CLR		R16
	STS		UNI_HOR, R16
	STS		DEC_HOR, R16

	CLR		ALARM_HOR

	RJMP	EXIT_LOOP

REST_HOR:
	CLR		FLAG_RESTAR
	DEC		ALARM_HOR
	LDS     R16, UNI_HOR          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 0                // Comparar UNI_HOR con 9
    BREQ    RESTAR_DEC_HOR_CONFIGURE		  // Si es 9, saltar a SUMAR_UNI_HOR
	
    DEC     R16                   // Incrementar DEC_MIN
    STS     UNI_HOR, R16          // Guardar el nuevo valor de DEC_MIN
	RJMP	EXIT_LOOP
    

RESTAR_DEC_HOR_CONFIGURE:
    LDI     R16, 9                   // Reiniciar UNI_HOR a 9
    STS     UNI_HOR, R16          // Guardar el nuevo valor de UNI_HOR

    LDS     R16, DEC_HOR          // Cargar el valor de DEC_HOR en R16
	CPI		R16, 0
	BREQ	UNDERFLOW_HOR

    // DECREMENTAR DEC_HOR
    DEC     R16                   // Incrementar DEC_HOR
    STS     DEC_HOR, R16          // Guardar el nuevo valor de DEC_HOR

	RJMP	EXIT_LOOP

UNDERFLOW_HOR:
	LDI		R16, 3
	STS		UNI_HOR, R16

	LDI		R16, 2
	STS		DEC_HOR, R16

	LDI		R16, 23
	MOV		ALARM_HOR, R16

	RJMP	EXIT_LOOP

CONFIGURE_CALENDAR_DAY:
	SBI		PORTC, PB4
	SBI		PORTC, PB5
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL CALENDARIO
	LDS		R16, UNI_DIA
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY1, R17

	LDS		R16, DEC_DIA
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY2, R17

	LDS		R16, UNI_MES
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY3, Z

	LDS		R16, DEC_MES
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY4, Z
//  -----------------------------------------------------------------------------------------------
	
	LDI		R16, 1
	CP		FLAG_SUMAR, R16
	BREQ	SUM_DAY
	CP		FLAG_RESTAR, R16
	BREQ	REST_DAY

	RJMP	EXIT_LOOP

SUM_DAY:
	CLR		FLAG_SUMAR
	// VERIFICAR UNI_DIA SEGUN EL MES
	LDI     ZL, LOW(tablameses_dec << 1) // Cargar la dirección de la tabla de MESES DECENAS
    LDI     ZH, HIGH(tablameses_dec << 1)
    ADD     ZL, MES               // Sumar el valor de MES a la dirección de la tabla
    LDI     R17, 0                // Cargar 0 en R17
    ADC     ZH, R17				  // Añadir el carry a la parte alta del puntero
	LPM		R17, Z				  // EN R17 TENEMOS HASTA QUE DECENA DE DIA DEBEMOS LLEGAR SEGUN EL MES

    LDS     R16, DEC_DIA          // Cargar el valor de DEC_DIA en R16
    CP		R16, R17                // Comparar DEC_DIA con EL DIA SEGUN EL ES
    BREQ    CHECK_UNI_DIA_CONFIGURE       // Si DEC_DIA coinicide con el valor de la tabla, saltar a CHECK_UNI_DIA_CONFIGURE

	LDS     R16, UNI_DIA          // Cargar el valor de UNI_DIA en R16
    CPI     R16, 9                // Comparar UNI_DIA con 9
    BREQ    SUMAR_DEC_DIA_CONFIGURE		  // Si es 9, saltar a SUMAR_DEC_DIA_CONFIGURE

FOLLOW_ROUTINE_UNI_DIA_CONFIGURE:
    // INCREMENTAR UNI_DIA
    INC     R16                   // Incrementar UNI_DIA
    STS     UNI_DIA, R16          // Guardar el nuevo valor de UNI_DIA

    RJMP    EXIT_LOOP             // Saltar a EXIT_LOOP

SUMAR_DEC_DIA_CONFIGURE:
	// ACTUALIZAR VALOR DE UNI_DIA
    CLR     R16                   // Reiniciar UNI_DIA a 0
    STS     UNI_DIA, R16          // Guardar el nuevo valor de UNI_DIA
	//	------------------------------------------------------------

	LDS     R16, DEC_DIA          // Cargar el valor de DEC_DIA en R16

    // INCREMENTAR DEC_DIA
    INC     R16                   // Incrementar DEC_HOR
    STS     DEC_DIA, R16          // Guardar el nuevo valor de DEC_DIA

    RJMP    EXIT_LOOP             // Saltar a EXIT_LOOP

CHECK_UNI_DIA_CONFIGURE:   
	LDI     ZL, LOW(tablameses_uni << 1) // Cargar la dirección de la tabla de MESES UNIDADES
    LDI     ZH, HIGH(tablameses_uni << 1)
    ADD     ZL, MES               // Sumar el valor de MES a la dirección de la tabla
    LDI     R17, 0                // Cargar 0 en R17
    ADC     ZH, R17				  // Añadir el carry a la parte alta del puntero
	LPM		R17, Z				  // GUARDAR EL VALOR DE QUE APUNTA Z EN R17

	LDS		R16, UNI_DIA
	CP		R16, R17			 // COMPARO EL DIA QUE VAMOS, CON EL DIA DE LA TABLA SEGUN EL NUMERO DE MES
	BREQ	OVERFLOW_DAY		 // SI LO VALRES COINCIDEN SIGNIFICA QUE HAY UN OVERFLOW DEL DÍA
	RJMP	FOLLOW_ROUTINE_UNI_DIA_CONFIGURE

OVERFLOW_DAY:
	// SE RESETEAN LOS DÍAS A 01a
	LDI		R16, 1
	STS		UNI_DIA, R16
	LDI		R16, 0
	STS		DEC_DIA, R16
	RJMP	EXIT_LOOP


REST_DAY:
	CLR		FLAG_RESTAR
	
    LDS     R16, DEC_DIA          // Cargar el valor de DEC_DIA en R16
    CPI		R16, 0               // Comparar DEC_DIA con CERO
    BREQ    CHECK_DEC_DIA_CONFIGURE       // Si DEC_DIA es 0, saltar a CHECK_DEC_DIA_CONFIGURE


	LDS     R16, UNI_DIA          // Cargar el valor de UNI_DIA en R16
    CPI     R16, 0                // Comparar UNI_HOR con 0
    BREQ    RESTAR_DEC_DIA_CONFIGURE		  // Si es 0, saltar a RESTAR_DEC_DIA_CONFIGURE

FOLLOW_ROUTINE_DEC_DIA_CONFIGURE:
    // DECREMENTAR UNI_DIA
    DEC     R16                   // DECREMENTAR UNI_DIA
    STS     UNI_DIA, R16          // Guardar el nuevo valor de DEC_HOR

    RJMP    EXIT_LOOP             // Saltar a EXIT_LOOP

RESTAR_DEC_DIA_CONFIGURE:
    LDI     R16, 9                   // Reiniciar UNI_DIA a 9
    STS     UNI_DIA, R16          // Guardar el nuevo valor de UNI_HOR
	//	------------------------------------------------------------

	LDS     R16, DEC_DIA          // Cargar el valor de DEC_DIA en R16

    // DECREMENTAR DEC_DIA
    DEC     R16                   // DECREMENTAR DEC_DIA
    STS     DEC_DIA, R16          // Guardar el nuevo valor de DEC_DIA

    RJMP    EXIT_LOOP             // Saltar a EXIT_LOOP

CHECK_DEC_DIA_CONFIGURE:   
	// SE REVISA QUE QUE UNI_DIA NO SE AUNO
	LDS		R16, UNI_DIA
	CPI		R16, 1
	BREQ	UNDERFLOW_DAY	// SI LO ES SALTAMOS A UNDERFLOW_DAY
	RJMP	FOLLOW_ROUTINE_DEC_DIA_CONFIGURE

UNDERFLOW_DAY:
	// ACTUALIZAR DEC_DIA SEGUN EL MES
	LDI     ZL, LOW(tablameses_dec << 1) // Cargar la dirección de la tabla de MESES DECENAS
    LDI     ZH, HIGH(tablameses_dec << 1)
    ADD     ZL, MES               // Sumar el valor de MES a la dirección de la tabla
    LDI     R16, 0                // Cargar 0 en R17
    ADC     ZH, R16				  // Añadir el carry a la parte alta del puntero
	LPM		R16, Z				  // EN R17 TENEMOS HASTA QUE DECENA DE DIA DEBEMOS LLEGAR SEGUN EL MES
	STS		DEC_DIA, R16
	// ACTUALIZAR  UNI_DIA SEGUN EL MES
	LDI     ZL, LOW(tablameses_uni << 1) // Cargar la dirección de la tabla de MESES UNIDADES
    LDI     ZH, HIGH(tablameses_uni << 1)
    ADD     ZL, MES               // Sumar el valor de MES a la dirección de la tabla
    LDI     R16, 0                // Cargar 0 en R17
    ADC     ZH, R16				  // Añadir el carry a la parte alta del puntero
	LPM		R16, Z				  // EN R17 TENEMOS HASTA QUE UNIDAD DE DIA DEBEMOS LLEGAR SEGUN EL MES
	STS		UNI_DIA, R16

	RJMP	EXIT_LOOP

CONFIGURE_CALENDAR_MES:
	SBI		PORTC, PB4
	SBI		PORTC, PB5
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL CALENDARIO
	LDI		R16, 1
	STS		UNI_DIA, R16
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY1, Z
	
	LDI		R16, 0
	STS		DEC_DIA, R16
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	LPM		DISPLAY2, Z
	

	LDS		R16, UNI_MES
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY3, R17

	LDS		R16, DEC_MES
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY4, R17
//  -----------------------------------------------------------------------------------------------
	LDI		R16, 1
	CP		FLAG_SUMAR, R16
	BREQ	SUM_MES
	CP		FLAG_RESTAR, R16
	BREQ	REST_MES
	RJMP	EXIT_LOOP

SUM_MES:
	INC		MES
	CLR		FLAG_SUMAR
	LDS		R16, DEC_MES
	CPI		R16, 1
	BREQ	CHECK_UNI_MES_CONFIGURE

	LDS     R16, UNI_MES          // Cargar el valor de UNI_MES en R16
    CPI     R16, 9                // Comparar UNI_MES con 9
    BREQ    SUMAR_DEC_MES_CONFIGURE		  // Si es 9, saltar a SUMAR_DEC_MES_CONFIGURE

FOLLOW_ROUTINE_UNI_MES_CONFIGURE:
    INC     R16                   // Incrementar UNI_MES
    STS     UNI_MES, R16          // Guardar el nuevo valor de UNI_MES

	RJMP	EXIT_LOOP

CHECK_UNI_MES_CONFIGURE:
	LDS     R16, UNI_MES          // Cargar el valor de UNI_MES en R16
    CPI     R16, 2
	BREQ	OVERFLOW_MES
	RJMP	FOLLOW_ROUTINE_UNI_MES_CONFIGURE   

SUMAR_DEC_MES_CONFIGURE:
	LDI		R16, 0
	STS		UNI_MES, R16
	LDS     R16, DEC_MES         // Cargar el valor de DEC_MES en R16

    // INCREMENTAR DEC_MES
    INC     R16                   // Incrementar DEC_MES
    STS     DEC_MES, R16          // Guardar el nuevo valor de DEC_MES

    RJMP    EXIT_LOOP             // Saltar a EXIT_LOOP
	
OVERFLOW_MES:
	// REINICIAR MES A O1
	LDI		R16, 1
	STS		UNI_MES, R16
	LDI		R16, 0
	STS		DEC_MES, R16
	CLR		MES
	RJMP	EXIT_LOOP

// RESTAR AL MES
REST_MES:
	DEC		MES
	CLR		FLAG_RESTAR
	LDS		R16, DEC_MES
	CPI		R16, 0
	BREQ	CHECK_UNI_MES_CONFIGURE_REST

	LDS     R16, UNI_MES          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 0                // Comparar UNI_HOR con 9
    BREQ    RESTAR_DEC_MES_CONFIGURE		  // Si es 9, saltar a SUMAR_UNI_HOR

FOLLOW_ROUTINE_UNI_MES_CONFIGURE_REST:
    DEC     R16                   // Incrementar DEC_MIN
    STS     UNI_MES, R16          // Guardar el nuevo valor de DEC_MIN

	RJMP	EXIT_LOOP

CHECK_UNI_MES_CONFIGURE_REST:
	LDS     R16, UNI_MES          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 1
	BREQ	UNDERFLOW_MES
	RJMP	FOLLOW_ROUTINE_UNI_MES_CONFIGURE_REST   

RESTAR_DEC_MES_CONFIGURE:
	LDI		R16, 9
	STS		UNI_MES, R16

	LDS     R16, DEC_MES         // Cargar el valor de DEC_DIA en R16
    // DECREMENTAR DEC_MES
    DEC     R16                   // Incrementar DEC_MES
    STS     DEC_MES, R16          // Guardar el nuevo valor de DEC_MES

    RJMP    EXIT_LOOP             // Saltar a EXIT_CALL
	
UNDERFLOW_MES:
	LDI		R16, 2
	STS		UNI_MES, R16
	LDI		R16, 1
	STS		DEC_MES, R16
	LDI		R16, 11
	MOV		MES, R16
	RJMP	EXIT_LOOP


CONFIGURE_ALARM_HOUR:
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL RELOJ
	LDS		R16, UNI_MIN_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY1, Z


	LDS		R16, DEC_MIN_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY2, Z


	LDS		R16, UNI_HOR_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY3, R17

	LDS		R16, DEC_HOR_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY4, R17
//  -----------------------------------------------------------------------------------------------
	LDI		R16, 100
	CP		CONTADOR2_500MS, R16
	BRNE	FOLLOW_ALARM_STATE_HOUR
	// Alternar el estado de PC4 Y PC5
	SBI		PINC, PC4
	SBI		PINC, PC5
	CLR		CONTADOR2_500MS

FOLLOW_ALARM_STATE_HOUR:
	LDI		R16, 1
	CP		FLAG_SUMAR, R16
	BREQ	SUM_HOR_ALARM
	CP		FLAG_RESTAR, R16
	BREQ	REST_HOR_ALARM

	RJMP	EXIT_LOOP

SUM_HOR_ALARM:
	INC		ALARM_HOR_CONFIGURE
	CLR		FLAG_SUMAR
	LDS		R16, DEC_HOR_ALARM
	CPI		R16, 2
	BREQ	CHECK_UNI_HOR_CONFIGURE_ALARM

	LDS     R16, UNI_HOR_ALARM          // Cargar el valor de UNI_HOR_ALARM en R16
    CPI     R16, 9                // Comparar UNI_HOR_ALARM con 9
    BREQ    SUMAR_DEC_HOR_CONFIGURE_ALARM		  // Si es 9, saltar a SUMAR_UNI_HOR_ALARM
	
FOLLOW_ROUTINE_UNI_HOR_CONFIGURE_ALARM:
    INC     R16                   // Incrementar UNI_HOR_ALARM
    STS     UNI_HOR_ALARM, R16          // Guardar el nuevo valor de UNI_HOR_ALARM
	RJMP	EXIT_LOOP

CHECK_UNI_HOR_CONFIGURE_ALARM:
	LDS     R16, UNI_HOR_ALARM          // Cargar el valor de UNI_HOR_ALARM en R16
    CPI     R16, 3
	BREQ	OVERFLOW_HOR_ALARM
	RJMP	FOLLOW_ROUTINE_UNI_HOR_CONFIGURE_ALARM       

SUMAR_DEC_HOR_CONFIGURE_ALARM:
    // ACTUALIZAR DISPLAY3 A CERO
    CLR     R16                   // Reiniciar UNI_HOR_ALARM a 0
    STS     UNI_HOR_ALARM, R16          // Guardar el nuevo valor de UNI_HOR_ALARM

    LDS     R16, DEC_HOR_ALARM          // Cargar el valor de DEC_HOR_ALARM en R16

    // INCREMENTAR DEC_HOR
    INC     R16                   // Incrementar DEC_HOR_ALARM
    STS     DEC_HOR_ALARM, R16          // Guardar el nuevo valor de DEC_HOR_ALARM

	RJMP	EXIT_LOOP

OVERFLOW_HOR_ALARM:
	CLR		R16
	STS		UNI_HOR_ALARM, R16
	STS		DEC_HOR_ALARM, R16

	CLR		ALARM_HOR_CONFIGURE

	RJMP	EXIT_LOOP

REST_HOR_ALARM:
	DEC		ALARM_HOR_CONFIGURE
	CLR		FLAG_RESTAR
	LDS     R16, UNI_HOR_ALARM          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 0                // Comparar UNI_HOR con 9
    BREQ    RESTAR_DEC_HOR_CONFIGURE_ALARM		  // Si es 9, saltar a SUMAR_UNI_HOR
	
    DEC     R16                   // Incrementar DEC_MIN
    STS     UNI_HOR_ALARM, R16          // Guardar el nuevo valor de DEC_MIN
	RJMP	EXIT_LOOP
    

RESTAR_DEC_HOR_CONFIGURE_ALARM:
    LDI     R16, 9                   // Reiniciar UNI_HOR a 9
    STS     UNI_HOR_ALARM, R16          // Guardar el nuevo valor de UNI_HOR

    LDS     R16, DEC_HOR_ALARM          // Cargar el valor de DEC_HOR en R16
	CPI		R16, 0
	BREQ	UNDERFLOW_HOR_ALARM

    // DECREMENTAR DEC_HOR
    DEC     R16                   // Incrementar DEC_HOR
    STS     DEC_HOR_ALARM, R16          // Guardar el nuevo valor de DEC_HOR

	RJMP	EXIT_LOOP

UNDERFLOW_HOR_ALARM:
	LDI		R16, 3
	STS		UNI_HOR_ALARM, R16

	LDI		R16, 2
	STS		DEC_HOR_ALARM, R16

	LDI		R16, 23
	MOV		ALARM_HOR_CONFIGURE, R16

	RJMP	EXIT_LOOP

CONFIGURE_ALARM_MIN:
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL RELOJ
	LDS		R16, UNI_MIN_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY1, R17

	LDS		R16, DEC_MIN_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY2, R17

	LDS		R16, UNI_HOR_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY3, Z

	LDS		R16, DEC_HOR_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		DISPLAY4, Z
//  -----------------------------------------------------------------------------------------------
	LDI		R16, 100
	CP		CONTADOR2_500MS, R16
	BRNE	FOLLOW_ALARM_STATE_MIN
	// Alternar el estado de PC4 Y PC5
	SBI		PINC, PC4
	SBI		PINC, PC5
	CLR		CONTADOR2_500MS
FOLLOW_ALARM_STATE_MIN:
	LDI		R16, 1
	CP		FLAG_SUMAR, R16
	BREQ	SUM_MINUTES_ALARM
	CP		FLAG_RESTAR, R16
	BREQ	REST_MINUTES_ALARM
	RJMP	EXIT_LOOP

SUM_MINUTES_ALARM:
	CLR		FLAG_SUMAR
	INC		ALARM_MIN_CONFIGURE
	LDS     R16, UNI_MIN_ALARM          // Cargar el valor de UNI_MIN_ALARM en R16
    CPI     R16, 9                // Comparar UNI_MIN_ALARM  con 9
    BREQ    SUMAR_DEC_MIN_CONFIGURE_ALARM         // Si es 9, saltar a SUMAR_DEC_MIN_ALARM

    INC     R16                   // Incrementar UNI_MIN_ALAMR
    STS     UNI_MIN_ALARM, R16          // Guardar el nuevo valor de UNI_MIN_ALARM

	RJMP	EXIT_LOOP

SUMAR_DEC_MIN_CONFIGURE_ALARM:
    CLR     R16                   // Reiniciar UNI_MIN_ALARM a 0
    STS     UNI_MIN_ALARM, R16          // Guardar el nuevo valor de UNI_MIN_ALARM
	//	--------------------------------

	LDS     R16, DEC_MIN_ALARM          // Cargar el valor de DEC_MIN_ALARM en R16
    CPI     R16, 5                // Comparar DEC_MIN_ALARM con 5
    BREQ    OVERFLOW_MIN_CONFIGURE_ALARM			// Si es 5, saltar a OVERFLOW_MIN_CONFIGURE_ALARM

    INC     R16                   // Incrementar DEC_MIN_ALARM
    STS     DEC_MIN_ALARM, R16          // Guardar el nuevo valor de DEC_MIN_ALARM

	RJMP	EXIT_LOOP

OVERFLOW_MIN_CONFIGURE_ALARM:
	CLR		R16
	STS		DEC_MIN_ALARM, R16
	STS		UNI_MIN_ALARM, R16

	CLR		ALARM_MIN_CONFIGURE

	RJMP	EXIT_LOOP

REST_MINUTES_ALARM:
	CLR		FLAG_RESTAR
	DEC		ALARM_MIN_CONFIGURE
	LDS     R16, UNI_MIN_ALARM          // Cargar el valor de UNI_MIN_ALARM en R16
    CPI     R16, 0                // Comparar UNI_MIN_ALARM con 9
    BREQ    RESTAR_DEC_MIN_CONFIGURE_ALARM         // Si es 9, saltar a SUMAR_DEC_MIN_ALARM

    DEC     R16                   // Incrementar UNI_MIN_ALARM
    STS     UNI_MIN_ALARM, R16          // Guardar el nuevo valor de UNI_MIN_ALARM

	RJMP	EXIT_LOOP

RESTAR_DEC_MIN_CONFIGURE_ALARM:
    LDI     R16, 9                   // Reiniciar UNI_MIN_ALARM a 0
    STS     UNI_MIN_ALARM, R16          // Guardar el nuevo valor de UNI_MIN_ALARM
	//	--------------------------------

	LDS     R16, DEC_MIN_ALARM          // Cargar el valor de DEC_MIN_ALARM en R16
    CPI     R16, 0                // Comparar DEC_MIN_ALARM con 5
    BREQ    UNDERFLOW_MIN_CONFIGURE_ALARM			// Si es 5, saltar a OVERFLOW_MIN_CONFIGURE_ALARM

    DEC     R16                   // Incrementar DEC_MIN_ALARM
    STS     DEC_MIN_ALARM, R16          // Guardar el nuevo valor de DEC_MIN_ALARM

	RJMP	EXIT_LOOP

UNDERFLOW_MIN_CONFIGURE_ALARM:
	LDI		R16, 5
	STS		DEC_MIN_ALARM, R16
	LDI		R16, 9
	STS		UNI_MIN_ALARM, R16
	LDI		R16, 59
	MOV		ALARM_MIN_CONFIGURE, R16

	RJMP	EXIT_LOOP


ON_OFF_ALARM:
// ACTUALIZAR VALORES DEL LOS DISPLAYS A LOS DEL RELOJ
	LDS		R16, UNI_MIN_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY1, R17

	LDS		R16, DEC_MIN_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY2, R17

	LDS		R16, UNI_HOR_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY3, R17

	LDS		R16, DEC_HOR_ALARM
	LDI     ZL, LOW(tabla7seg << 1) // Cargar la dirección de la tabla de 7 segmentos
    LDI     ZH, HIGH(tabla7seg << 1)
	ADD		ZL, R16
	LDI		R17, 0
	ADC		ZH, R17
	LPM		R17, Z
	ANDI	R17, 0b01111111
	MOV		DISPLAY4, R17
//  -----------------------------------------------------------------------------------------------
	LDI		R16, 100
	CP		CONTADOR2_500MS, R16
	BRNE	FOLLOW_ON_OFF_ALARM
	// Alternar el estado de PC4 Y PC5
	SBI		PINC, PC4
	SBI		PINC, PC5
	CLR		CONTADOR2_500MS

FOLLOW_ON_OFF_ALARM:
	LDI		R16, 1
	CP		FLAG_SUMAR, R16
	BREQ	ACTIVATE_ALARM
	CP		FLAG_RESTAR, R16
	BREQ	DESACTIVATE_ALARM
	RJMP	EXIT_LOOP

ACTIVATE_ALARM:
	CLR		FLAG_SUMAR
	LDI		R16, 1
	MOV		FLAG_ALARM, R16
	SBI		PORTB, PB5
	RJMP	EXIT_LOOP

DESACTIVATE_ALARM:
	CLR		FLAG_RESTAR
	LDI		R16, 0
	MOV		FLAG_ALARM, R16
	CBI		PORTB, PB5
	RJMP	EXIT_LOOP

EXIT_LOOP:
    RJMP    MAIN_LOOP             // Volver al bucle principal


// SUB-RUTINAS SIN INTERRUPCION
ONE_MINUTE_SUM:
	CLR     CONTADOR_1MIN   
	INC		ALARM_MIN      
	
	LDI		R16, 1
	CP		FLAG_ALARM, R16
	BRNE	FOLLOW_ONE_MINUTE_SUM
	CP		ALARM_HOR_CONFIGURE, ALARM_HOR
	BRNE	FOLLOW_ONE_MINUTE_SUM
	CP		ALARM_MIN_CONFIGURE, ALARM_MIN
	BRNE	FOLLOW_ONE_MINUTE_SUM
	LDI		R16, 1
	MOV		ALARM_OFF, R16
	SBI		PORTB, PB3

FOLLOW_ONE_MINUTE_SUM:
    LDS     R16, UNI_MIN          // Cargar el valor de UNI_MIN en R16
	CPI     R16, 9                // Comparar UNI_MIN con 9
    BREQ    SUMAR_DEC_MIN         // Si es 9, saltar a SUMAR_DEC_MIN

    INC     R16                   // Incrementar UNI_MIN
    STS     UNI_MIN, R16          // Guardar el nuevo valor de UNI_MIN

	RJMP	EXIT_CALL
	

SUMAR_DEC_MIN:
	//	ACTUALIZAR DISPLAY1 A CERO
    CLR     R16                   // Reiniciar UNI_MIN a 0
    STS     UNI_MIN, R16          // Guardar el nuevo valor de UNI_MIN
	//	--------------------------------

	LDS     R16, DEC_MIN          // Cargar el valor de DEC_MIN en R16
    CPI     R16, 5                // Comparar DEC_MIN con 5
    BREQ    SUMAR_UNI_HOR			// Si es 5, saltar a SUMAR_UNI_HOR

    INC     R16                   // Incrementar DEC_MIN
    STS     DEC_MIN, R16          // Guardar el nuevo valor de DEC_MIN

	RJMP	EXIT_CALL

SUMAR_UNI_HOR:
	//	ACTUALIZAR DISPLAY2 A CERO
    CLR     R16                   // Reiniciar UNI_MIN a 0
	CLR		ALARM_MIN
    STS     DEC_MIN, R16          // Guardar el nuevo valor de UNI_MIN
	//	--------------------------------
	
	INC		ALARM_HOR

	LDI		R16, 1
	CP		FLAG_ALARM, R16
	BRNE	FOLLOW_SUMAR_UNI_HOR
	CP		ALARM_HOR_CONFIGURE, ALARM_HOR
	BRNE	FOLLOW_SUMAR_UNI_HOR
	CP		ALARM_MIN_CONFIGURE, ALARM_MIN
	BRNE	FOLLOW_SUMAR_UNI_HOR
	LDI		R16, 1
	MOV		ALARM_OFF, R16
	SBI		PORTB, PB3

FOLLOW_SUMAR_UNI_HOR:
	LDS		R16, DEC_HOR
	CPI		R16, 2
	BREQ	CHECK_UNI_HOR

	LDS     R16, UNI_HOR          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 9                // Comparar UNI_HOR con 9
    BREQ    SUMAR_DEC_HOR		  // Si es 9, saltar a SUMAR_UNI_HOR

FOLLOW_ROUTINE_UNI_HOR:
    INC     R16                   // Incrementar DEC_MIN
    STS     UNI_HOR, R16          // Guardar el nuevo valor de DEC_MIN

	RJMP	EXIT_CALL
CHECK_UNI_HOR:
	LDS     R16, UNI_HOR          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 3
	BREQ	SUMAR_UNI_DIA
	RJMP	FOLLOW_ROUTINE_UNI_HOR       


SUMAR_DEC_HOR:
    // ACTUALIZAR DISPLAY3 A CERO
    CLR     R16                   // Reiniciar UNI_HOR a 0
    STS     UNI_HOR, R16          // Guardar el nuevo valor de UNI_HOR

	INC		ALARM_HOR

    LDS     R16, DEC_HOR          // Cargar el valor de DEC_HOR en R16

    // INCREMENTAR DEC_HOR
    INC     R16                   // Incrementar DEC_HOR
    STS     DEC_HOR, R16          // Guardar el nuevo valor de DEC_HOR

    RJMP    EXIT_CALL             // Saltar a EXIT_CALL


SUMAR_UNI_DIA:
    // REINICIAR HORAS A 00:00
    CLR     R16                   // Reiniciar DEC_HOR a 0
    STS     DEC_HOR, R16          // Guardar el nuevo valor de DEC_HOR
    STS     UNI_HOR, R16          // Guardar el nuevo valor de UNI_HOR
	CLR		ALARM_MIN
	CLR		ALARM_HOR

	LDI		R16, 1
	CP		FLAG_ALARM, R16
	BRNE	FOLLOW_SUMAR_DIA
	CP		ALARM_HOR_CONFIGURE, ALARM_HOR
	BRNE	FOLLOW_SUMAR_DIA
	CP		ALARM_MIN_CONFIGURE, ALARM_MIN
	BRNE	FOLLOW_SUMAR_DIA
	LDI		R16, 1
	MOV		ALARM_OFF, R16
	SBI		PORTB, PB3
	//	--------------------------------------------------------------------

FOLLOW_SUMAR_DIA:
	// VERIFICAR UNI_DIA SEGUN EL MES
	LDI     ZL, LOW(tablameses_dec << 1) // Cargar la dirección de la tabla de MESES DECENAS
    LDI     ZH, HIGH(tablameses_dec << 1)
    ADD     ZL, MES               // Sumar el valor de DEC_HOR a la dirección de la tabla
    LDI     R17, 0                // Cargar 0 en R17
    ADC     ZH, R17				  // Añadir el carry a la parte alta del puntero
	LPM		R17, Z				  // EN R17 TENEMOS HASTA QUE DECENA DE DIA DEBEMOS LLEGAR SEGUN EL MES

    LDS     R16, DEC_DIA          // Cargar el valor de UNI_DIA en R16
    CP		R16, R17                // Comparar DEC_DIA con EL DIA SEGUN EL ES
    BREQ    CHECK_UNI_DIA       // Si DEC_HOR es 2, saltar a CHECK_UNI_HOR

	LDS     R16, UNI_DIA          // Cargar el valor de UNI_DIA en R16
    CPI     R16, 9                // Comparar UNI_HOR con 9
    BREQ    SUMAR_DEC_DIA		  // Si es 9, saltar a SUMAR_DEC_DIA

FOLLOW_ROUTINE_UNI_DIA:
    // INCREMENTAR UNI_DIA
    INC     R16                   // Incrementar UNI_DIA
    STS     UNI_DIA, R16          // Guardar el nuevo valor de UNI_DIA

    RJMP    EXIT_CALL             // Saltar a EXIT_CALL

CHECK_UNI_DIA:   
	LDI     ZL, LOW(tablameses_uni << 1) // Cargar la dirección de la tabla de MESES UNIDADES
    LDI     ZH, HIGH(tablameses_uni << 1)
    ADD     ZL, MES               // Sumar el valor de MES a la dirección de la tabla
    LDI     R17, 0                // Cargar 0 en R17
    ADC     ZH, R17				  // Añadir el carry a la parte alta del puntero
	LPM		R17, Z

	LDS		R16, UNI_DIA
	CP		R16, R17			 // COMPARO EL DIA QUE VAMOS, CON EL DIA DE LA TABLA SEGUN EL NUMERO DE MES
	BREQ	SUMAR_UNI_MES
	RJMP	FOLLOW_ROUTINE_UNI_DIA

SUMAR_DEC_DIA:
	// ACTUALIZAR DISPLAY1 A CERO
    CLR     R16                   // Reiniciar UNI_HOR a 0
    STS     UNI_DIA, R16          // Guardar el nuevo valor de UNI_HOR
	//	------------------------------------------------------------

	LDS     R16, DEC_DIA          // Cargar el valor de DEC_DIA en R16

    // INCREMENTAR DEC_HOR
    INC     R16                   // Incrementar DEC_DIA
    STS     DEC_DIA, R16          // Guardar el nuevo valor de DEC_DIA

    RJMP    EXIT_CALL             // Saltar a EXIT_CALL


SUMAR_UNI_MES:
//  INCREMENTAR VARIABLES DE MES
	INC		MES

	LDI		R16, 1
	STS		UNI_DIA, R16

	CLR		R16
	STS		DEC_DIA, R16
//	--------------------------------------------------------------------------------------------

	LDS		R16, DEC_MES
	CPI		R16, 1
	BREQ	CHECK_UNI_MES

	LDS     R16, UNI_MES          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 9                // Comparar UNI_HOR con 9
    BREQ    SUMAR_DEC_MES		  // Si es 9, saltar a SUMAR_UNI_HOR

FOLLOW_ROUTINE_UNI_MES:
    INC     R16                   // Incrementar DEC_MIN
    STS     UNI_MES, R16          // Guardar el nuevo valor de DEC_MIN

	RJMP	EXIT_CALL

CHECK_UNI_MES:
	LDS     R16, UNI_MES          // Cargar el valor de UNI_HOR en R16
    CPI     R16, 2
	BREQ	RESET_CLOCK
	RJMP	FOLLOW_ROUTINE_UNI_MES   

SUMAR_DEC_MES:
	// ACTUALIZAR DISPLAY3 A CERO
    CLR     R16                   // Reiniciar UNI_HOR a 0
    STS     UNI_MES, R16          // Guardar el nuevo valor de UNI_MES
	//	------------------------------------------------------------

	LDS     R16, DEC_MES         // Cargar el valor de DEC_DIA en R16

    // INCREMENTAR DEC_MES
    INC     R16                   // Incrementar DEC_MES
    STS     DEC_MES, R16          // Guardar el nuevo valor de DEC_MES

    RJMP    EXIT_CALL             // Saltar a EXIT_CALL
	
RESET_CLOCK:
	LDI		R16, 1
	STS		UNI_DIA, R16
	STS		UNI_MES, R16
	
	CLR		R16
	STS		DEC_DIA, R16
	STS		DEC_MES, R16

	CLR		MES
EXIT_CALL:
	RET

// SUB-RUTINAS DE INTERRUPCION
// TIMER 0
TIMR0_ISR:
    PUSH    R16
    PUSH    R18
    IN      R16, SREG
    PUSH    R16

    // Recargar el Timer0
    LDI     R16, TIMER0_INICIAL
    OUT     TCNT0, R16

	// SUMAR UNO AL LOS CONTADORES
	INC		CONTADOR_500MS 
	INC		CONTADOR2_500MS
	 
    // Seleccionar el display actual basado en TRANSISTORES
    CPI     TRANSISTORES, 0
    BRNE    CHECK2
    LDI     R18, 0x01     ; Display 1 (PC0 activado)
    OUT     PORTD, DISPLAY1
    RJMP    UPDATE_DISPLAY

CHECK2:
    CPI     TRANSISTORES, 1
    BRNE    CHECK3
    LDI     R18, 0x02     ; Display 2 (PC1 activado)
    OUT     PORTD, DISPLAY2
    RJMP    UPDATE_DISPLAY

CHECK3:
    CPI     TRANSISTORES, 2
    BRNE    CHECK4
    LDI     R18, 0x04     ; Display 3 (PC2 activado)
    OUT     PORTD, DISPLAY3
    RJMP    UPDATE_DISPLAY

CHECK4:
    LDI     R18, 0x08     ; Display 4 (PC3 activado)
    OUT     PORTD, DISPLAY4
    CLR     TRANSISTORES           ; Reiniciar TRANSISTORES a 0
    RJMP    UPDATE_DISPLAY_RESET

UPDATE_DISPLAY:
	INC     TRANSISTORES           ; Incrementar TRANSISTORES para el siguiente display
UPDATE_DISPLAY_RESET:
	IN		R16, PORTC
	ANDI	R16, 0b00110000
	ADD		R18, R16
    OUT     PORTC, R18    ; Activar el transistor del display actual

    

END_ISR_TIMER0:
    POP     R16
    OUT     SREG, R16
    POP     R18
    POP     R16
    RETI

// TIMER1
TIMR1_ISR:
	PUSH    R16
    IN      R16, SREG
    PUSH    R16

	LDI		R16, HIGH(TIMER1_INICIAL)   ; Cargar la parte alta (0xC2)
    STS		TCNT1H, R16					; Escribir en TCNT1H
    LDI		R16, LOW(TIMER1_INICIAL)    ; Cargar la parte baja (0xF7)
    STS		TCNT1L, R16					; Escribir en TCNT1L

	LDS		R16, MODE
	CPI		R16, 0
	BREQ	INCREMENTAR_CONTADOR_1MIN
	CPI		R16, 1
	BREQ	INCREMENTAR_CONTADOR_1MIN
	
	RJMP	END_ISR_TIMER1
	
	INCREMENTAR_CONTADOR_1MIN:
	INC		CONTADOR_1MIN				//INCREMENTAR EL CONTADOR DE UN MINUTO

END_ISR_TIMER1:
	POP     R16
    OUT     SREG, R16
    POP     R16

	RETI

PCINT0_ISR:
    PUSH    R16                  // Guardar el registro R16 en la pila
    IN      R16, SREG            // Guardar el registro de estado SREG
    PUSH    R16                  // Guardarlo en la pila para restaurarlo después

    // Verifica si el botón PB0 fue presionado (nivel lógico 0)
    SBIS    PINB, PB0            
    RJMP    CHANGE_MODE          // Si se presionó, salta a cambiar modo

    // Verifica si el botón PB1 fue presionado
    SBIS    PINB, PB1
    RJMP    CHANGE_ACTION_SUMAR  // Si se presionó, salta a la acción de sumar

    // Verifica si el botón PB2 fue presionado
    SBIS    PINB, PB2
    RJMP    CHANGE_ACTION_RESTAR // Si se presionó, salta a la acción de restar

    RJMP    END_ISR_PCINT0       // Si no se presionó ningún botón, salir de la ISR

CHANGE_MODE:
    LDS     R16, MODE            // Carga el valor actual del modo en R16
    CPI     R16, MODES           // Compara con el número total de modos
    BREQ    RESET_MODE           // Si se alcanzó el último modo, reiniciar modo
    INC     R16                  // Incrementar el modo
    STS     MODE, R16            // Guardar el nuevo modo en la variable MODE
    RJMP    END_ISR_PCINT0       // Salir de la ISR

RESET_MODE:
    CLR     R16                  // Limpiar R16 (modo 0)
    STS     MODE, R16            // Guardar el modo 0
    RJMP    END_ISR_PCINT0       // Salir de la ISR

CHANGE_ACTION_SUMAR:
    LDS     R16, MODE            // Cargar el modo actual
    CPI     R16, 0
    BREQ    APAGAR_ALARMA        // Si está en modo 0, apagar alarma
    CPI     R16, 1
    BREQ    APAGAR_ALARMA        // Si está en modo 1, apagar alarma
    LDI     R16, 1
    MOV     FLAG_SUMAR, R16      // Activar la bandera para sumar
    RJMP    END_ISR_PCINT0       // Salir de la ISR

APAGAR_ALARMA:
    LDI     R16, 1
    CP      ALARM_OFF, R16       // Verifica si la alarma ya está apagada
    BREQ    APAGAR               // Si ya está apagada, ejecuta APAGAR
    RJMP    END_ISR_PCINT0       // Si no, salir de la ISR

APAGAR:
    CLR     ALARM_OFF            // Apagar la alarma
    CBI     PORTB, PB3           // Limpiar el bit PB3 (apagar LED o señal)
    RJMP    END_ISR_PCINT0       // Salir de la ISR

CHANGE_ACTION_RESTAR:
    LDS     R16, MODE            // Cargar el modo actual
    CPI     R16, 0
    BREQ    END_ISR_PCINT0       // Si el modo es 0, salir
    CPI     R16, 1
    BREQ    END_ISR_PCINT0       // Si el modo es 1, salir
    LDI     R16, 1
    MOV     FLAG_RESTAR, R16     // Activar la bandera para restar
    RJMP    END_ISR_PCINT0       // Salir de la ISR

END_ISR_PCINT0:
    POP     R16                  // Restaurar R16 desde la pila
    OUT     SREG, R16            // Restaurar el registro de estado SREG
    POP     R16                  // Restaurar R16 desde la pila
    RETI                         // Retorno de la interrupción
