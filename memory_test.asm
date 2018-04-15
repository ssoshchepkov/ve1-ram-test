WriteIndicatorPort      equ 8                               ; порт индикаторов, отображающих записанный байт
ReadIndicatorPort       equ 12                              ; порт индикаторов, отображающих считанный байт
RamStartAddress         equ 3072                            ; адрес начала RAM
RamEndAddress           equ 4096                            ; адрес конца RAM
RamSize                 equ RamEndAddress - RamStartAddress ; размер RAM
RomStartAddress         equ 0                               ; адрес начала ROM
RomModuleSize           equ 1024                            ; размер микросхемы ROM
BinDumpFileName         equ "memory_test.bin"               ; имя файла в который записывается бинарный дапм

; 4 разных значения, которые записываются/считываются при выполнении тестов
TestByteValue1          equ 0
TestByteValue2          equ 255
TestByteValue3          equ 10101010b
TestByteValue4          equ 01010101b

; 4 порта таймера Z80 CTC
CtcChannel0             equ 0
CtcChannel1             equ 1
CtcChannel2             equ 2
CtcChannel3             equ 3

InterruptVectorTable    equ 10000b                          ; Начало таблицы векторов прерываний Z80 CTC
Channel3VectorOffset    equ 110b                            ; Смещение вектора для канала 3, определяемое 1м и 2м
                                                            ; битами

; макрос вызова процедуры теста
; параметры:
; testByte - значение (байт), используемое для записи и проверки в данном тесте
; testProc - адрес процедуры проверки памяти
callTest                macro(testByte, testProc)
                        ld a, testByte
                        call testProc
                        jr nz, Exit
                        mend

; макрос, выставляющий одинаковое значение на обоих светодиодных индикаторах
; параметры:
; value - значение (байт), которое выставляется на обоих индикаторах
setIndicators           macro(value)
                        ld a, value
                        out (WriteIndicatorPort), a
                        out (ReadIndicatorPort), a
                        mend

                        org RomStartAddress                 ; начало ROM
                        jr InitCtc                          ; пропускаем таблицу прерываний и переходим к 
                                                            ; инициализации таймера

                        org InterruptVectorTable + Channel3VectorOffset ; адрес вектора для канала 3
                        DEFW Channel3Vector                 ; вектор прерывания канала 3

InitCtc:
; Инициализация каналов 0 and 1
                        ld a, 00000011b                 ; параметры каналов (7-0 биты): прерывания выкл., режим
                                                        ; таймера, делитель = 16, CLK/TRG Edge = Falling Edge, 
                                                        ; таймер запускается после загрузки константы, константа
                                                        ; не передается после выполнения этой команды, программный
                                                        ; reset включен, это команда управления
                        out (CtcChannel0),A             ; Выполняем команду для канала 0. Канал не используется.
                        out (CtcChannel1),A             ; Выполняем команду для канала 1. Канал не используется.

; Инициализация канала 2
; Канал  делит CPU CLK на (256*256) передавая сигнал на TO2. TO2 подсоеденино TRG3.
                        ld A,00100111b                  ; параметры каналов (7-0 биты): прерывания выкл., режим
                                                        ; таймера, делитель = 256, CLK/TRG Edge = Falling Edge, 
                                                        ; таймер запускается после загрузки константы, константа
                                                        ; передается после выполнения этой команды, программный
                                                        ; reset включен, это команда управления
                        out (CtcChannel2), A
                        ld A, 0FFh                      ; задаем временную констанну равную 255
                        out (CtcChannel2), A            ; для канала 2
                                                        ; T02 выход = CPU_CLK/(256*256)
; Инициализация канала 3
; на вход TRG канала 3 поступает сигнал из TO2
; Канал 3 делит TO2 на AFh
; Канал 3 вызывает прерывание CPU. В примере, написанном для часов CPU 5 MHz указывалось, что при заданных
; константах прерывание будет вызываться приблизительно раз в 2 секунды.
; Обработчик прерывания находится по адресу Channel3Vector
                        ld A, 11000111b                 ; параметры каналов (7-0 биты): прерывания вкл., режим
                                                        ; счетчика, делитель не важен, CLK/TRG Edge = Falling Edge, 
                                                        ; таймер не важен, константа передается после выполнения этой 
                                                        ; команды, программный reset включен, это команда управления
                        out (CtcChannel3), A
                        ld A, 0AFh                      ; задаем временную константу, равную AFh
                        out (CtcChannel3), A            ; для канала 3
                        ld A, InterruptVectorTable      ; вектор прерывания задается битами 7­-3
                                                        ; биты 2 и 1 не важны, т.к. будут выставляться автоматически 
                                                        ; в зависимости от канала, бит 0 указывает, что эта команда
                                                        ; задает уектор прерывания
                        out (CtcChannel0), A            ; загружаем вектор для канала 0

                        ld A, 0
                        ld I, A                         ; обнулим регистр I
                        im 2                            ; режим прерываний 2
                        ei                              ; включаем прерывания

                        setIndicators(255)              ; включаем все светодиоды на обоих индикаторах
                                                        ; перед выполнением тестов

                        halt                            ; ждем прерывание от таймера

