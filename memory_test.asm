
; --------------------- Константы -------------------------------


WriteIndicatorPort      equ 8                               ; порт индикаторов, отображающих записанный байт
ReadIndicatorPort       equ 12                              ; порт индикаторов, отображающих считанный байт
RamStartAddress         equ 3072                            ; адрес начала RAM
RamEndAddress           equ 4096                            ; адрес конца RAM
RamSize                 equ RamEndAddress - RamStartAddress ; размер RAM
RomStartAddress         equ 0                               ; адрес начала ROM
RomModuleSize           equ 1024                            ; размер микросхемы ROM
BinDumpFileName         equ "memory_test_no_ctc.bin"        ; имя файла в который записывается бинарный дапм

InnerCycleDelayConst    equ 50000                           ; константа внутреннего цикла задержки с которой
                                                            ; внутренний цикл должен выполняться примерно секунду
OuterCycleDelayConst    equ 3                               ; константа внешнего цикла, примерное кол-во секунд,
                                                            ; которые выподняется задержка

; 4 разных значения, которые записываются/считываются при выполнении тестов
TestByteValue1          equ 0
TestByteValue2          equ 255
TestByteValue3          equ 10101010b
TestByteValue4          equ 01010101b


; --------------------- Макросы -------------------------------


; макрос вызова процедуры теста
; параметры:
; testByte - значение (байт), используемое для записи и проверки в данном тесте
; testProc - адрес процедуры проверки памяти
; indicatorsValue - значение, выводимое на индикаторах, отображающее общий прогресс
callTest                macro(testByte, testProc, indicatorsValue)
                        ld a, testByte
                        ld hl, TestReturnAddress
                        jp testProc
TestReturnAddress:      jr nz, Exit
                        setIndicators(indicatorsValue)
                        mend

callDelay               macro()
                        ld hl,DelayExit ; загружаем адрес команды, которая будет после jp Delay
                        jp Delay
DelayExit:
                        mend

; макрос, выставляющий одинаковое значение на обоих светодиодных индикаторах
; параметры:
; value - значение (байт), которое выставляется на обоих индикаторах
setIndicators           macro(value)
                        ld a, value
                        out (WriteIndicatorPort), a
                        out (ReadIndicatorPort), a
                        mend


; --------------------- Начало -------------------------------


                        org RomStartAddress

                        setIndicators(255)              ; включаем все светодиоды на обоих индикаторах
                                                        ; перед выполнением тестов

                        callDelay()                      ; вызываем задержку

                        setIndicators(0)                ; выключаем все индикаторы

; выполняем тесты, в которых происходит побайтная запись и чтение:
                        callTest(TestByteValue1, ByteCheck, 00000001b)
                        callTest(TestByteValue2, ByteCheck, 00000011b)
                        callTest(TestByteValue3, ByteCheck, 00000111b)
                        callTest(TestByteValue4, ByteCheck, 00001111b)

; выполняем тесты, в которых память сначала заполняется, а затем побайтно проверяется
                        callTest(TestByteValue1, BlockCheck, 00011111b)
                        callTest(TestByteValue2, BlockCheck, 00111111b)
                        callTest(TestByteValue3, BlockCheck, 01111111b)
                        callTest(TestByteValue4, BlockCheck, 11111111b)

; включаем первый и последний светодиоды на обоих индикаторах в знак успешного завершения тестов
                        setIndicators(10000001b)

Exit:
                        halt                            ; конец программы


; --------------------- Подпрограммы -------------------------------


; подпрограмма побайтной проверки памяти
; параметры:
; регистр A должен содержать значение, используемое для записи и проверки
; в HL должен содержаться адрес возврата для подпрограммы
ByteCheck:
                        exx                             ; переключаем регисты чтоб сохранить HL
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

                        exx
                        jp (hl)                         ; возврат


; подпрограмма проверки в режиме "записить всю память, затем считывать"
; регистр A должен содержать значение, используемое для записи и проверки
; в HL должен содержаться адрес возврата для подпрограммы
BlockCheck:
; сначала заполним всю область памяти
                        exx                             ; переключаем регисты чтоб сохранить HL
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

                        exx
                        jp (hl)                         ; возврат


; Обработчик ошибок
Error:
                        out (WriteIndicatorPort), a ; выводим значение, которое мы записали
                        dec hl                      ; hl было увеличено на 1 командой cpi, уменьшаем
                        ld a, (hl)                  ; считываем ошибочное значение
                        out (ReadIndicatorPort), a  ; выводим значение, которое мы считали

                        exx
                        jp (hl)                     ; возврат


; Подпрограмма задержки
; в HL должен содержаться адрес возврата для подпрограммы
Delay:
                        exx                             ; переключаем регисты чтоб сохранить HL
                        ld bc, OuterCycleDelayConst     ; BC - счетчик внешнего цикла
Outer:
                        ld de, InnerCycleDelayConst     ; DE - счетчик внутреннего цикла
Inner:
                        dec de                          ; DE -= 1
                        ld a, d
                        or e                            ; проверим, равно ли DE нулю (A = D | E)
                        jp nz, Inner                    ; если DE не ноль, продолжаем внутренний цикл
                        dec bc                          ; BC =- 1
                        ld a, b
                        or c                            ; проверим, равно ли BC нулю (A = B | C)
                        jp nz, Outer                    ; если BC не ноль, продолжаем внешний цикл

                        exx
                        jp (hl)                         ; возврат
End:

; при трансляции сохранить бинарный дамп с нулевого адреса размером 1К в указанный файл
output_bin      BinDumpFileName, RomStartAddress, End
