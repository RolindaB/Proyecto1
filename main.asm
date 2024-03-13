//******************************************************************************
//Universidad del Valle de GUatemala
//IE023: Programación de Microcontroladores
//Autor: Astryd Rolinda Magaly Beb Caal
//Proyecto: Proyecto #1
//Hardware: ATMEGA328P
//Created: 16-02-2024
//******************************************************************************
//Encabezado
//******************************************************************************
.include "M328PDEF.inc"
.def Estado = R20 
.cseg
.org 0x00
	 JMP Inicio// vector reset
.org 0x0008
	 JMP ISR_PCINT1
.org 0x001A
	JMP ISR_TIMER1_OVF// vector overflow timer1
.org 0x0020
	JMP ISR_TIMER0_OVF
; *****************************************************************************
; Tabla de conversión para los displays de 7 segmentos
; *****************************************************************************
TABLA: .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7C, 0x07, 0x7F, 0x6F

Inicio: 
//*****************************************************************************
// Stack Pointer
//*****************************************************************************
	LDI R16, LOW(RAMEND)
	OUT SPL, R16

	LDI R17, HIGH(RAMEND)
	OUT SPH, R17
//*****************************************************************************
; configuraciones
//*****************************************************************************
	LDI R16, 0b1000_0000
	LDI R16, (1 << CLKPCE) //Corrimiento a CLKPCE
	STS CLKPR, R16        // Habilitando el prescaler 
	LDI R16, 0b0000_0100
	STS CLKPR, R16   //Frecuencia del sistema de 1MHz

; ***************************
; CONFIGURACIÓN DE PUERTOS
; ***************************  
    LDI R16, 0b01111111
    OUT DDRD, R16   ; Configurar pin PD0 a PD6 Como salida

    LDI R16, 0b0001_1111
    OUT DDRB, R16   ; (PB1 y PB0  PB3 y PB4 como salida) multiplexación, pb2 leds parpadeo

	;modos leds
	LDI R16, (1<<PB5)
	OUT DDRB, R16
	LDI R16, (1<<PC5)
	OUT DDRC, R16

	;Entradas y pull-up
   	LDI R16, 0B0001_1111   ; Cargar un byte con los bits PC0, PC1, PC2 y PC3 establecidos
	OUT DDRC, R16          ; Configurar PC0, PC1, PC2, PC3 y PC4 como entradas
	OUT PORTC, R16         ; Habilitar las resistencias pull-up en PC0, PC1, PC2 y PC3

	
	LDI R16, (1 << PCINT8) | (1 << PCINT9) | (1 << PCINT10) | (1 << PCINT11)| (1<<PCINT12) ; Habilitar las interrupciones de PCINT8 a PCINT12
    STS PCMSK1, R16         ; Guardar en el registro PCMSK0 (máscara de interrupción)*/
	LDI R16, (1 << PCIE1)  ; Habilitar la interrupción de cambio de pin en PCINT0
	STS PCICR, R16          ; Guardar en el registro PCICR (controlador de interrupción)

	SEI //HABILITAR interrupciones globales

	LDI Estado, 1
	// iniciar con todos los display en 0
	LDI R23, 0 ;contador de pasadas del timer
    ; Inicializar contadores
    LDI R22, 0 ; Contador de las UNIDADES min
    LDI R21, 0  ; Contador de las DECENAS min
    LDI R19, 0  ; Contador de las UNIDADES hor
    LDI R17, 0  ; Contador de las DECENAS hor
	CLR R30 //CONTAR HORAS
	
; Inicializar contadores de fecha en 0
; El reloj inicia automaticamente en 1 de enero
	LDI R24, 1 ;unidad de dias
	CLR R26 ; decena de dias
	LDI R27, 1 ; unidad de mes
	CLR R28 ; decena de mes
	CLR R29 ; DIAS MES
	CLR R12; MES
	CLR R13; DIA
	
/*;alarma
	CLR R6 ; Contador de las UNIDADES min
	CLR R7	; Contador de las DECENAS min
	CLR R8	; Contador de las UNIDADES hor
	CLR R9	; Contador de las DECENAS hor*/
; INICIALIZAR TIMERS
	CALL INIT_TIMER1 ; inicialización del timer1
	CALL INIT_TIMER0; inicialización del timer0
    
	CLR R18 ;parpadeo

