.global _start

_start:

    ldr x0, =0x09000000  
    
    adr x1, message     

print_loop:
    ldrb w2, [x1], #1    
    cbz w2, halt         
    strb w2, [x0]
    b print_loop

halt:
    wfi                  
    b halt

message:
    .asciz "\n\n****************************************\n* SECURE BOOT BYPASSED !               *\n* PWNED BY JUSTTHINKING BOOTKIT !      *\n****************************************\n\n"
