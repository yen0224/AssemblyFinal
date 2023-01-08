.486 
.model flat, stdcall 
option casemap:none ; Case sensitive

include main.inc

WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD

; 不確定是什麼
szText MACRO Name, Text:VARARG
    LOCAL lbl
        jmp lbl
            Name db Text,0
        lbl:
    ENDM

.const
    background equ 100
    menu equ 101
    ball_image equ 102
    victor_2 equ 103
    brick_image equ 104
    lose equ 105
    p2 equ 1002
    CREF_TRANSPARENT  EQU 0FF00FFh
    CREF_TRANSPARENT2 EQU 0FF0000h
    PLAYER_SPEED  EQU  10
    PLAYER_NEG_SPEED  EQU  -10
    brick_amount        EQU      24

.data
    ; NOTSURE
    szDisplayName   db  "Arkanoid",0    ;DD:Define Double Word，要用DWORD也可
    CommandLine     dd  0               ;WinMain函式的參數之一，該參數設null也可
    buffer          db  256 dup(?)
    hBmp            dd  0
    menuBmp         dd  0
    victoryBmp     dd  0
    loseBmp         dd  0
    p2_spritesheet  dd  0               ;spritesheet載入圖片，灰色方框，資料壓縮
    ballBmp         dd  0
    brickBmp        dd  0
    paintstruct     PAINTSTRUCT <>      ;內有ballObj、sizePoint
    ultimate_player1    BYTE    0
    brick_manager       dd      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    brick_left          dd    24
    life                BYTE     3
    GAMESTATE           BYTE     1      ;game status
    ;遊戲狀態
        ; 1 - menu
        ; 2 - in_game
        ; 3 - player_win
        ; 4 - player_lost

    ; NOTSURE
    ; - MCI_OPEN_PARMS Structure ( API=mciSendCommand ) -
    open_dwCallback         dd ?
    open_wDeviceID          dd ?
    open_lpstrDeviceType    dd ?
    open_lpstrElementName   dd ?
    open_lpstrAlias         dd ?

    ; - MCI_GENERIC_PARMS Structure ( API=mciSendCommand ) -
    generic_dwCallback      dd ?

    ; - MCI_PLAY_PARMS Structure ( API=mciSendCommand ) -
    play_dwCallback         dd ?
    play_dwFrom             dd ?
    play_dwTo               dd ?

; NOTSURE
; 無初始值之資料段與常數資料段
.data?
hInstance HINSTANCE ?

hWnd HWND ?
thread1ID DWORD ?
thread2ID DWORD ?