//*****************************************************************************

LOOP:
;RELOJ SIEMPRE CUENTA(no para)
; Verificar si han pasado 15 ciclos del timer (60 segundos)
	CPI R23, 15
	BREQ INCMIN
;estados
	SBRC Estado, 0
	JMP Hora
	SBRC  Estado, 1
	JMP conHora
	SBRC Estado,2
	JMP Fecha
	SBRC Estado, 3
	JMP conFecha
	SBRC Estado, 4
	JMP LOOP
; *****************************************************************************
; Rutina de inicialización del Timer0
; *****************************************************************************
INIT_TIMER0:     //Arrancar el TIMER0
	; Configurar el Timer0 para operar en modo normal
    LDI R16, 0
    OUT TCCR0A, R16

    ; Configurar el prescaler del Timer0 (1024)
    LDI R16, (1 << CS02) | (1 << CS00)
    OUT TCCR0B, R16

    ; Iniciar el Timer0 con un valor de 11 (0.25ms)
    LDI R16, 11
    OUT TCNT0, R16

    ; Activar la interrupción del Timer0 Overflow
    LDI R16, (1 << TOIE0)
    STS TIMSK0, R16

    RET

; *****************************************************************************
; Rutina de inicialización del Timer1
; *****************************************************************************
INIT_TIMER1:
    ; Modo normal del temporizador
    LDI R16, 0
    STS TCCR1A, R16

    ; Prescaler de 1024
    LDI R16, (1 << CS12) | (1 << CS10)
    STS TCCR1B, R16

    ; Valor inicial del contador
    LDI R16, 0xF0;F0;FC
    STS TCNT1H, R16   ; Valor inicial del contador alto
    LDI R16, 0xBD;BD;2F
    STS TCNT1L, R16   ; Valor inicial del contador bajo

    ; Activar interrupción del TIMER1 por overflow
    LDI R16, (1 << TOIE1)
    STS TIMSK1, R16
    RET// REGRESAR A SUBRUTINA


;Subrutinas


; ****************************************************************
; Rutina principal  del tiempo
; ****************************************************************
HORA:
	;SBI PORTB, PB5
	; Actualizar los displays de tiempo
	CALL MOSTRAR_H
	JMP LOOP
INCMIN:
	CLR R23
	INC R22
	CPI R22, 10
	BREQ RES_UMIN
	JMP LOOP	
RES_UMIN:
		CLR R22
		INC R21
; Verificar si las decenas de minutos llegaron a 6
		CPI R21, 6
		BREQ RES_UHOR
		JMP LOOP	
RES_UHOR:
		CLR R21
		INC R19
		CPI R19, 10
		BREQ RES_DHOR // verifica si 
		CPI R17, 2
		BREQ REes2
		JMP LOOP	

RES_DHOR:
		INC R17 // incrementa registro decena de hora
		CLR R19 // REINICIA REGISTRO DE UNIDAD DE HORA
		JMP LOOP	
REes2:
	CPI R19, 4
	BREQ RESET //RESETEAR TODO
	JMP LOOP	
RESET:
	; Reiniciar todos los contadores
	LDI R22, 0  ; Unidades de minutos
	LDI R21, 0  ; Decenas de minutos
	LDI R19, 0  ; Unidades de horas
	LDI R17, 0  ; Decenas de horas
	INC R24
	INC R13
	MOV R31, R12
    CPI R31, 0// enero
	BREQ Dias31x
	CPI R31, 1// febreo
	BREQ Dias28x
	CPI R31, 2//Marzo
	BREQ Dias31x
	CPI R31, 3//abril
	BREQ Dias30x
	CPI R31, 4//Mayo
	BREQ Dias31x
	CPI R31, 5//Junio
	BREQ Dias30x
	CPI R31, 6//JUlio
	BREQ Dias31x
	CPI R31,7//agosto
	BREQ Dias31x
	CPI R31,8//septiembre
	BREQ  Dias30x
	CPI R31,9//octubre
	BREQ Dias31x
	CPI R31,10//noviembre
	BREQ Dias30x
	CPI R31, 11//diciembre; */
	BREQ Dias31x
	JMP LOOP
Dias31x:
	LDI R29, 32
	JMP VerCasox
