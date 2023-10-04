org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


;
; FAT12 header
; 
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'NANOBYTE OS'        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

;
; Code goes here
;

start:
    jmp main


;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; save registers we will modify
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; verify if next character is null?
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret
    

main:
    ; setup data segments
    mov ax, 0                   ; can't set ds/es directly
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00              ; stack grows downwards from where we are loaded in memory

    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    mov ax, 1                   ; LBA=1, second sector from disk
    mov cl, 1                   ; 1 sector to read
    mov bx, 0x7E00              ; data should be after the bootloader
    call disk_read

    ; print hello world message
    mov si, msg_hello
    call puts

    cli                         ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Error handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for keypress
    jmp 0FFFFh:0                ; jump to beginning of BIOS, should reboot

.halt:
    cli                         ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret


;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_hello:              db 'Hello world!', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h


; org 0x7C00
; bits 16

; ; defines a newline in assembly
; %define ENDL 0X0D, 0X0A

; ;
; ; FAT12 header
; ;
; jmp short start
; nop

; bdb_oem:                        db 'MSWIN4.1'   ; 8 bytes
; bdb_bytes_per_sector:           dw 512
; bdb_sectors_per_sector:         db 1
; bdb_reserved_sectors:           dw 1 
; bdb_fat_count:                  db 2
; bdb_dir_entries_count:          dw 0E0h
; bdb_total_sectors:              dw 2880
; bdb_media_descriptor_type:      db 0F0h
; bdb_sectors_per_fat:            dw 9
; bdb_sectors_per_track:          dw 18
; bdb_heads:                      dw 2
; bdb_hidden_sectors:             dd 0
; dbd_large_sector_count:         dd 0

; ; extended boot record
; ebr_drive_number:               db 0
;                                 db 0
; ebr_signature:                  db 29h
; ebr_volume_id:                  db 12h, 34h, 56h, 78h
; ebr_volume_label:               db 'NANOBYTE OS'
; ebr_system_id:                  db 'FAT12    '

; ;
; ; Code goes here
; ;



; ; program entry point, jumps to main
; start:
;     jmp main


; ; Prints a string to the screen
; ; Params : 
; ;    - ds:si points to string
; ;
; puts:
;     ; save registers we will modify on the stack
;     push si
;     push ax

; .loop:
;     lodsb                   ; loads next character in al, from ds:si
;     or al, al               ; verify if next character is null?
;     jz .done                ; if result of previous op is 0 program jumps

;     ; calls bios interrupt
;     mov ah, 0x0e            ; parameter used for BIOS video interrupt
;     int 0x10                ; triggers an interrupt to invoke BIOS video services, 
;                             ; with specified parameters, will display character in al register

;     jmp .loop               ; continue processing next character

; ; marks end of subroutine
; ; restores original ax, and si registers from stack and returns from subroutine
; .done:
;     pop ax
;     pop si
;     ret


; main:

;     ; setup data segments to 0
;     mov ax, 0               ; cant write to ds/es directly 
;     mov ds, ax
;     mov es, ax

;     ; setup stack           ; stack grows downwards from where we are loaded in mem
;     ; sets ss (stack segment) to 0
;     ; sets sp (stack ptr) to 0x7C00 (configs stack to start at mem location 0x7CO0)
;     mov ss, ax
;     mov sp, 0x7C00

;     ; read something from floppy disk
;     ; BIOS should set DL to drive number
;     mov [ebr_drive_number], dl

;     mov ax, 1                           ; LBA = 1, second sector from disk
;     call cl, 1                          ; 1 sector to read
;     mov bx, 0x7E00                      ; data should be after the bootloader
;     call disk_read

;     ; print message
;     ; load address of msg_hello into si register
;     mov si, msg_hello
;     call puts

;     cli                             ; disable interrupts, this way the CPU can't get out of the halt state
;     ; stops CPU from executing further instructions, halts program
;     hlt


; ;
; ; Error handlers
; ;
; floppy_error:
;     mov si, msg_read_failed
;     call puts
;     jmp wait_key_and_reboot

; wait_key_and_reboot:
;     mov ah, 0
;     int 16h                         ; wait for keypress
;     jmp 0FFFFh:0                    ; jump to beginning of BIOS
    

; .halt:
;     cli                             ; disable interrupts, this way the CPU can't get out of the halt state
;     hlt                             


; ;
; ; Disk routines
; ;

; ;
; ; Converts and LBA address to a CHS address
; ; Parameters:
; ;   - ax: LBA address
; ; Returns:
; ;   - cx [bits 0-5]: sector number
; ;   - cx [bits 6-15]: cylinder
; ;   - dh: header
; lba_to_chs:
;     push ax
;     push dx

;     xor dx, dx                          ; dx = 0
;     div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
;                                         ; dx = LBA % SectorsPerTrack
    
;     inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
;     mov cx, dx                          ; cx = sector

;     xor dx, dx                          ; dx = 0
;     div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack ) / Heads = cylinder
;                                         ; dx = (LBA / SectorsPerTrack ) % Heads = head
;     mov dh, dl                          ; dh = head
;     mov ch, al                          ; ch = cylinder (lower 8 bits)
;     shl ah, 6
;     or cl, ah                           ; hput upper bits of cylinder in cl

;     pop ax
;     mov dl, al                          ; restore DL
;     pop ax
;     ret


; ;
; ; Reads sectors from a Disk
; ; Parameters:
; ; - ax =  LBA address
; ; - cl: number of sectors to read (up to 128)
; ; - dl: drive number 
; ; - es:bx: memory address where to store read data
; ;
; disk_read:
;     push ax                                 ; save registers we will modify
;     push bx
;     push cx
;     push dx
;     push di





;     push cx                               ; save CL (number of sectors to read)
;     call lba_to_chs                       ; compute CHS
;     pop ax                                ; AL = number of sectors to be read

;     mov ah, 02h
;     mov di, 3                             ; retry count

; .retry:
;     pusha                                 ; save all registers, we dont know what bIOS modifies
;     stc                                 ; set carry flag, some BIOSes dont set it                                
;     int 13h                             ; carry flag cleared = success
;     jnc .done                           ; jump if carry not set

;     ; read failed
;     popa
;     call disk_reset

;     dec di
;     test di, di
;     jnz .retry

; .fail:
;     ; all attempts are exhausted
;     jmp floppy_error

; .done: 
;     popa

;     pop di
;     pop dx
;     pop cx
;     pop bx
;     pop ax                             ; restore modified registers
;     ret


; ;
; ; Resets the disk controller
; ; Parameters:
; ;   dl: drive number
; ;
; disk_reset:
;     pusha
;     mov ah, 0
;     stc
;     int 13h
;     jc floppy_error
;     popa
;     ret





    




; ; defines a string
; msg_hello:              db 'Hello world!', ENDL, 0
; msg_read_failed:        db 'Read from disk failed!', ENDL, 0

; ; ensures bootloader takes up 512 bytes which is required
; times 510-($-$$) db 0

; ; BIOS checks for this value to determine if the media is bootable
; ; if present BIOS loads and executes bootloader code
; dw 0AA55h