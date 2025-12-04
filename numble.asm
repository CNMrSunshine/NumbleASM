global  _start
extern printf, rand, srand

section .data
    ; =======================================
    ; 长文字信息
    MSG1 db 0x1b, "[36mWelcome to WODL. Enjoy!", 0x0a
    LenMSG1 equ $-MSG1
    MSG2 db 0x0a, 0x1b, "[36mThe selected word contains ", 0x1b, "[32m%d letters",0x0a, 0x1b, "[36mInput your first attempt then press ENTER to summit!", 0x0a, 0x00
    MSG4 db 0x0a, 0x1b, "[37m [%d] -", 0x00
    MSG5 db 0x1b, "[35m Wrong length!",0x0a, 0x00
    WinMSG db 0x0a, 0x0a, 0x1b, "[36mCongrats! You WON after %d attempts!", 0x0a, 0x00
    KeyBoardLayout db "1234567890"
    ; =======================================
    ; 短文字信息
    ShowAttempt db 0x1b, "[37m[%d] -", 0x00
    FlushPreANSI db 0x1b, "[1A", 0x1b, "[2K" ; 控制台移动光标到上一行行首 并清空行
    LenFlushPreANSI equ $-FlushPreANSI
    FlushCurANSI db 0x1b, "[2K", 0x1b, "[1G" ; 控制台清除当前行并移动光标到行首
    LenFlushCurANSI equ $-FlushCurANSI
    LetterRed db " ", 0x1b, "[31m[%c]", 0x00
    LetterYellow db " ", 0x1b, "[33m[%c]", 0x00
    LetterGreen db " ", 0x1b, "[32m[%c]", 0x00
    LetterGrey db " ", 0x1b, "[90m[%c]", 0x00
    Return db 0x0a, 0x00 ; \n
    Header db 0x1b, "[37mWODL> "
    lenHeader equ $-Header
    LeftSym db "["
    RightSym db "] "
    KBReturn1 db 0x0a, "  ", 0x00
    KBReturn2 db 0x0a, "    ", 0x00
    ; =======================================
    ; 硬编码参数
    WordLen db 0x05
    wdlistPath db "wordlist", 0x00
    fopenMode db "r", 0x00
    RandNum times 8 db 0x00
    inFormat db "%s", 0x00
    ; =======================================
    ; 有初始值的变量
    input times 0x20 db 0x20
    ; =======================================


section .bss
    ; =======================================
    SelectedNum resb 0x5
    Attempts resb 0x8 ; 存放用户尝试次数
    TermiosData resb 64 ; 终端ioctl数据
    KnownNumbers resb 0xa ; 记录已确认的字母
    ; =======================================

section .text
_start:
    call RawMode ; 将终端设置为raw输入模式
    mov rsi, MSG1
    mov rdx, LenMSG1
    call print ; 打印欢迎语
InitRand:
    rdtsc
    mov rdi, rax
    call srand ; 用CPU时钟做伪随机种子
    xor rcx, rcx ; 计数器
CreateDigit: ; 逐位随机
    push rcx ; 保存计数器
    sub rsp, 8 ; 对齐栈
    call rand ; 生成伪随机数
    xor rdx, rdx
    mov rbx, 9
    div rbx ; 取模9
    add rsp, 8
    pop rcx ; 恢复计数器
    add dl, 0x30 ; Hex -> ASCII数字
    xor rbx, rbx ; 子循环计数器
CheckDigit: ; 检查该位数字是否与之前的重复
    test rcx, rcx
    jz SaveDigit ; 跳过检查第一位
    cmp byte [SelectedNum+rbx], dl ; 逐位检查
    je CreateDigit ; 重新生成重复的数字
    inc rbx
    cmp rbx, rcx
    jne CheckDigit
SaveDigit: ; 保存当前位数字
    mov byte [SelectedNum+rcx], dl
    inc rcx
    cmp rcx, 5
    jne CreateDigit
GuessStart:
    mov rdi, Return
    call printf
    mov rdi, Return
    call printf ; 换行顺便fflush
    xor rcx, rcx ; 计数器
ClearBuffer:
    mov [input+rcx], 0x20
    inc rcx
    cmp rcx, 0x20
    jne ClearBuffer
    xor rcx, rcx ; 用户输入字符数计数器