Dias28x:
	LDI R29, 31
	JMP VerCasox
Dias30x:
	LDI R29, 29
	JMP VerCasox
VerCasox:
	CP R13, R29; VERIFICA Que el numero de dias haya llegado al limiite segun  el mes
	BREQ AUMENTO
	CPI R24, 10; Verifica que la unidad de dia haya llegado a 9
	BREQ diferente_dia
AUMENTO:
	LDI R31,1
	MOV R13, R31
	CLR R26	;decena de dias
	LDI R24,1; UNidad de dias
	INC R27; UNIDAD DE MESES
	INC R12; MESES

	CPI R27, 10; verificar si la unidad de meses a llegado a 10
	BREQ otro_mes
	CPI R28, 1  //Cuando llegue el display 3 a mostar su maximo valor
	BREQ REST_YEAR
	JMP LOOP
otro_mes:
	INC R28; INCREMENTAR DECENA DE MES
	CLR R29; RESETEAR UNIDAD DE MES
	JMP LOOP
REST_YEAR:
	CPI R29, 3
	BRSH REST_YEAR2
	JMP LOOP
REST_YEAR2: ;este se resetea solo si es 31 de diciembre(año nuevo)
	CLR R28; resetea decena de meses
	CLR R26; resetea decena de dia
	LDI R24, 1; inicia en el primer dia de 
	LDI R27, 1; enero
	CLR R12
	MOV R13, R24
	JMP LOOP
diferente_dia:
	INC R26
	CLR R24
	JMP LOOP
;******************************************************************************
RETARDO:
    LDI R30, 125; Cargar con un valor a R30
	INC R5
delay:
   
   DEC R30        ; Decrementa R30
   BRNE delay     ; Si R30 no es igual a 0, vuelve al delay
   LDI R30, 125
Delay1:
		
	DEC R30
	BRNE Delay1     ; Si R30 no es igual a 0, vuelve al delay*/
	MOV R31, R5
	CPI R31,6
	BRNE RETARDO
	CLR R5

		RET
		
; ***********************************************************
; Rutinas para la gestión de los displays de horas
; ***********************************************************
MOSTRAR_H: 
//display u min
    CALL RETARDO  ; Retardo para la visualización
    ; Enciende el display de las unidades de minutos
    SBI PINB, PB4
    ; Obtén el valor de las unidades de minutos
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R22    ; R22 contiene las unidades de minutos
    LPM R25, Z
    OUT PORTD, R25  ; Muestra el valor en el display
//display 2 dmin
	CALL RETARDO  ; Retardo para la visualización
	SBI PINB, PB4  ; Apaga los otros displays
    ; Enciende el display de las decenas de minutos
    SBI PINB, PB3
    ; Obtén el valor de las decenas de minutos
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R21    ; R21 contiene las decenas de minutos
    LPM R25, Z
    OUT PORTD, R25  ; Muestra el valor en el display

// display3 u hor
	CALL RETARDO  ; Retardo para la visualización
	SBI PINB, PB3  ; Apagar otros displays
    ; Enciende el display de las unidades de horas
    SBI PINB, PB0
    ; valor de las unidades de horas
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R19    ; R19 contiene las unidades de horas
    LPM R25, Z
    OUT PORTD, R25  ; Mostrar el valor en el display
//display4 d hor
	CALL RETARDO  ; Retardo para la visualización
	SBI PINB, PB0  ; Apagar los otros displays
    ; Enciende el display de las decenas de horas
    SBI PINB, PB1
    ; valor de las decenas de horas
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R17    ; R17 contiene las decenas de horas
    LPM R25, Z
    OUT PORTD, R25  ; Muestra el valor en el display
	
	call RETARDO
	SBI PINB, PB1
    RET
;******************************************************************************
conHora:
	SBI PORTB, PB5
	CBI PINB, PB2
	CALL MOSTRAR_H
	CPI R22, 10  ; display Umin llega a 10
	BREQ MdecenU ;Salta
	CPI R19, 10  ;display u hor llega a 10
	BREQ MdecenaH;Salta
	CPI R17, 2  ;display Dhor llega  a 2
	BRSH H24x ;Salta
	CPI R22, 0 ;display Umin es menor a 0
	BRLT mDESmin  ;Salta 
	CPI R19, 0  ;display dHor es menor a 0
	BRLT mDEShora  ;Salta si es menor a 0 
	JMP LOOP
