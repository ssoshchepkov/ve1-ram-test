
; --------------------- Константы -------------------------------


WriteIndicatorPort      equ 8                               ; порт индикаторов, отображающих записанный байт
ReadIndicatorPort       equ 12                              ; порт индикаторов, отображающих считанный байт
RamStartAddress         equ 3072                            ; адрес начала RAM
RamEndAddress           equ 4096                            ; адрес конца RAM
RamSize                 equ RamEndAddress - RamStartAddress ; размер RAM
RomStartAddress         equ 0                               ; адрес начала ROM
RomModuleSize           equ 1024                            ; размер микросхемы ROM
BinDumpFileName         equ "memory_test.bin"               ; имя файла в который записывается бинарный дапм

InnerCycleDelayConst    equ 60000                           ; константа внутреннего цикла задержки
OuterCycleDelayConst    equ 3                               ; константа внешнего цикла задержки

; 4 разных значения, которые записываются/считываются при выполнении тестов
TestByteValue1          equ 0
TestByteValue2          equ 255
TestByteValue3          equ 10101010b
TestByteValue4          equ 01010101b

ShiftCheckStartByte     equ 10000000b

; --------------------- Макросы -------------------------------


; макрос вызова процедуры теста
; параметры:
; testProc - адрес процедуры проверки памяти
; indicatorsValue - значение, выводимое на индикаторах, отображающее общий прогресс, 0 если не нужно
; отображать прогресс (для последнего теста)
; initializer - блок кода, содержащий выставление дополнительных параметров теста (обычно, содержимое A)
callTest                macro(testProc, indicatorsValue, initializer)
                        ld hl, TestReturnAddress
                        exx                                     ; переключаем регисты чтоб сохранить HL
                        initializer
                        jp testProc
TestReturnAddress:      jp nz, Exit
                        if indicatorsValue != 0
                            setIndicators(indicatorsValue)
                            delay(1)
                        endif

                        mend


; макрос задержки
; параметры:
; delayTime - время задержки в секундах (примерное)
delay                   macro(delayTime)
                        ld hl, DelayExit                        ; загружаем адрес команды, которая будет после jp Delay
                        exx                                     ; переключаем регисты чтоб сохранить HL
                        ld bc, delayTime * OuterCycleDelayConst ; BC - счетчик внешнего цикла для задержки
                        jp Delay
DelayExit:
                        mend


; макрос выхода из подпрограммы
return                  macro()
                        exx             ; переключаемся на альтернативный набор регистров
                        jp (hl)         ; регистр HL этого набора содержит адрес выхода, переходим к нему
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

                        delay(3)                        ; вызываем задержку

                        setIndicators(0)                ; выключаем все индикаторы

; выполняем тесты, в которых происходит побайтная запись и чтение:
                        callTest(ByteCheck, 00000001b, {
                            ld a, TestByteValue1
                        })
                        callTest(ByteCheck, 00000011b, {
                            ld a, TestByteValue2
                        })
                        callTest(ByteCheck, 00000111b, {
                            ld a, TestByteValue3
                        })
                        callTest(ByteCheck, 00001111b, {
                            ld a, TestByteValue4
                        })

; выполняем тесты, в которых память сначала заполняется, а затем побайтно проверяется
                        callTest(BlockCheck, 00011111b, {
                            ld a, TestByteValue1
                        })
                        callTest(BlockCheck, 00111111b, {
                            ld a, TestByteValue2
                        })
                        callTest(BlockCheck, 01111111b, {
                            ld a, TestByteValue3
                        })
                        callTest(BlockCheck, 11111111b, {
                            ld a, TestByteValue4
                        })

; тест со сдвигом байта
                        callTest(ShiftingByteCheck, 0, {})

; включаем по 1 светодиоду на обоих индикаторах в знак успешного завершения тестов
                        ld a, 00000001b
                        out (WriteIndicatorPort), a
                        ld a, 10000000b
                        out (ReadIndicatorPort), a

Exit:
                        halt                            ; конец программы


; --------------------- Подпрограммы -------------------------------


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

                        return()                        ; возврат


; подпрограмма проверки в режиме "записить всю память, затем считывать"
; регистр A должен содержать значение, используемое для записи и проверки
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

                        return()                        ; возврат


; подпрограмма побайтовой проверки со сдвигом
ShiftingByteCheck:
                        ld hl, RamStartAddress          ; начало RAM в HL
                        ld bc, RamSize                  ; размер RAM в BC
ShiftingByteOuter:      ld a, ShiftCheckStartByte
ShiftingByteInner:      ld (hl), a
                        cp (hl)
                        jr nz, ShiftError
                        rrca                            ; сдвигаем бит
                        cp ShiftCheckStartByte          ; и проверяем прошли ли мы полный круг
                        jr nz, ShiftingByteInner
                        inc hl
                        dec bc
                        ld a, b
                        or c
                        jr nz, ShiftingByteOuter

                        return()                        ; возврат


; Обработчик ошибок для проверок памяти со сдвигом бита
; в HL должен содержаться адрес возврата
ShiftError:
                        out (WriteIndicatorPort), a ; выводим значение, которое мы записали
                        ld a, (hl)                  ; считываем ошибочное значение
                        out (ReadIndicatorPort), a  ; выводим значение, которое мы считали

                        return()                        ; возврат

; Обработчик ошибок
; в HL должен содержаться адрес возврата
Error:
                        out (WriteIndicatorPort), a ; выводим значение, которое мы записали
                        dec hl                      ; hl было увеличено на 1 командой cpi, уменьшаем
                        ld a, (hl)                  ; считываем ошибочное значение
                        out (ReadIndicatorPort), a  ; выводим значение, которое мы считали

                        return()                        ; возврат


; Подпрограмма задержки
; в HL' должен содержаться адрес возврата для подпрограммы
Delay:
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

                        return()                        ; возврат
End:

; при трансляции сохранить бинарный дамп с нулевого адреса размером 1К в указанный файл
output_bin      BinDumpFileName, RomStartAddress, End
