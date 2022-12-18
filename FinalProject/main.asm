.386 
.model flat, stdcall 
option casemap:none
includelib C:\masm32\lib\kernel32.lib 
.data 
.code 
start:
    ExitProcess PROTO STDCALL :DWORD
    invoke ExitProcess,0 
end start