; decremento de unidad de horas afecta a la decena 
H24x:
	//CPI R22, 0  ;display 4 llega a -1
	//BRLT mDESmin  //Salta si es menor, con signo
	CPI R19, 4   ;y el  display dh tiene un 3
	BREQ REseteaHoras
	CPI R19, 0 //Si display 2 muestra un 0
	BRLT decremento; si r19 es menor a 0 salta
	JMP LOOP
; Para incremento de decenas de minutos
MdecenU:
	INC R21  ;Incrementar decena de minutos
	CPI R21, 6  ; verificar si no a llegaado a 6
	BRSH InDminv ; si es mayor o igual a a 6
	CLR R22
	JMP LOOP
; si el de decenas de min es igual o mayor a 6
InDminv:
	CPI R22, 10  ;Verificar si display unidad de minutos llegó a 9
	BREQ ResetMin
	JMP LOOP
;resetear minutos
ResetMin:
	CLR R21
	CLR R22
	JMP LOOP
; Para incremento de decenas de horas
MdecenaH:
	INC R17   ;incremento de decenas de horas
	CLR R19   ;resetear unidad de hora
	JMP LOOP
;decremento de d min
mDESmin:
	CPI R21, 5 
	BREQ desCmin
    CPI R21, 4
	BREQ desCmin
    CPI R21, 3
	BREQ desCmin
	CPI R21, 2
	BREQ desCmin
	CPI R21, 1
	BREQ desCmin
	LDI R21, 5
	LDI R22, 9
	JMP LOOP
;resetar horas
REseteaHoras:
	CLR R17
	CLR R19
	JMP LOOP
decremento:
	LDI R17, 1  ; colocar 19 en horas
	LDI R19, 9
	JMP LOOP
; si el display de unidad de horas es menor a cero
mDEShora:
	CPI R17, 1   ; y el de decena de hora es 1
	BREQ DEChOR; decrementar r17 y poner en 9 el de uHor
	LDI R17, 2
	LDI R19, 3
	JMP LOOP

DEChOR:
	LDI R17, 0  //Colocar el arreglo de display 1 a 09
	LDI R19, 9
	JMP LOOP

desCmin:
	DEC R21    //Decrementar valor de display 3
	LDI R22, 9  //Colocar display 4 en 9
	JMP LOOP

;***********************************************************************
Fecha:
	SBI PORTD, PD7
	CALL MOSTRAR_fecha
	JMP LOOP;

; ***********************************************************
; Rutinas para la gestión de los displays de fecha
; ***********************************************************
MOSTRAR_fecha: 
//display u dia
    CALL RETARDO  ; Retardo para la visualización
    ; Enciende el display de las unidades de dias
    SBI PINB, PB0
    ; Obtén el valor de las unidades de dias
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R24    ; R24 contiene las unidades de dias
    LPM R25, Z
    OUT PORTD, R25  ; Muestra el valor en el display
//display 2 d dia
	CALL RETARDO  ; Retardo para la visualización
	SBI PINB, PB0 ; Apaga los otros displays
    ; Enciende el display de las decenas de dias
    SBI PINB, PB1
    ; Obtén el valor de las decenas de dias
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R26   ; R26 contiene las decenas de dias
    LPM R25, Z
    OUT PORTD, R25  ; Muestra el valor en el display

// display3 u mes
	CALL RETARDO  ; Retardo para la visualización
	SBI PINB, PB1  ; Apagar otros displays
    ; Enciende el display de las unidades de mes
    SBI PINB, PB4
    ; valor de las unidades de mes
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R27    ; R27 contiene las unidades de mes
    LPM R25, Z
    OUT PORTD, R25  ; Mostrar el valor en el display
//display4 d mes
	CALL RETARDO  ; Retardo para la visualización
	SBI PINB, PB4  ; Apagar los otros displays
    ; Enciende el display de las decenas de mes
    SBI PINB, PB3
    ; valor de las decenas de mes
    LDI ZH, HIGH(TABLA << 1)
    LDI ZL, LOW(TABLA << 1)
    ADD ZL, R28    ; R28 contiene las decenas de mes
    LPM R25, Z
    OUT PORTD, R25  ; Muestra el valor en el display
	CALL RETARDO
	SBI PINB, PB3
    RET