ReadInput:
    push rcx ; 保存计数器
    sub rsp, 8
    call PrintKeyBoard ; 打印键盘
    mov rdi, Return
    call printf
    call PrintInput ; 打印输入框
    add rsp, 8
    pop rcx
    mov rax, 0 ; read
    mov rdi, 0 ; stdin
    lea rsi, [input+rcx] ; 输入缓冲区 input[rcx]
    mov rdx, 1 ; 输入长度
    push rcx ; 保存计数器
    sub rsp, 8 ; 对齐栈
    syscall ; 读取用户输入
CheckInput:
    add rsp, 8
    pop rcx
    mov byte al, [input+rcx] ; al: 输入字符
    cmp al, 0x7f ; del键
    je DeleteLetter ; 删除前一个输入
    cmp al, 0x08 ; 删除键
    je DeleteLetter
    cmp al, 0x30
    jl ClearInput ; 非数字 回退输入
    cmp al, 0x3a
    jg ClearInput
    push rcx
    sub rsp, 8
    jmp ProcessLetters ; 处理输入

DeleteLetter:
    mov al, 0x20
    test rcx, rcx
    jz DelCurrentDigit ; 若为第一位 则只清除当前输入
    mov byte [input+rcx], al ; 清除当前输入
    dec rcx
DelCurrentDigit:
    mov byte [input+rcx], al ; 清除前一输入
    jmp ContinueRead ; 继续监听输入

ClearInput:
    mov al, 0x20
    mov byte [input+rcx], al ; 回退缓冲区
    dec rcx ; 回退计数器
    jmp ContinueRead ; 继续监听输入

ProcessLetters:
    add rsp, 8
    pop rcx ; 恢复输入计数器
    inc rcx
    cmp byte cl, [WordLen]
    jne ContinueRead
PrintAttempt:
    call FlushCurrentLine ; 清除键盘和输入框
    call FlushPreLine
    call FlushPreLine
    inc [Attempts]
    mov rdi, ShowAttempt
    mov rsi, [Attempts]
    call printf
    xor rcx, rcx ; 循环计数器
    xor rsi, rsi ; 正确字母计数器
CheckLetters:
    cmp byte sil, [WordLen]
    je win
    cmp byte cl, [WordLen]
    je GuessStart
    mov byte al, [input+rcx]
    mov byte bl, [SelectedNum+rcx] ; 首先检查当前字母位是否匹配
    cmp al, bl
    je LetterCorrect
    xor rdx, rdx ; 子循环计数器
CheckEachLetter:
    mov byte bl, [SelectedNum+rdx] ; 再检查该字母是否存在于单词
    cmp al, bl
    je LetterContain
    inc rdx
    cmp byte dl, [WordLen]
    jne CheckEachLetter
    jmp LetterNotContain

win:
    mov rdi, WinMSG
    mov rsi, [Attempts]
    call printf
exit:
    mov rax, 60
    mov rdi, 0
    syscall


; ===========================================
; 杂项
print:
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    syscall
    ret

FlushCurrentLine: ; 清空当前终端行
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    mov rsi, FlushCurANSI
    mov rdx, LenFlushCurANSI
    syscall
    ret

FlushPreLine: ; 清空终端上一行
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    mov rsi, FlushPreANSI
    mov rdx, LenFlushPreANSI
    syscall
    ret

RawMode: ; 将终端设置为raw输入模式
    mov rax, 16 ; ioctl
    mov rdi, 0 ; stdin
    mov rsi, 0x5401 ; ioctl指令: tcgets
    mov rdx, TermiosData
    syscall ; 获取当前终端配置
    mov eax, dword [TermiosData + 12]  ; lflag偏移
    and eax, ~(0x00000008 | 0x00000002) ; ECHO | ICAMON
    mov dword [TermiosData + 12], eax
    mov byte [TermiosData + 20 + 6], 1 ; vmin = 6
    mov byte [TermiosData + 20 + 5], 0 ; vtime = 5
    mov rax, 16
    mov rdi, 0
    mov rsi, 0x5402 ; ioctl指令: tcsets
    mov rdx, TermiosData
    syscall ; 写入新的终端配置
    ret

PrintInput: ; 打印输入框
    mov rsi, Header
    mov rdx, lenHeader
    call print ; 打印"NUMBL> "
    xor rbx, rbx
