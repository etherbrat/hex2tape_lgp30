; helloword.asm
; prints strings using a print_string subroutine
;				
; A string comprises a series of 6-bit character codes, up to 5 per word.
; The string is terminated by a stop code (') which is not printed.
; The creator of the string must not make any assumption about case (upper or lower) at the commencement of printing.
; The creator of the string must include case shifts as required to produce the required characters.
; To assemble a string:
; string: .word shl(<code0>,2) + shl(<code1>,8) + shl(<code2>,14) + shl(<code3>,20) + shl(<code4>,26)
; .word shl(<code5>,2) + shl(<code6>,8) + shl(<code7>,14) + etc.
; The first code in each word must reside in the sector field, others must be left shifted in multiples of 6 bits.
;
; Some help from the cross assembler would be good,
; e.g. .string <string_using_escape_codes_where required>,
; but not available at this time.
;
; Calling Convention:
; Put b <address_of_string> in the accumulator (outer argument)
; Plant the return address at the end of the print_string function
; Jump to print_string
;
; Print String Procedure:
; Do until a stop code is found:
;   Print each character in the word
;   Index to the next word
; Return to caller
;
; Notes:
; 1. The current word address, the loop counter, and the incrementer/decrementer are integers at q=29
; 2. The equates hereunder provide the character codes.
			
    .locn   0                       ; load address
main:
	b	arg1		                ; bring the outer argument to A/ac
	r	print_string_end		    ; plant the return address
	u	print_string		        ; jump to subroutine
	b	arg2		                ; returns here - bring the outer argument to A/ac
	r	print_string_end		    ; plant the return address
	u	print_string		        ; jump to subroutine
	z	0		                    ; returns here - end of main program
arg1:
	b	my_1st_string		        ; outer argument - brings first word of string
my_1st_string:                      ; Hello World<caret><'>                                
	.word	shl(ucase,2)+shl(h,8)+shl(lcase,14)+shl(e,20)+shl(l,26)
	.word	shl(l,2)+shl(o,8)+shl(space,14)+shl(ucase,20)+shl(w,26)
	.word	shl(lcase,2)+shl(o,8)+shl(r,14)+shl(l,20)+shl(d,26)
	.word	shl(caret,2)+shl(stop,8)
arg2:
	b	my_2nd_string		        ; outer argument - brings first word of string
my_2nd_string:                      ; Good night and good luck<caret><'>
	.word	shl(ucase,2)+shl(g,8)+shl(lcase,14)+shl(o,20)+shl(o,26)
	.word	shl(d,2)+shl(space,8)+shl(n,14)+shl(i,20)+shl(g,26)
	.word	shl(h,2)+shl(t,8)+shl(space,14)+shl(a,20)+shl(n,26)
	.word	shl(d,2)+shl(space,8)+shl(g,14)+shl(o,20)+shl(o,26)
	.word	shl(d,2)+shl(space,8)+shl(l,14)+shl(u,20)+shl(c,26)
	.word	shl(k,2)+shl(caret,8)+shl(stop,14)
                                    ;
print_string:
	h 	outer_arg		            ; save the outer argument for later execution
                                    ;
inner_loop:
	b	counter_init		        ; start_inner_loop - bring the inner loop counter initial value
	h 	counter		                ; initialise the inner loop counter
outer_arg:
	.word	0		                ; holds a b instr for execution - brings a word for serialisation to the printer
	h	inner_arg		            ; save the inner argument

continue_inner_loop:
	e	code_mask		            ; mask in the code bits (in sector field)
	h   code			            ; save the code
	s	stop_code		            ; subtract stop code (in sector field)
	t	not_stop_code		        ; skip on negative to not_stop_code
	b	stop_code		            ; bring stop code (in sector field)
	s	code		                ; subtract code
	t	not_stop_code		        ; skip on negative to not_stop_code
	u	print_string_end		    ; skip to end_of_procedure (not higher, not lower, then equal)
not_stop_code:				        ; not_stop_code
	b	code		                ; retireve the code
	n	left_shift_6		        ; shift code into the track field (left, 6 bits)
	a	p_instr		                ; add a p instruction (p instruction acquires code)
	h	pinstr_exec		            ; save the p instruction for immediate execution
pinstr_exec:
	.word	0		                ; holds a p instr for execution - prints the current code
	b	inner_arg		            ; retrieve the inner argument
	m	right_shift_6		        ; shift the next character into the sector field (right, six bits)
	h	inner_arg		            ; save the inner argument
	b	counter		                ; retrieve the inner loop counter
	s	incdec		                ; subtract indexer
	t	continue_outer_loop		    ; skip on negative to continue_outer_loop
	h	counter		                ; save the inner loop counter
    b   inner_arg                   ; retrieve the inner_argument
	u	continue_inner_loop		    ; jump to inner_loop
                                    ;
continue_outer_loop:
	b	incdec                      ; continue_outer_loop - retrieve the indexer
	a	outer_arg		            ; add the outer argument (indexes the address of the word to be serialised to the printer)
	h	outer_arg		            ; save the outer argument for later execution
	u	inner_loop		            ; repeat the inner loop

print_string_end:
	u	0		                    ; end_of_procedure - patched for return to caller
                                    ;
counter:	    .word	0		    ; the inner loop counter here
inner_arg:	    .word	0		    ; inner argument here - the word to be serialised to the printer (as shifted)
code:	        .word	0           ; the code for printing here (as extracted from inner argument)
counter_init:	.atq	4 29		; CONST inner loop counter initial value here
code_mask:	    .word	0x000000fc  ; CONST 6-bit mask for sector field
stop_code:	    .word	shl(stop,2)	; CONST stop code (in sector field)
left_shift_6:	.lshn	6		    ; CONST n multiplier for 6 -bit left shift
p_instr:	    p	0		        ; CONST p instruction (with track field to be filled)
right_shift_6:	.rshm	6		    ; CONST m multiplier for 6-bit right shift
incdec:     	.atq	1 29		; CONST incrementer/decrementer here
                                    ;
                                    ; CONST character codes
	.equ	z	1	
	.equ	rbrac	2	
	.equ	n0	2	
	.equ	space	3	
	.equ	lcase	4	
	.equ	b	5	
	.equ	l	6	
	.equ	n1	6	
	.equ	uscor	7	
	.equ	minus	7	
	.equ	ucase	8	
	.equ	y	9	
	.equ	mul	10	
	.equ	n2	10	
	.equ	eql	11	
	.equ	plus	11	
	.equ	colour	12	
	.equ	r	13	
	.equ	quot	14	
	.equ	n3	14	
	.equ	coln	15	
	.equ	scoln	15	
	.equ	caret	16	
	.equ	i	17	
	.equ	delta	18	
	.equ	n4	18	
	.equ	ques	19	
	.equ	div	19	
	.equ	bs	20	
	.equ	d	21	
	.equ	pct	22	
	.equ	n5	22	
	.equ	rsb	23	
	.equ	fstop	23	
	.equ	tab	24	
	.equ	n	25	
	.equ	dol	26	
	.equ	n6	26	
	.equ	lsb	27	
	.equ	comma	27	
	.equ	m	29	
	.equ	pi	30	
	.equ	n7	30	
	.equ	v	31	
	.equ	stop	32	
	.equ	p	33	
	.equ	sigma	34	
	.equ	n8	34	
	.equ	o	35	
	.equ	e	37	
	.equ	lbrac	38	
	.equ	n9	38	
	.equ	x	39	
	.equ	u	41	
	.equ	f	42	
	.equ	t	45	
	.equ	g	46	
	.equ	h	49	
	.equ	j	50	
	.equ	c	53	
	.equ	k	54	
	.equ	a	57	
	.equ	q	58	
	.equ	s	61	
	.equ	w	62	
                                    ;
	.end	main		