;***********************************************************************
conFecha:
	//SBI PORTC, PC5
	CALL MOSTRAR_fecha
	MOV R31, R12
    CPI R31, 0// enero
	BREQ Dias31
	CPI R31, 1// febreo
	BREQ Dias28
	CPI R31, 2//Marzo
	BREQ Dias31
	CPI R31, 3//abril
	BREQ Dias30
	CPI R31, 4//Mayo
	BREQ Dias31
	CPI R31, 5//Junio
	BREQ Dias30
	CPI R31, 6//JUlio
	BREQ Dias31
	CPI R31,7//agosto
	BREQ Dias31
	CPI R31,8//septiembre
	BREQ  Dias30
	CPI R31,9//octubre
	BREQ Dias31
	CPI R31,10//noviembre
	BREQ Dias30
	CPI R31, 11//diciembre; */
	BREQ Dias31
	JMP LOOP
Dias31:
	LDI R29, 32
	JMP VerCaso
Dias28:
	LDI R29, 29
	JMP VerCaso
Dias30:
	LDI R29, 31
	JMP VerCaso
VerCaso:
	MOV R31, R13
	CPI R24, 10  ; display unidad de dia  = 9
	BREQ IdcDia
	CPI R24, -1  ; display unidad de dia  = 0
	BREQ Dc_dia
	CPI R27, 10   ; display unidad de  mes  = 9
	BREQ icDMES;******************************************************++++++++++++
	CP R13, R29 ; verificar la cantidad de dias no sobrepasen el limite
	BREQ RES_DIA	; saltar si son  iguales

	CPI R31, 0 ; verifica si el registro de dias esta en 0
	BREQ Ver_Cmes

	CPI R28, 1  ;si el displey de DEC de mes = 1
	BREQ ver_Me

	CPI R27, 0  ;display  muestra 1
	BREQ XXXNO

	JMP LOOP

icDMES:
	INC R28
	CLR R27
	JMP LOOP

ver_Me:
	CPI R27, 3  ; verificar si la unidad de mes es 2
	BREQ Res_Mes
	CPI R27, -1; si es 0
	BREQ Dec_mes
	JMP LOOP
; reiniciar meses
Res_Mes:
	CLR R28
	LDI R27, 1
	CLR R12
	JMP LOOP

XXXNO:
	LDI R28, 1
	LDI R27, 2
	LDI R31, 12
	MOV R12, R31   //Los meses deben de ser 12
	JMP LOOP

Dec_mes:
	LDI R28, 0
	LDI R27, 9
	JMP LOOP
; si la unidad de dia llega a 10
IdcDia:
	CLR R24 ; resetear unidad de dia
	INC R26   ; incrementar decena diA
	JMP LOOP
; si la unidad de dia llega a 0
Dc_dia:
	DEC R26
	LDI R24, 9
	JMP LOOP

RES_DIA:
	LDI R26, 0
	LDI R24, 1; AL RESETEAR DIA VUELVE A 1
	MOV R13, R24
	JMP LOOP
; verificar la cantidad del mes, esto depende del mes
Ver_Cmes:
	CPI R29, 32
	BREQ M31
	CPI R29, 31
	BREQ M30
	CPI R29, 29
	BREQ M28
	JMP LOOP
M31:
	LDI R26, 3
	LDI R24, 1
	LDI R29, 31
	MOV R13, R29
	JMP LOOP
M30:
	LDI R26, 3
	LDI R24, 0
	LDI R29, 30
	MOV R13, R29
	;JMP LOOP
M28:
	LDI R26, 2
	LDI R24, 8
	LDI R29, 28
	MOV R13, R29
	JMP LOOP

//*****************************************************************************
//PULSADORES
//*****************************************************************************
ISR_PCINT1:
	PUSH R16         //Se guarda en pila el registro R16
	IN R16, SREG
	PUSH R16

	SBRC Estado, 0
	JMP ISR_Hora
	SBRC  Estado, 1
	JMP ISR_conHora
	SBRC Estado,2
	JMP ISR_Fecha
	SBRC Estado, 3
	JMP ISR_conFecha
	SBRC  Estado, 4
	LDI Estado,1
	jmp But_goOut