PrintLetters: ; 打印用户输入字母
    push rbx ; 保存打印计数器
    sub rsp, 8 ; 对齐栈
    mov rsi, LeftSym
    mov rdx, 1
    call print ; 打印"["
    lea rsi, [input+rbx]
    mov rdx, 1
    call print ; 打印用户输入数字
    mov rsi, RightSym
    mov rdx, 2
    call print ; 打印"] "
    add rsp, 8
    pop rbx ; 恢复打印计数器
    inc rbx
    cmp byte bl, [WordLen]
    jne PrintLetters
    ret

ContinueRead:
    push rcx ; 保存计数器
    sub rsp, 8
    call FlushCurrentLine
    call FlushPreLine
    add rsp, 8
    pop rcx
    jmp ReadInput

; ====

PrintKeyBoard:
    xor rcx, rcx ; 计数器
PrintKeyBoardLoop:
    xor rsi, rsi
    mov byte sil, [KeyBoardLayout+rcx]
    cmp sil, 0x01
    je PrintKBReturn1
    cmp sil, 0x02
    je PrintKBReturn2
    sub sil, 0x30 ; ASCII -> Hex位次
    mov byte bl, [KnownNumbers+rsi]
    add sil, 0x30 ; 恢复ASCII
    push rcx ; 保存计数器 顺便对齐栈
    cmp bl, 0x1
    je PrintKBGreen
    cmp bl, 0x2
    je PrintKBYellow
    cmp bl, 0x3
    je PrintKBRed

PrintKBGrey:
    mov rdi, LetterGrey
    call printf
    jmp PrintKBEnd
PrintKBGreen:
    mov rdi, LetterGreen
    call printf
    jmp PrintKBEnd
PrintKBYellow:
    mov rdi, LetterYellow
    call printf
    jmp PrintKBEnd
PrintKBRed:
    mov rdi, LetterRed
    call printf
    jmp PrintKBEnd
PrintKBReturn1:
    push rcx ; 保存计数器
    mov rdi, KBReturn1
    call printf
    jmp PrintKBEnd
PrintKBReturn2:
    push rcx ; 保存计数器
    mov rdi, KBReturn2
    call printf

PrintKBEnd:
    pop rcx ; 恢复计数器
    inc rcx
    cmp rcx, 0xa
    jne PrintKeyBoardLoop
    ret

; ====

CustomStrlen: ; 以[sil]为终止符计算[rdi]字符串长度
    xor rax, rax ; 重置循环计数器
strlenLoop:
    mov byte bl, [rdi+rax] ; bl = buffer[rax]
    inc rax ; 每检查1字节 rax++
    cmp bl, sil
    jne strlenLoop
    dec rax ; 去掉最后检查的字节
    ret


; ===========================================
; 处理用户输入时的输出

WrongLength:
    mov rdi, MSG5
    mov rsi, [Attempts]
    call printf
    jmp GuessStart

LetterCorrect:
    push rcx ; 保存循环计数器和正确字母计数器
    push rsi
    sub rax, 0x30 ; ASCII -> Hex位次
    mov [KnownNumbers+rax], 0x1 ; 0x1 = 字母正确
    add rax, 0x30 ; 恢复ASCII
    mov rdi, LetterGreen
    mov rsi, rax
    call printf
    pop rsi ; 恢复计数器
    pop rcx
    inc rcx
    inc rsi
    jmp CheckLetters

LetterContain:
    push rcx ; 保存循环计数器和正确字母计数器
    push rsi
    sub rax, 0x30 ; ASCII -> Hex位次
    mov [KnownNumbers+rax], 0x2 ; 0x2 = 字母存在
    add rax, 0x30 ; 恢复ASCII
    mov rdi, LetterYellow
    mov rsi, rax
    call printf
    pop rsi ; 恢复计数器
    pop rcx
    inc rcx
    jmp CheckLetters

LetterNotContain:
    push rcx ; 保存循环计数器和正确字母计数器
    push rsi
    sub rax, 0x30 ; ASCII -> Hex位次
    mov [KnownNumbers+rax], 0x3 ; 0x3 = 字母不存在
    add rax, 0x30 ; 恢复ASCII
    mov rdi, LetterRed
    mov rsi, rax
    call printf
    pop rsi ; 恢复计数器
    pop rcx
    inc rcx
    jmp CheckLetters

; ===========================================
