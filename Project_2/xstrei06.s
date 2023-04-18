; Autor reseni: Jaroslav Streit xstrei06
;r5-r12-r13-r15-r0-r4

; Projekt 2 - INP 2022
; Vernamova sifra na architekture MIPS64

; DATA SEGMENT
                .data
login:          .asciiz "xstrei06"  ; sem doplnte vas login
debug1:         .asciiz "debug1"
debug2:         .asciiz "debug2"
cipher:         .space  17  ; misto pro zapis sifrovaneho loginu
key_1:          .word   115 ;19
key_2:          .word   116 ;20
add_key:        .byte   19
over/underflow: .byte   26
sub_key:        .byte   20
ascii_a:        .byte   96

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize "funkce" print_string)

; CODE SEGMENT
                .text

                ; ZDE NAHRADTE KOD VASIM RESENIM
main:
                daddi r5, r0, cipher
                daddi r12, r0, login
                dadd r4, r0, r5
                daddi r13, r0, ascii_a
                
    only_letters:       
                lbu r15, 0(r12)
                lbu r13, 0(r13)

                dsubu r13, r13, r15
                bgez r13, numbers_gone
                  
                sb r15, 0(r5)
                addi r12, r12, 1
                addi r5, r5, 1

                daddi r13, r0, ascii_a
                j only_letters
                
    numbers_gone:  
                sb r0, 0(r5)
                dadd r13, r0, r0
                dadd r5, r0, r4
                daddi r4, r0, cipher

    loop:          
                lbu r15, 0(r5)
                beq r15, r0, end
                bne r13, r0, backward
                j forward
                
    end:
                jal     print_string    ; vypis pomoci print_string - viz nize


                syscall 0   ; halt

    forward:
                daddi r12, r0, add_key
                lbu r12, 0(r12)
                daddu r15, r15, r12
                slti r12, r15, 0x7a
                bne r12, r0, next1

                daddi r12, r0, over/underflow
                lb r12, 0(r12) 
                dsub r15, r15, r12

    next1:
                sb r15, 0(r5)
                sltiu r13, r13, 1
                addi r5, r5, 1
                j loop
    backward:       
                daddi r12, r0, sub_key
                lbu r12, 0(r12)
                dsub r15, r15, r12
                slti r12, r15, 0x61
                beq r12, r0, next2

                daddi r12, r0, over/underflow
                lb r12, 0(r12)
                dadd r15, r15, r12

    next2:      
                sb r15, 0(r5)
                sltiu r13, r13, 1
                addi r5, r5, 1
                j loop

print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address