;PRIMER ESTADO
ISR_Hora:
	SBIC PINC, PINC0
	JMP INCREMENT
	JMP But_goOut
; SEGUNDO ESTADO
INCREMENT:
	ROL Estado
	SBRC Estado, 6
	LDI Estado,1
	JMP But_goOut
	
ISR_conHora:
	SBIC PINC, PINC0
	JMP INCREMENT
	SBIC PINC, PINC1
    RJMP INC_MIN
    SBIC PINC, PINC2
    RJMP INC_HOR
    SBIC PINC, PINC3
    RJMP DEC_MIN
    SBIC PINC, PINC4
    RJMP DEC_HOR
	JMP But_goOut
INC_MIN:
	INC R22 ; ; Incrementa los minutos
	JMP But_goOut
INC_HOR:
	INC R19 ; Incrementa los horas
	JMP But_goOut
DEC_MIN:
	DEC R22 ; decrementa los minutos
	JMP But_goOut
DEC_HOR:
	DEC R19 ; decrementa horass
	JMP But_goOut
; TERCER ESTADO
ISR_Fecha:
	SBIC PINC, PINC0
	JMP INCREMENT
	JMP But_goOut ; solo muestra fecha 
; CUARTO ESTADO
ISR_conFecha:
	SBIC PINC, PINC0
	JMP INCREMENT
	SBIC PINC, PINC1
    RJMP INC_DIA
    SBIC PINC, PINC2
    RJMP INC_MES
    SBIC PINC, PINC3
    RJMP DEC_DIA
    SBIC PINC, PINC4
    RJMP DEC_MESX
	JMP But_goOut
INC_DIA: ; Incrementa dia
	INC R24
	INC R13
	JMP But_goOut
INC_MES:
	INC R27 ; Incrementa mes
	INC R12
	JMP But_goOut
DEC_DIA:
	DEC R24	; decrementa dia
	DEC R13
	JMP But_goOut
DEC_MESX:
	DEC R27	; decrmenta mes
	DEC R12
	JMP But_goOut	

But_goOut: ; Salir de interrupción
	SBI PCIFR, PCIF0 ; APAGAR BANDERA
	POP R16; OBTENER VALOR DE SREG
	OUT SREG, R16;OBTENER VALOR DE R16
	POP R16
	RETI

; *****************************************************************************
; Manejador de la interrupción del Timer0 Overflow
; *****************************************************************************
ISR_TIMER0_OVF:
    PUSH R16 ; Guardar R16 en la pila
    IN R16, SREG ; Guardar el estado de los flags de interrupción en R16
    PUSH R16 ; Guardar R16 en la pila

    LDI R16, 11 ; Configurar el Timer0 para un nuevo ciclo
    OUT TCNT0, R16
	INC R18 ; Incrementar la variable de control del parpadeo del LED
    SBI TIFR0, TOV0 ; Limpiar la bandera de overflow del Timer0

    
	
PAR:
	
	CPI R18, 2
	BREQ ONpar
	CPI R18, 4
	BREQ OFFpar
	JMP SALIR0
ONpar:
    SBI PORTB, PB2 ; Encender el LED en PB2
    JMP SALIR0

OFFpar:
    CBI PORTB, PB2 ; Apagar el LED en PB2
    CLR R18
	JMP SALIR0
SALIR0:
    POP R16 ; Recuperar R16 desde la pila
    OUT SREG, R16 ; Restaurar los flags de interrupción
    POP R16 ; Recuperar R16 desde la pila

    RETI ; Retornar de la interrupción

; *****************************************************************************
; Manejador de la interrupción del Timer1 Overflow
; *****************************************************************************
ISR_TIMER1_OVF:
  ; Guardar registros en la pila
    PUSH R16
    IN R16, SREG
    PUSH R16

    ; Restablecer el contador Timer1
    LDI R16, 0xF0;F0 ;fc
    STS TCNT1H, R16   ; Valor inicial del contador alto
    LDI R16, 0xBD;BD ;2F
    STS TCNT1L, R16   ; Valor inicial del contador bajo
	INC R23
    ; Limpiar la bandera de desbordamiento del Timer1
    SBI TIFR1, TOV1
    ; Restaurar registros desde la pila
    POP R16
    OUT SREG, R16
    POP R16
	
    RETI

