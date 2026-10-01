.intel_syntax noprefix
.global _start
.extern http_start_server
.extern http_send_response

.section .rodata
resp_headers:
    .ascii "HTTP/1.1 200 OK\r\nServer: asmhttp-asm\r\nContent-Type: text/plain\r\nContent-Length: 15\r\n\r\n"
resp_headers_len = . - resp_headers
resp_body:
    .ascii "Hello from ASM\n"
resp_body_len = . - resp_body

.section .text
_start:
    lea rdi, [rip + handle_request]
    call http_start_server
    mov eax, 60
    xor edi, edi
    syscall

handle_request:
    # In: rdi = req, rsi = wire_buf, edx = client_fd
    mov edi, edx                        # arg1: client_fd
    lea rsi, [rip + resp_headers]       # arg2: headers
    mov rdx, resp_headers_len           # arg3: header_len
    lea rcx, [rip + resp_body]          # arg4: body
    mov r8, resp_body_len               # arg5: body_len
    call http_send_response
    ret
