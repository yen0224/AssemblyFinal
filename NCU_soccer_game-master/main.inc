include C:\masm32\include\masm32rt.inc
include C:\Masm32\include\winmm.inc 
include C:\Masm32\Include\msimg32.inc

includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\kernel32.lib
includelib C:\Masm32\Lib\msimg32.lib
includelib C:\Masm32\lib\winmm.lib
includelib C:\Masm32\Lib\masm32.lib

point struct 
    x dd 0      
    y dd 0
point ends

gameObject struct
    pos     point <>
    speed   point <> ; 水平和垂直速度
gameObject ends

barStruct struct
    barObj             gameObject <>
    sizePoint             point <>
    stopped               BYTE 0
    jumping               BYTE 0
    direction             BYTE 0
    goals                 dd   0
barStruct ends

ballStruct struct
    ballObj     gameObject <>
    sizePoint   point <>
ballStruct ends

brickStruct struct
    brickObj    gameObject <>
    sizePoint   point <>
brickStruct ends

.const
    BAR_WIDTH      EQU 232
    BAR_HALF_WIDTH EQU BAR_WIDTH / 2
    BAR_HEIGHT      EQU 39
    BAR_HALF_HEIGHT EQU BRICK_HEIGHT / 2

    BALL_SIZE       EQU 30
    BALL_HALF_SIZE  EQU BALL_SIZE / 2

    BRICK_WIDTH      EQU 90
    BRICK_HALF_WIDTH EQU BRICK_WIDTH / 2
    BRICK_HEIGHT      EQU 40
    BRICK_HALF_HEIGHT EQU BRICK_HEIGHT / 2

    ;BALL_SPEED_Y EQU -17

    D_RIGHT       EQU 0 
    D_TOP         EQU 1  
    D_LEFT        EQU 2     
    D_DOWN        EQU 3
    D_DOWN_RIGHT  EQU 4
    D_DOWN_LEFT   EQU 5
    D_TOP_LEFT    EQU 6
    D_TOP_RIGHT   EQU 7
    MAX_GOALS EQU 3

.data
    bar barStruct <<<500, 500>,  <0, 0>>, <232/2, 39>, 0, D_LEFT, 0 >
    ball ballStruct <<<420, 250>,  <0, 0>>>
    brick brickStruct <<<95, 50>, <0, 0>>, <0, 0>>
    auxiliar_point point <0, 0>