.code 
start:
    ; NOTSURE
    invoke GetModuleHandle, NULL ; provides the instance handle
    mov    hInstance, eax

    ; 讀取 BMP 圖像
    invoke LoadBitmap, hInstance, background    ;args:handle,bitmap resource
    mov    hBmp, eax

    invoke LoadBitmap, hInstance, menu
    mov    menuBmp, eax

    invoke LoadBitmap, hInstance, victor_2
    mov    victoryBmp, eax

    invoke LoadBitmap, hInstance, p2
    mov     p2_spritesheet, eax

    invoke LoadBitmap, hInstance, ball_image
    mov     ballBmp, eax

    invoke LoadBitmap, hInstance, brick_image
    mov     brickBmp, eax

    invoke LoadBitmap, hInstance, lose
    mov    loseBmp, eax


    ;WinMain 函數是用戶為基於 Microsoft Windows 的應用程序提供的入口點的常規名稱
    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT    
    invoke ExitProcess,eax

    ; 判斷 barObj 的 speed 是否為 0, 設定 stopped 為 1
    isStopped proc addrPlayer:dword
        assume edx:ptr barStruct
        mov edx, addrPlayer

        .if [edx].barObj.speed.x == 0
            mov [edx].stopped, 1
        .endif

        ret
    isStopped endp
    
    ;* the process who draw the background
    paintBackground proc _hdc:HDC, _hMemDC:HDC, _hMemDC2:HDC
        LOCAL rect   :RECT      ;RECT 結構定義了矩形左上角和右下角的坐標。

        ; paint background image
        .if(GAMESTATE == 1)
            invoke SelectObject, _hMemDC2, menuBmp  ;SelectObject 函數將一個對象選擇到指定的設備內容 (DC) 中。新對象替換相同類型的先前對象。
        .elseif(GAMESTATE == 2)
            invoke SelectObject, _hMemDC2, hBmp
        .elseif(GAMESTATE == 3)
            invoke SelectObject, _hMemDC2, victoryBmp
        .elseif(GAMESTATE == 4)
            invoke SelectObject, _hMemDC2, loseBmp
        .endif
        invoke BitBlt, _hMemDC, 0, 0, 910, 522, _hMemDC2, 0, 0, SRCCOPY     ;BitBlt 函數執行將與像素矩形相對應的顏色數據從指定的源設備內容到目標設備內容的bit-block傳輸。

        .if(GAMESTATE == 2)
        ; paint score
            invoke SetTextColor,_hMemDC,00FF8800h
        
            invoke wsprintf, addr buffer, chr$("life remain = %d"), life
            mov   rect.left, 360
            mov   rect.top , 900
            mov   rect.right, 490
            mov   rect.bottom, 50  

            invoke DrawText, _hMemDC, addr buffer, -1, \
                addr rect, DT_CENTER or DT_VCENTER or DT_SINGLELINE

        ; paint bricks remain
            invoke SetTextColor,_hMemDC,00FF8800h
            invoke wsprintf, addr buffer, chr$("bricks remain = %d"), brick_left
            mov   rect.left, 360
            mov   rect.top , 935
            mov   rect.right, 490
            mov   rect.bottom, 50  

            invoke DrawText, _hMemDC, addr buffer, -1, \
                addr rect, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        .endif

        ret

    paintBackground endp

    ;* the process who draw the player
    paintPlayers proc _hdc:HDC, _hMemDC:HDC, _hMemDC2:HDC
        ; Bar
        invoke SelectObject, _hMemDC2, p2_spritesheet

        movsx eax, bar.direction
        mov ebx, BAR_HALF_WIDTH
        mul ebx
        mov ecx, eax

        invoke isStopped, addr bar

        mov edx, 0

        mov eax, bar.barObj.pos.x
        mov ebx, bar.barObj.pos.y
        sub eax, BAR_HALF_WIDTH
        sub ebx, BAR_HALF_HEIGHT

        invoke TransparentBlt, _hMemDC, eax, ebx, BAR_WIDTH, BAR_HEIGHT, _hMemDC2, edx, ecx, BAR_WIDTH, BAR_HEIGHT, 16777215

        ; Ball
        invoke SelectObject, _hMemDC2, ballBmp

        movsx eax, bar.direction
        mov ebx, BALL_SIZE
        mul ebx
        mov ecx, eax

        mov edx, 0

        mov eax, ball.ballObj.pos.x
        mov ebx, ball.ballObj.pos.y
        sub eax, BALL_HALF_SIZE
        sub ebx, BALL_HALF_SIZE

        invoke TransparentBlt, _hMemDC, eax, ebx,\
            BALL_SIZE, BALL_SIZE, _hMemDC2,
            edx, ecx, BALL_SIZE, BALL_SIZE, 16777215

        ; Brick - Row 1
        mov ecx, 8
        mov esi, OFFSET brick_manager
        paintBrickOne:
            push ecx
            mov edi, [esi]
            .if (edi == 0)
                jmp nextOne
            .endif

            invoke SelectObject, _hMemDC2, brickBmp

            movsx eax, bar.direction
            mov ebx, BRICK_HALF_WIDTH
            mul ebx
            mov ecx, eax
            mov edx, 0

            mov eax, brick.brickObj.pos.x
            mov ebx, brick.brickObj.pos.y
            sub eax, BRICK_HALF_WIDTH
            sub ebx, BRICK_HALF_HEIGHT

            invoke TransparentBlt, _hMemDC, eax, ebx, BRICK_WIDTH, BRICK_HEIGHT, _hMemDC2, edx, ecx, BRICK_WIDTH, BRICK_HEIGHT, 16777215
            nextOne :
                add brick.brickObj.pos.x, 100
                add esi, 4
                pop ecx
        loop paintBrickOne
        mov brick.brickObj.pos.x, 95

        ; Brick - Row 2
        mov brick.brickObj.pos.y, 100
        mov ecx, 8
        paintBrickTwo:
           push ecx
           mov edi, [esi]
           .if (edi == 0)
               jmp nextTwo
           .endif

           invoke SelectObject, _hMemDC2, brickBmp

          movsx eax, bar.direction
           mov ebx, BRICK_HALF_WIDTH
           mul ebx
            mov ecx, eax
            mov edx, 0

            mov eax, brick.brickObj.pos.x
            mov ebx, brick.brickObj.pos.y
            sub eax, BRICK_HALF_WIDTH
            sub ebx, BRICK_HALF_HEIGHT

            invoke TransparentBlt, _hMemDC, eax, ebx, BRICK_WIDTH, BRICK_HEIGHT, _hMemDC2, edx, ecx, BRICK_WIDTH, BRICK_HEIGHT, 16777215
            nextTwo :
               add brick.brickObj.pos.x, 100
               add esi, 4
               pop ecx
        loop paintBrickTwo
        mov brick.brickObj.pos.x, 95

        ; Brick - Row 3
        mov brick.brickObj.pos.y, 150
        mov ecx, 8
        paintBrickThree:
           push ecx
           mov edi, [esi]
           .if (edi == 0)
               jmp nextThree
           .endif
           invoke SelectObject, _hMemDC2, brickBmp
           movsx eax, bar.direction
           mov ebx, BRICK_HALF_WIDTH
           mul ebx
           mov ecx, eax
           mov edx, 0
           mov eax, brick.brickObj.pos.x
           mov ebx, brick.brickObj.pos.y
           sub eax, BRICK_HALF_WIDTH
           sub ebx, BRICK_HALF_HEIGHT
           invoke TransparentBlt, _hMemDC, eax, ebx, BRICK_WIDTH, BRICK_HEIGHT, _hMemDC2, edx, ecx, BRICK_WIDTH, BRICK_HEIGHT, 16777215
           nextThree :
               add brick.brickObj.pos.x, 100
               add esi, 4
               pop ecx
        loop paintBrickThree
        mov brick.brickObj.pos.x, 95
        mov brick.brickObj.pos.y, 50
        ret
    paintPlayers endp

    ; NOTSURE
    screenUpdate proc
        LOCAL hMemDC:HDC
        LOCAL hMemDC2:HDC
        LOCAL hBitmap:HDC
        LOCAL hDC:HDC

        invoke BeginPaint, hWnd, ADDR paintstruct   ;BeginPaint函數為繪畫準備指定的窗口，並用有關繪畫的信息填充 PAINTSTRUCT 結構。
        mov hDC, eax
        invoke CreateCompatibleDC, hDC  ;CreateCompatibleDC函數創建與指定設備兼容的內存設備內容 (DC)
        mov hMemDC, eax
        invoke CreateCompatibleDC, hDC ; for double buffering
        mov hMemDC2, eax
        invoke CreateCompatibleBitmap, hDC, 910, 522
        mov hBitmap, eax

        invoke SelectObject, hMemDC, hBitmap

        invoke paintBackground, hDC, hMemDC, hMemDC2
        .if(GAMESTATE == 2)
            invoke paintPlayers, hDC, hMemDC, hMemDC2
        .endif
        invoke BitBlt, hDC, 0, 0, 910, 522, hMemDC, 0, 0, SRCCOPY

        invoke DeleteDC, hMemDC     ;DeleteDC 函數刪除指定的設備內容 (DC)。
        invoke DeleteDC, hMemDC2
        invoke DeleteObject, hBitmap
        invoke EndPaint, hWnd, ADDR paintstruct ;EndPaint 函數標記指定窗口中的繪製結束。每次調用 BeginPaint 函數時都需要此函數，但僅在繪製完成後才需要
        ret
    screenUpdate endp

    ; NOTSURE
    paintThread proc p:DWORD
        .WHILE GAMESTATE != 5
            invoke Sleep, 8 ; 60 FPS
            invoke InvalidateRect, hWnd, NULL, FALSE ;InvalidateRect函數將一個橢圓添加到指定窗口的更新區域。更新區域代表了必須重新繪製的窗口區域的部分。
        .endw
        ret
    paintThread endp   

    ; 使玩家不會走出邊界
    changePlayerSpeed proc uses eax addrPlayer : DWORD, direction : BYTE, keydown : BYTE
        assume eax: ptr barStruct
        mov eax, addrPlayer

        .if keydown == FALSE
            .if direction == 1 ;a
                .if [eax].barObj.speed.x > 7fh
                    mov [eax].barObj.speed.x, 0 
                .endif
            .elseif direction == 3 ;d
                .if [eax].barObj.speed.x < 80h
                    mov [eax].barObj.speed.x, 0 
                .endif
            .endif
        .else
            .if direction == 2 ; a
                mov [eax].barObj.speed.x, -PLAYER_SPEED
                mov [eax].stopped, 0
            .elseif direction == 3 ; d
                mov [eax].barObj.speed.x, PLAYER_SPEED
                mov [eax].stopped, 0
            .endif
        .endif

        assume ecx: nothing
        ret
    changePlayerSpeed endp


    ; !purpose: reset the ball to the initial position
    resetBall proc
        mov ball.ballObj.speed.x, 0
        mov ball.ballObj.speed.y, 0
        mov ball.ballObj.pos.x, 420
        mov ball.ballObj.pos.y, 381
        ret
    resetBall endp


    ; !purpose: reset the position of the bar
    resetPositions proc
        mov bar.barObj.pos.x, 420
        mov bar.barObj.pos.y, 420
        ret
    resetPositions endp


    ; !purpose: reset all bricks (brick_manager) to 1
    resetBrick proc
        push esi
        push edi
        mov brick_left, brick_amount
        mov esi, OFFSET brick_manager
        mov ecx, brick_amount
        .while ecx > 0
            mov edi, 1
            mov [esi], edi
            add esi, 4
            dec ecx
        .endw
        pop edi
        pop esi
        ret
    resetBrick endp


    movePlayer proc uses eax addrPlayer:dword
        assume edx:ptr barStruct
        mov edx, addrPlayer
        assume ecx:ptr gameObject
        mov ecx, addrPlayer
        ;.if [edx].jumping == TRUE  ;如果玩家在跳躍(減速)
        ;    mov ebx, [ecx].speed.y
        ;    inc ebx
        ;    mov [ecx].speed.y, ebx
        ;.endif

        ; X AXIS ______________
        mov eax, [ecx].pos.x
        mov ebx, [ecx].speed.x
        add eax, ebx
        ;  如果玩家在屏幕範圍內，我們才改變它的位置
        .if  eax < 890 - BAR_WIDTH/2 && eax > 0 + BAR_WIDTH/2
            mov [ecx].pos.x, eax
        .endif

        ; Y AXIS ______________
        mov eax, [ecx].pos.y
        mov ebx, [ecx].speed.y
        add eax, ebx
        mov eax, 420
        mov [ecx].pos.y, eax

        ;assume ecx:nothing
        ret
    movePlayer endp

    moveBall proc uses eax addrBall:dword
        assume ebx:ptr ballStruct
        mov ebx, addrBall

        ;我們增加速度 y;eax 上的速度增量
        mov eax, [ebx].ballObj.pos.y
        mov ecx, [ebx].ballObj.speed.y
        add ax, cx

        ; if fall out of the bottom of the screen
        .if eax > 443
            invoke resetBall
            invoke resetPositions
            mov eax, [ebx].ballObj.pos.y
            mov ecx, [ebx].ballObj.speed.y
            sub life, 1
        .endif

        ; if fall out of the top of the screen
        .if eax < 30
            mov ecx, [ebx].ballObj.speed.y
            neg ecx
            mov [ebx].ballObj.speed.y, ecx
        .endif

        ; X AXIS ______________
        mov edx, [ebx].ballObj.pos.x
        mov ecx, [ebx].ballObj.speed.x
        add dx, cx

        ;如果球在屏幕邊緣，我們移動它
        .if edx > 10 && edx < 885
            mov [ebx].ballObj.pos.x, edx
        .else
            mov ecx, ball.ballObj.speed.x
            neg ecx
            mov [ebx].ballObj.speed.x, ecx 
        .endif

        mov [ebx].ballObj.pos.y, eax
        
        assume ecx:nothing
        ret 
    moveBall endp


    resetLife proc
        mov life, 3
        ret
    resetLife endp


    ; !purpose: check the amount of bricks left
    ; update variable: brick_amount
    countBricks proc
        ; preserve registers
        push eax
        push esi
        push ecx
        push edi

        mov ecx, brick_amount
        mov esi, OFFSET brick_manager
        mov eax, 0
        .while ecx > 0
            mov edi, [esi]
            .if (edi == 1)
                inc eax
            .endif
            add esi, 4
            dec ecx
        .endw
        mov brick_left, eax

        ; restore registers
        pop edi
        pop ecx
        pop esi
        pop eax
        ret
    countBricks endp

    ; !purpose: check if two objects collided
    ;* @param: object1's position and size, object2's position and size
    ;* return value: TRUE if collided, otherwise FALSE
    ; collide proc obj1Pos:point, obj2Pos:point, obj1Size:point, obj2Size:point
    ;     ;* add object's position axises with its sizes 
    ;     ;* object1
    ;     mov eax, obj1Pos.x
    ;     add eax, obj1Size.x
    ;     ;* object2
    ;     mov ebx, obj2Pos.x
    ;     ;sub ebx, obj2Size.x
    ;     ;* there shall have three threds to deal with the collision
    ;     ;* compare the right side 
    ;     .if eax > ebx
    ;         mov eax, obj1Pos.x
    ;         sub eax, obj1Size.x
    ;         mov ebx, obj2Pos.x
    ;         add ebx, obj2Size.x
    ;         ;then compare the left side
    ;         .if eax < ebx
    ;             mov cl, TRUE
    ;         .else
    ;             mov cl, FALSE
    ;         .endif
    ;     .else
    ;         mov cl, FALSE
    ;     .endif
    ;     mov eax, obj1Pos.y
    ;     add eax, obj1Size.y
    ;     ;eax:玩家的下邊界
    ;     mov ebx, obj2Pos.y
    ;     ;sub ebx, obj2Size.y
    ;     ;ebx:球的上邊界
    ;     .if eax > ebx
    ;         mov eax, obj1Pos.y
    ;         sub eax, obj1Size.y
    ;         mov ebx, obj2Pos.y
    ;         add ebx, obj2Size.y
    ;         .if eax < ebx
    ;             mov ch, TRUE
    ;         .else
    ;             mov ch, FALSE
    ;         .endif
    ;     .else
    ;         mov ch, FALSE
    ;     .endif
    ;     pop ebx
    ;     pop eax
    ;     ret
    ; collide endp

    ; !purpose: deal with collision between ball and bar
    ballColliding proc
        ; preserve registers
        push eax
        push ebx
        push ecx
        push edx
        
        ;invoke collide, bar.barObj.pos, ball.ballObj.pos, bar.sizePoint, ball.sizePoint
        mov eax, bar.barObj.pos.x
        add eax, bar.sizePoint.x
        mov ebx, ball.ballObj.pos.x
        .if eax > ebx
            mov eax, bar.barObj.pos.x
            sub eax, bar.sizePoint.x
            mov ebx, ball.ballObj.pos.x
            add ebx, ball.sizePoint.x
            .if eax < ebx
                mov cl, TRUE
            .else
                mov cl, FALSE
            .endif
        .else
            mov cl, FALSE
        .endif
        mov eax, bar.barObj.pos.y
        add eax, bar.sizePoint.y
        mov ebx, ball.ballObj.pos.y
        .if eax > ebx
            mov eax, bar.barObj.pos.y
            sub eax, bar.sizePoint.y
            mov ebx, ball.ballObj.pos.y
            add ebx, ball.sizePoint.y
            .if eax < ebx
                mov ch, TRUE
            .else
                mov ch, FALSE
            .endif
        .else
            mov ch, FALSE
        .endif

        .if ch == TRUE  && cl == TRUE
            mov eax, bar.barObj.speed.x
            .if eax > 25
                .if eax == 0                                    ; 如果玩家是靜止的
                    mov eax, ball.ballObj.speed.x
                    add eax, 25
                .else                                           ; 如果玩家在移動
                    add eax, bar.barObj.speed.x          
                    add eax, PLAYER_SPEED
                .endif
            .endif
            mov ball.ballObj.speed.y, PLAYER_NEG_SPEED
            mov ball.ballObj.speed.x, eax       
        .endif
        
        pop edx
        pop ecx
        pop ebx
        pop eax
        ret
    ballColliding endp

    ; !purpose: deal with collision between ball and brick

    brickCollide proc
        push eax
        push ebx
        push ecx
        push edi
        push esi

        mov eax, ball.ballObj.pos.x
        ;add eax, BALL_HALF_SIZE
        mov ebx, brick.brickObj.pos.x

        .if eax > ebx
            ;sub eax, ball.sizePoint.x
            add eax, BALL_SIZE
            add ebx, 800
            .if eax < ebx
                mov cl, TRUE
            .else
                mov cl, FALSE
            .endif
        .else
            mov cl, FALSE
        .endif
        mov eax, ball.ballObj.pos.y
        ;add eax, BALL_HALF_SIZE
        mov ebx, brick.brickObj.pos.y
        ;sub ebx, brick.sizePoint.y
        .if eax > ebx
            ;mov eax, ball.ballObj.pos.y
            add eax, BALL_HALF_SIZE
            ;mov ebx, brick.brickObj.pos.y
            add ebx, TOTAL_BRICK_HEIGHT
            .if eax < ebx
                mov ch, TRUE
            .else
                mov ch, FALSE
            .endif
        .else
            mov ch, FALSE
        .endif
        
        .if ch == TRUE  && cl == TRUE
            ;index
            ;initialize edx for division
            mov edx, 0
            mov eax, ball.ballObj.pos.x
            sub eax, 95
            mov ecx, 100
            div ecx
            mov ecx, eax

            ;when we get the index of the hitten brick, we can use it to change the brick's state
            mov eax, ball.ballObj.pos.y
            mov ebx, eax
            add ebx, BALL_SIZE
            
            ;eax is the top point of ball
            ;ebx is the bottom point of ball
            .if eax >= 70 && eax <=90 || ebx >=50 && ebx <= 70
                jmp judge
            .elseif eax >= 120 && eax <=140 || ebx >=100 && ebx <= 120
                add ecx, 8
                jmp judge
            .elseif eax >= 170 && eax <=190 || ebx >=150 && ebx <= 170
                add ecx, 16
                jmp judge   
            .endif
            jmp endproc
            judge:
                .if ecx < 24 && brick_manager[ecx*4] == 1 
                    mov brick_manager[ecx*4], 0
                    mov eax, ball.ballObj.speed.y
                    neg eax
                    mov ball.ballObj.speed.y, eax
                    dec brick_left
                .endif
            .endif
        endproc:
        pop esi
        pop edi
        pop ecx
        pop ebx
        pop eax

        ret
    brickCollide endp


    ; NOTSURE
    gameManager proc p:dword
        LOCAL area:RECT

        game:
            .while GAMESTATE == 2
                invoke Sleep, 30
                invoke movePlayer, addr bar
                ; TODO : 呼叫碰撞
                invoke brickCollide     ;collide between brick and ball
                invoke ballColliding    ;collide between ball and bar and boarder
                invoke moveBall, addr ball
                invoke countBricks

                ; if no bricks left, win
                .if (brick_left == 0)
                    mov GAMESTATE, 3
                .ELSEIF (life == 0)
                    mov GAMESTATE, 4
                .endif
            .endw

        jmp game

        ret
    gameManager endp


    WinMain proc hInst     :DWORD,
                hPrevInst :DWORD,
                CmdLine   :DWORD,
                CmdShow   :DWORD

        LOCAL wc   :WNDCLASSEX
        LOCAL msg  :MSG     ;MSG結構包含來自Thread的消息隊列的信息

        LOCAL Wwd  :DWORD
        LOCAL Wht  :DWORD
        LOCAL Wtx  :DWORD
        LOCAL Wty  :DWORD

        szText szClassName,"Windowclass1"
        
        ;==================================================
        ; Fill WNDCLASSEX structure with required variables
        ;==================================================

        mov wc.cbSize,         sizeof WNDCLASSEX
        mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                            or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc,    offset WndProc       ;本視窗的訊息處裡函式
        mov wc.cbClsExtra,     NULL                 ;附加引數
        mov wc.cbWndExtra,     NULL                 ;附加引數
        m2m wc.hInstance,      hInst                ;當前應用程式的例向控制代碼
        mov wc.hbrBackground,  COLOR_BTNFACE+1      ;視窗背景色
        mov wc.lpszMenuName,   NULL                 ;視窗選單
        mov wc.lpszClassName,  offset szClassName   ;視窗結構體的名稱 ;給視窗結構體命名，CreateWindow函式將根據視窗結構體名稱來建立視窗
        ; RC 文件中的圖標 ID
        invoke LoadIcon,hInst, IDI_APPLICATION      ;視窗圖式
        mov wc.hIcon,          eax
        invoke LoadCursor,NULL,IDC_ARROW            ;視窗游標
        mov wc.hCursor,        eax
        mov wc.hIconSm,        0

        invoke RegisterClassEx, ADDR wc             ;註冊視窗


        invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW, \
                            ADDR szClassName, \
                            ADDR szDisplayName,\
                            WS_OVERLAPPEDWINDOW,\
                            ;Wtx,Wty,Wwd,Wht,
                            CW_USEDEFAULT,CW_USEDEFAULT, 910, 552, \      ;窗口大小
                            NULL,NULL,\
                            hInst,NULL


        mov   hWnd,eax  ; copy return value into handle DWORD

        invoke LoadMenu,hInst,600                 ; load resource menu
        invoke SetMenu,hWnd,eax                   ; set it to main window

        invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
        invoke UpdateWindow,hWnd                  ; update the display

        ;===================================
        ; Loop until PostQuitMessage is sent
        ;===================================

        StartLoop:
        invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
        cmp eax, 0                                  ; exit if GetMessage()
        je ExitLoop                                 ; returns zero
        invoke TranslateMessage, ADDR msg           ; translate it
        invoke DispatchMessage,  ADDR msg           ; send it to message proc
        jmp StartLoop
        ExitLoop:

        return msg.wParam   ;wParam:指定有關消息的附加信息。確切含義取決於消息成員的值

    WinMain endp


    WndProc proc hWin:DWORD,
                 uMsg:DWORD,
                 wParam:DWORD,
                 lParam:DWORD
        ;variables
        LOCAL hDC:DWORD
        LOCAL memDC:DWORD
        LOCAL memDCp1:DWORD
        LOCAL hOld:DWORD
        LOCAL hWin2:DWORD
        LOCAL direction:BYTE
        LOCAL keydown:BYTE
        mov direction, -1
        mov keydown, -1

    
        ; 當它創建
        .if uMsg == WM_CREATE  ;當應用程序通過調用 CreateWindowEx 或 CreateWindow 函數請求創建窗口時，將發送 WM_CREATE 消息
            mov eax, offset gameManager 
            invoke CreateThread, NULL, NULL, eax, 0, 0, addr thread1ID 
            invoke CloseHandle, eax 

            mov eax, offset paintThread 
            invoke CreateThread, NULL, NULL, eax, 0, 0, addr thread2ID 
            invoke CloseHandle, eax 

        .elseif uMsg == WM_PAINT    ;當系統或其他應用程序請求繪製應用程序窗口的一部分時，會發送 WM_PAINT 消息
            invoke screenUpdate

        .elseif uMsg == WM_DESTROY                                        ; if the user closes our window 
            invoke PostQuitMessage,NULL                                   ; quit our application 

        ; game manager
        .elseif uMsg == WM_CHAR
            .if (wParam == 13) ; [ENTER]
                .if GAMESTATE == 1
                    invoke resetBrick
                    invoke resetPositions
                    invoke resetBall
                    invoke resetLife
                    mov GAMESTATE, 2
                .elseif GAMESTATE == 2
                    mov GAMESTATE, 1
                .elseif (GAMESTATE == 3) || (GAMESTATE == 4)
                    invoke resetBrick
                    invoke resetPositions
                    invoke resetBall
                    invoke resetLife
                    mov GAMESTATE, 2
                .endif                
            .endif

            ; [Space]
            .if (wParam == 32) && (GAMESTATE == 2)
                invoke resetBall
                mov ball.ballObj.speed.y, PLAYER_NEG_SPEED
            .endif

        ; 當釋放非系統鍵時
        .elseif uMsg == WM_KEYUP            

            .if (wParam == VK_LEFT) ;左
                mov keydown, FALSE
                mov direction, 1

            .elseif (wParam == VK_RIGHT) ;右
                mov keydown, FALSE
                mov direction, 3
            .endif

            .if direction != -1
                invoke changePlayerSpeed, ADDR bar, direction, keydown
                mov direction, -1
                mov keydown, -1
            .endif            
           
        ;當按下非系統鍵時
        .elseif uMsg == WM_KEYDOWN
            .if (wParam == VK_LEFT) ; 左
                mov keydown, TRUE
                mov direction, 2

            .elseif (wParam == VK_RIGHT) ; 右
                mov keydown, TRUE
                mov direction, 3
            .endif

            .if direction != -1
                invoke changePlayerSpeed, ADDR bar, direction, keydown
                mov direction, -1
                mov keydown, -1
            .endif
        .else
            invoke DefWindowProc,hWin,uMsg,wParam,lParam ;DefWindowProc 函數調用默認窗口過程來為應用程序不處理的任何窗口消息提供默認處理
        .endif
        ret
    WndProc endp
end start