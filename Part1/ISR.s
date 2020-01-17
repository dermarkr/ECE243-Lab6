

                .section .vectors, "ax"  
                B        _start              // reset vector
                B        SERVICE_UND         // undefined instruction vector
                B        SERVICE_SVC         // software interrupt vector
                B        SERVICE_ABT_INST    // aborted prefetch vector
                B        SERVICE_ABT_DATA    // aborted data vector
                .word    0                   // unused vector
                B        SERVICE_IRQ         // IRQ interrupt vector
                B        SERVICE_FIQ         // FIQ interrupt vector
				
.include		"address_map_arm.s"
.include		"defines.s"
.include		"exceptions.s"
.include		"interrupt_ID.s"

                .text    
                .global  _start 

_start:                                  
/* Set up stack pointers for IRQ and SVC processor modes */             
				LDR 	R1, = 0b11010010
				MSR		CPSR_c, R1
				LDR		SP, = 0xFFFFFFFC
				
				LDR		R1, = 0b11010011
				MSR		CPSR_c, R1
				LDR		SP, = 0x3FFFFFFC
				
                BL       CONFIG_GIC      // configure the ARM generic
                                         // interrupt controller
/* Configure the KEY pushbuttons port to generate interrupts */
                LDR		R0, =0xFF200050
				MOV		R1, #15
				STR		R1, [R0, #8]

/* Enable IRQ interrupts in the ARM processor */
                LDR		R0, =0b01010011
				MSR		CPSR_c, R0
IDLE:                                    
                B        IDLE            // main program simply idles

/* Define the exception service routines */

SERVICE_IRQ:    PUSH    {R0-R7, LR}     
                LDR     R4, =0xFFFEC100 // GIC CPU interface base address
                LDR     R5, [R4, #0x0C] // read the ICCIAR in the CPU
                                         // interface

KEYS_HANDLER:                       
                CMP      R5, #73         // check the interrupt ID

UNEXPECTED:     BNE      UNEXPECTED      // if not recognized, stop here
                BL       KEY_ISR         

EXIT_IRQ:       STR      R5, [R4, #0x10] // write to the End of Interrupt
                                         // Register (ICCEOIR)
                POP      {R0-R7, LR}     
                SUBS     PC, LR, #4      // return from exception
				
KEY_ISR:		LDR		R5, =0xFF200050
				LDRB	R0, [R5, #12]
				BL		DISPLAY
				B		EXIT_IRQ

				
DISPLAY:    	LDR     R3, =0xFF200020 // base address of HEX3-HEX0
				MOV     R1, R0          // display R5 on HEX1-0

				MOV		R6, PC
				B       SEG7_CODE       
				MOV		R2, #4
				MUL		R4, R0, R2
				SUB		R4, #4
				LSL     R1, R4     
				
				STR     R4, [R3]        // display the number from R7
				MOV		PC, LR

			
SEG7_CODE: 	 MOV     R2, #BIT_CODES  
				ADD     R2, R1         // index into the BIT_CODES "array"
				LDRB    R1, [R2]       // load the bit pattern (to be returned)
				ADD		R6, #4
				MOV     PC, R6 
							
BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
			.byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
			.byte	0b00000000
			.skip   2      // pad with 2 bytes to maintain word alignment

.end