; выполняем тесты, в которых происходит побайтная запись и чтение:
                        callTest(TestByteValue1, ByteCheck)
                        callTest(TestByteValue2, ByteCheck)
                        callTest(TestByteValue3, ByteCheck)
                        callTest(TestByteValue4, ByteCheck)

; выполняем тесты, в которых память сначала заполняется, а затем побайтно проверяется
                        callTest(TestByteValue1, BlockCheck)
                        callTest(TestByteValue2, BlockCheck)
                        callTest(TestByteValue3, BlockCheck)
                        callTest(TestByteValue4, BlockCheck)

; включаем все светодиоды на обоих индикаторах в знак успешного завершения тестов
                        setIndicators(255)

Exit:
                        halt                            ; конец программы

; подпрограмма побайтной проверки памяти
; параметры:
; регистр A должен содержать значение, используемое для записи и проверки
ByteCheck:
                        ld hl, RamStartAddress          ; начало RAM в HL
                        ld bc, RamSize                  ; размер RAM в BC
ByteCompare:
                        ld (hl), a                      ; записываем содержимое A в ячейку
                        cpi                             ; сравниваем содержимое ячейки, на которую укадывает hl
                                                        ; hl с регистром A; затем hl+=1, bc-=1
                                                        ; флаг z содержит резултьтат сравнения 1, если равно
                                                        ; флаг c/v сбрасывается в 0, если bc = 0
                        jr nz, Error                    ; если флаг z равен 0, то у нас ошибка
                        jp pe, ByteCompare              ; если флаг c/v не 0, то переходим к следующей ячейке

                        ret

BlockCheck:
; сначала заполним всю область памяти
                        ld hl, RamStartAddress          ; начало RAM в HL
                        ld bc, RamSize                  ; размер RAM в BC
                        ld (hl), a                      ; запишем в начальную ячейку значение, которым надо заполнить
                                                        ; панять 
                        dec bc                          ; bc -= 1, т.к. 1 байт мы уже записали
                        ld d, h                         ; DE = HL
                        ld e, l
                        inc de                          ; DE += 1
                        ldir                            ; последовательно копируем BC байт из области, начинающейся
                                                        ; с HL в область, начинающаяся с DE, заполняя её нужным 
                                                        ; значением

; теперь последовтельно сравниваем
                        ld hl, RamStartAddress          ; начало RAM в HL
                        ld bc, RamSize                  ; размер RAM в BC
BlockCompare:
                        cpi                             ; сравниваем содержимое ячейки, на которую укадывает hl
                                                        ; hl с регистром A; затем hl+=1, bc-=1
                                                        ; флаг z содержит резултьтат сравнения 1, если равно
                                                        ; флаг c/v сбрасывается в 0, если bc = 0
                        jr nz, Error                    ; если флаг z равен 0, то у нас ошибка
                        jp pe, BlockCompare             ; если флаг c/v не 0, то переходим к следующей ячейке

                        ret

; Обработчик ошибок
Error:
                        out (WriteIndicatorPort), a ; выводим значение, которое мы записали
                        dec hl                      ; hl было увеличено на 1 командой cpi, уменьшаем
                        ld a, (hl)                  ; считываем ошибочное значение
                        out (ReadIndicatorPort), a  ; выводим значение, которое мы считали

                        ret

; Обработчик прерывания от таймера
Channel3Vector:
                        setIndicators(0)            ; Выключаем индикаторы
                        reti                        ; Возвращаемся из прерывания не включая разрешения на дальнейшие
                                                    ; прерывания

; при трансляции сохранить бинарный дамп с нулевого адреса размером 1К в указанный файл
output_bin      BinDumpFileName, RomStartAddress, RomModuleSize
