org 0x7C00
bits 16

; defines a newline in assembly
%define ENDL 0X0D, 0X0A

; program entry point, jumps to main
start:
    jmp main


; Prints a string to the screen
; Params : 
;    - ds:si points to string
;
puts:
    ; save registers we will modify on the stack
    push si
    push ax

.loop:
    lodsb                   ; loads next character in al, from ds:si
    or al, al               ; verify if next character is null?
    jz .done                ; if result of previous op is 0 program jumps

    ; calls bios interrupt
    mov ah, 0x0e            ; parameter used for BIOS video interrupt
    int 0x10                ; triggers an interrupt to invoke BIOS video services, 
                            ; with specified parameters, will display character in al register

    jmp .loop               ; continue processing next character

; marks end of subroutine
; restores original ax, and si registers from stack and returns from subroutine
.done:
    pop ax
    pop si
    ret


main:

    ; setup data segments to 0
    mov ax, 0               ; cant write to ds/es directly 
    mov ds, ax
    mov es, ax

    ; setup stack           ; stack grows downwards from where we are loaded in mem
    ; sets ss (stack segment) to 0
    ; sets sp (stack ptr) to 0x7C00 (configs stack to start at mem location 0x7CO0)
    mov ss, ax
    mov sp, 0x7C00

    ; print message
    ; load address of msg_hello into si register
    mov si, msg_hello
    call puts

    ; stops CPU from executing further instructions, halts program
    hlt

; .halt:
;     jmp .halt

; defines a string
msg_hello: db 'Hello world!', ENDL, 0

; ensures bootloader takes up 512 bytes which is required
times 510-($-$$) db 0

; BIOS checks for this value to determine if the media is bootable
; if present BIOS loads and executes bootloader code
dw 0AA55h