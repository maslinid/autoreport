script_name('Network Optimizer')
script_version('1.0')
script_author('Papa_Neurowise')

require 'lib.moonloader'
local memory = require 'memory'
local ffi = require 'ffi'

-- Более мягкие константы
local NETWORK_UPDATE_DELAY = 1000 -- Увеличиваем интервал обновления
local PACKET_PRIORITY = 1 -- Средний приоритет (было 2)
local MIN_BUFFER_SIZE = 8 -- Минимальный размер буфера (байт)

ffi.cdef[[
    int SetPriorityClass(void* hProcess, unsigned long dwPriorityClass);
    void* GetCurrentProcess();
]]

-- Оптимизированная функция для RakNet
function optimizeRakNet()
    local rakClient = memory.getint32(sampGetBase() + 0x26E8C4)
    if rakClient ~= 0 then
        -- Базовые настройки
        memory.setint8(rakClient + 0x7A, PACKET_PRIORITY, true) -- Приоритет пакетов
        memory.setint8(rakClient + 0x7B, 0, true) -- Оставляем алгоритм Нейгла
        memory.setint8(rakClient + 0x7C, MIN_BUFFER_SIZE, true) -- Буфер
    end
end

-- Мягкая оптимизация SAMP
function optimizeSAMP()
    local sampBase = sampGetBase()
    if sampBase ~= 0 then
        -- Базовая оптимизация без форсирования
        memory.setint8(sampBase + 0x119, 1, true)
    end
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    -- Устанавливаем нормальный приоритет
    ffi.C.SetPriorityClass(ffi.C.GetCurrentProcess(), 0x00000020) -- NORMAL_PRIORITY_CLASS
    
    -- Основной цикл
    while true do
        wait(NETWORK_UPDATE_DELAY)
        optimizeRakNet()
        optimizeSAMP()
    end
end