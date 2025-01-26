script_name('AutoReport')
script_version_number = '2.2'
script_version('2.2')
script_author('Papa_Neurowise')

require 'lib.moonloader'
local sampev = require 'lib.samp.events'
local vkeys = require 'vkeys'
local memory = require 'memory'
local raknet = require 'lib.samp.raknet'
local hook = require 'lib.samp.events.core'
local dlstatus = require('moonloader').download_status
local renderText = renderCreateFont('Arial', 8, FCR_BOLD + FCR_BORDER)
local renderSmallText = renderCreateFont('Arial', 6, FCR_BORDER)
local screenX, screenY = getScreenResolution()
local ffi = require 'ffi'
local imgui = require 'imgui'
local inicfg = require 'inicfg'
local encoding = require 'encoding'
encoding.default = 'CP1251'

-- Сохраняем оригинальную функцию
local originalSampAddChatMessage = sampAddChatMessage

-- Исправленная функция-обёртка
function sampAddChatMessage(text, color)
    if not text then return end
    text = tostring(text)
    -- Убираем лишние цветовые коды в начале строки
    text = text:gsub('^{%x+}%s*', '')
    return originalSampAddChatMessage('[AutoReport] ' .. text, color)
end

local memory_flag = 0x000000 -- Адрес в памяти для связи с CLEO
local enable_autoupdate = true
local update_url = 'https://raw.githubusercontent.com/maslinid/autoreport/refs/heads/main/update.json?nocache=' .. os.time()
local script_path = thisScript().path
local script_dir = getWorkingDirectory() .. '\\moonloader\\'
local update_available = false
local new_version = nil
local cooldown_slider = imgui.ImInt(0)
local disable_after_report = imgui.ImBool(false)
-- Добавьте после других глобальных переменных
local disable_after_recon_switch = imgui.ImBool(false)
local mainIni = inicfg.load({
    main = {
        toggleKey = 0xC2,
        report_cooldown = 0,
        disable_after_report = false,
        disable_after_recon_switch = false,
        -- Добавляем все остальные настройки
        window_position_x = 0,
        window_position_y = 0
    }
}, 'autoreport.ini')

-- И загружаем значение
disable_after_recon_switch.v = mainIni.main.disable_after_recon_switch

-- И загрузите значение при старте
report_cooldown = mainIni.main.report_cooldown

-- Глобальные переменные
local active = false
local used_keys_file = getGameDirectory() .. '\\moonloader\\config\\autoreport_used_keys.dat'

-- Защищенные переменные (обфусцированные)
local _0x1 = {
    animation_offset = 0,
    rainbow_offset = 0,
    icons = {'^', '>', 'v', '<'},
    icon_index = 1,
    send_second = false,
    second_time = 0,
    is_activated = false,
    last_send_time = 0,
    last_report_time = 0,
    original_hash = 0
}

-- Константы оптимизации
local SEND_DELAY = 2 -- Уменьшаем задержку между отправками
local MIN_REPORT_DELAY = 50 -- Уменьшаем минимальную задержку между репортами
local DOUBLE_SEND = true
local TRIPLE_SEND = true
local FORCE_PACKET = true
local AGGRESSIVE_MODE = true -- Новый режим агрессивной отправки
local PACKET_PRIORITY = 2 -- Повышенный приоритет пакетов

-- Объявления FFI
ffi.cdef[[
    int SendMessage(void* hWnd, unsigned int Msg, int wParam, int lParam);
    int GetVolumeInformationA(
        const char* lpRootPathName,
        char* lpVolumeNameBuffer,
        unsigned long nVolumeNameSize,
        unsigned long* lpVolumeSerialNumber,
        unsigned long* lpMaximumComponentLength,
        unsigned long* lpFileSystemFlags,
        char* lpFileSystemNameBuffer,
        unsigned long nFileSystemNameSize
    );
    bool IsDebuggerPresent();
    void* GetModuleHandleA(const char* lpModuleName);
]]

function checkUpdates(manual)
    if not enable_autoupdate then return end
    
    if manual then
        sampAddChatMessage('[AutoReport] {ffffff}Начинаю проверку обновлений...', 0x7ef542)
    end

    local json_path = script_dir .. 'update.json'
    if doesFileExist(json_path) then
        os.remove(json_path)
    end

    downloadUrlToFile(update_url, json_path, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            if manual then
                sampAddChatMessage('[AutoReport] {ffffff}Проверяю наличие обновлений...', 0x7ef542)
            end
            
            local file = io.open(json_path, 'r')
            if file then
                local content = file:read('*a')
                file:close()
                
                local ok, info = pcall(decodeJson, content)
                if ok and info and info.latest then
                    local current_version = tonumber(script_version_number)
                    local latest_version = tonumber(info.latest)
                    
                    if current_version and latest_version then
                        if latest_version > current_version then
                            update_available = true
                            new_version = info.latest
                            if manual then
                                sampAddChatMessage('г==========================================', 0x7ef542)
                                sampAddChatMessage('¦ {ffffff}Доступно обновление!', 0x7ef542)
                                sampAddChatMessage('¦ {ffffff}Текущая версия: {ff0000}' .. script_version_number, 0x7ef542)
                                sampAddChatMessage('¦ {ffffff}Новая версия: {00ff00}' .. new_version, 0x7ef542)
                                if info.changelog then
                                    sampAddChatMessage('¦ {ffffff}Список изменений:', 0x7ef542)
                                    local changelog = decodeUTF8(info.changelog)
                                    for line in changelog:gmatch("[^\n]+") do
                                        sampAddChatMessage('¦ {ffffff}' .. line, 0x7ef542)
                                    end
                                end
                                sampAddChatMessage('¦ {ffffff}Начинаю обновление...', 0x7ef542)
                                sampAddChatMessage('L==========================================', 0x7ef542)
                                downloadUpdates(info)
                            else
                                sampAddChatMessage('[AutoReport] {ffffff}Доступно обновление до версии ' .. new_version, 0x7ef542)
                                sampAddChatMessage('[AutoReport] {ffffff}Используйте {00ccff}/arupdate{ffffff} для обновления', 0x7ef542)
                            end
                        else
                            update_available = false
                            if manual then
                                sampAddChatMessage('г==========================================', 0x7ef542)
                                sampAddChatMessage('¦ {ffffff}У вас установлена актуальная версия', 0x7ef542)
                                sampAddChatMessage('¦ {ffffff}Текущая версия: {00ff00}' .. script_version_number, 0x7ef542)
                                sampAddChatMessage('L==========================================', 0x7ef542)
                            end
                        end
                    else
                        if manual then
                            sampAddChatMessage('[AutoReport] {ffffff}Ошибка сравнения версий:', 0x7ef542)
                            sampAddChatMessage('[AutoReport] {ffffff}Текущая версия: ' .. tostring(script_version_number), 0x7ef542)
                            sampAddChatMessage('[AutoReport] {ffffff}Версия в обновлении: ' .. tostring(info.latest), 0x7ef542)
                        end
                    end
                else
                    if manual then
                        sampAddChatMessage('[AutoReport] {ffffff}Ошибка получения данных обновления', 0x7ef542)
                    end
                end
            else
                if manual then
                    sampAddChatMessage('[AutoReport] {ffffff}Ошибка чтения файла обновления', 0x7ef542)
                end
            end
            
            if doesFileExist(json_path) then
                os.remove(json_path)
            end
        end
    end)
end

function downloadUpdates(info)
    local function convertToCP1251(content)
        local encoding = require 'encoding'
        encoding.default = 'CP1251'
        return encoding.UTF8:decode(content)
    end

    local function processFile(path, content)
        local f = io.open(path, 'w+b') -- Открываем в бинарном режиме
        if f then
            local converted_content = convertToCP1251(content)
            f:write(converted_content)
            f:close()
            return true
        end
        return false
    end

    local download_queue = {}
    
    if info.updateurl then
        table.insert(download_queue, {url = info.updateurl, path = script_path, name = "Основной скрипт"})
    end
    
    if info.additional_files then
        for filename, url in pairs(info.additional_files) do
            table.insert(download_queue, {url = url, path = script_dir .. filename, name = filename})
        end
    end
    
    local function processQueue()
        if #download_queue == 0 then
            sampAddChatMessage('Все файлы обновлены! Перезагружаю скрипт...', 0x7ef542)
            lua_thread.create(function()
                wait(1000)
                thisScript():reload()
            end)
            return
        end
        
        local item = table.remove(download_queue, 1)
        sampAddChatMessage('Загрузка: ' .. item.name, 0x7ef542)
        
        -- Скачиваем во временный файл
        local temp_path = item.path .. '.tmp'
        downloadUrlToFile(item.url, temp_path, function(id, status, p1, p2)
            if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                -- Читаем содержимое временного файла
                local f = io.open(temp_path, 'r')
                if f then
                    local content = f:read('*all')
                    f:close()
                    os.remove(temp_path)
                    
                    -- Удаляем старый файл
                    if doesFileExist(item.path) then
                        os.remove(item.path)
                    end
                    
                    -- Сохраняем с правильной кодировкой
                    if processFile(item.path, content) then
                        sampAddChatMessage('Успешно загружен: ' .. item.name, 0x7ef542)
                        wait(500)
                        processQueue()
                    else
                        sampAddChatMessage('Ошибка сохранения: ' .. item.name, 0x7ef542)
                        processQueue()
                    end
                else
                    sampAddChatMessage('Ошибка чтения: ' .. item.name, 0x7ef542)
                    processQueue()
                end
            end
        end)
    end
    
    sampAddChatMessage('г==========================================', 0x7ef542)
    sampAddChatMessage('¦ Начинаю процесс обновления', 0x7ef542)
    sampAddChatMessage('¦ Всего файлов к загрузке: {00ff00}' .. #download_queue, 0x7ef542)
    sampAddChatMessage('L==========================================', 0x7ef542)
    
    lua_thread.create(function()
        wait(100)
        processQueue()
    end)
end

function decodeUTF8(str)
    if not str then return "" end
    return encoding.UTF8:decode(str)
end

-- Загружаем значения при старте
function loadSettings()
    if mainIni then
        disable_after_report.v = mainIni.main.disable_after_report
        disable_after_recon_switch.v = mainIni.main.disable_after_recon_switch
        cooldown_slider.v = mainIni.main.report_cooldown
        report_cooldown = mainIni.main.report_cooldown
    end
end

-- Добавляем функцию декодирования UTF-8
function decodeUTF8(str)
    if not str then return "" end
    return encoding.UTF8:decode(str)
end

function downloadUpdates(info)
    -- Создаем очередь загрузки
    local download_queue = {}
    
    -- Добавляем основной скрипт
    table.insert(download_queue, {url = info.updateurl, path = script_path, name = "Основной скрипт"})
    
    -- Добавляем дополнительные файлы
    if info.additional_files then
        for filename, url in pairs(info.additional_files) do
            table.insert(download_queue, {url = url, path = script_dir .. filename, name = filename})
        end
    end
    
    -- Создаем функцию для последовательной загрузки
    local function processQueue()
        if #download_queue == 0 then
            sampAddChatMessage('[AutoReport] {ffffff}Все файлы обновлены! Перезагружаю скрипты...', 0x7ef542)
            lua_thread.create(function()
                wait(1000)
                thisScript():reload()
            end)
            return
        end
        
        local item = table.remove(download_queue, 1)
        sampAddChatMessage('[AutoReport] {ffffff}Загрузка: ' .. item.name, 0x7ef542)
        
        -- Удаляем старый файл перед загрузкой
        if doesFileExist(item.path) then
            os.remove(item.path)
            wait(100) -- Ждем удаления файла
        end
        
        -- Создаем папку, если её нет
        local folder = item.path:match("(.*\\)")
        if folder and not doesDirectoryExist(folder) then
            createDirectory(folder)
        end
        
        -- Пытаемся загрузить файл с повторами при ошибке
        local attempts = 0
        local max_attempts = 3
        
        local function tryDownload()
            attempts = attempts + 1
            downloadUrlToFile(item.url, item.path, function(id, status, p1, p2)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    if doesFileExist(item.path) then
                        sampAddChatMessage('[AutoReport] {ffffff}Успешно загружен: ' .. item.name, 0x7ef542)
                        wait(500) -- Ждем между загрузками
                        processQueue()
                    else
                        if attempts < max_attempts then
                            sampAddChatMessage('[AutoReport] {ffffff}Повторная попытка загрузки: ' .. item.name, 0x7ef542)
                            wait(1000)
                            tryDownload()
                        else
                            sampAddChatMessage('[AutoReport] {ff0000}Ошибка загрузки: ' .. item.name, 0x7ef542)
                            processQueue()
                        end
                    end
                end
            end)
        end
        
        lua_thread.create(function()
            wait(100) -- Небольшая задержка перед началом загрузки
            tryDownload()
        end)
    end
    
    -- Начинаем загрузку
    sampAddChatMessage('г==========================================', 0x7ef542)
    sampAddChatMessage('¦ {ffffff}Начинаю процесс обновления', 0x7ef542)
    sampAddChatMessage('¦ {ffffff}Всего файлов к загрузке: {00ff00}' .. #download_queue, 0x7ef542)
    sampAddChatMessage('L==========================================', 0x7ef542)
    
    lua_thread.create(function()
        wait(100)
        processQueue()
    end)
end

-- Функции шифрования для хранения использованных ключей
local function encryptString(str)
    local result = ""
    local key = os.time() % 255
    for i = 1, #str do
        result = result .. string.char(bit.bxor(string.byte(str, i), key))
    end
    return result .. string.char(key)
end

local function decryptString(str)
    if #str < 2 then return "" end
    local key = string.byte(str, #str)
    local result = ""
    for i = 1, #str - 1 do
        result = result .. string.char(bit.bxor(string.byte(str, i), key))
    end
    return result
end

-- Функции для работы с использованными ключами
local function isKeyUsed(key)
    if not doesFileExist(used_keys_file) then
        return false
    end
    
    local f = io.open(used_keys_file, 'rb')
    if not f then return false end
    
    local content = f:read('*all')
    f:close()
    
    if #content == 0 then return false end
    
    local decrypted = decryptString(content)
    for line in decrypted:gmatch("[^\r\n]+") do
        if line == key then
            return true
        end
    end
    
    return false
end

local function markKeyAsUsed(key)
    -- Проверяем валидность ключа перед записью
    if not key:match("^%d+:[%x]+:[%x]+$") then
        return false
    end
    
    local content = ""
    if doesFileExist(used_keys_file) then
        local f = io.open(used_keys_file, 'rb')
        if f then
            content = f:read('*all')
            f:close()
            if #content > 0 then
                content = decryptString(content)
            end
        end
    end
    
    content = content .. key .. "\n"
    local encrypted = encryptString(content)
    
    local f = io.open(used_keys_file, 'wb')
    if f then
        f:write(encrypted)
        f:close()
        return true
    end
    return false
end

-- Защищенные настройки активации
local function getProtectedSalt()
    local base = string.char(80,97,112,97,78,101,117,114,111,50,48,50,52) -- "PapaNeuro2024"
    local dynamic_salt = os.time() % 1000
    return base .. tostring(dynamic_salt)
end

-- Настройки конфигурации
local directIni = 'moonloader\\config\\autoreport.ini'
local mainIni = inicfg.load({
    main = {
        toggleKey = 0xC2
    }
}, directIni)
inicfg.save(mainIni, directIni)

-- Переменные для ImGui
local imgui_window = {
    v = imgui.ImBool(false),
    setting_key = imgui.ImBool(false)
}

-- Защищенные функции проверки
local function encryptHWID(hwid, salt)
    local result = ""
    local complex_key = {}
    
    for i = 1, #salt do
        complex_key[i] = string.byte(salt, i)
    end
    
    for i = 1, #hwid do
        local byte = string.byte(hwid, i)
        local salt_byte = complex_key[(i % #complex_key) + 1]
        local encrypted = (byte * salt_byte + 73) % 256
        encrypted = bit.bxor(encrypted, (i * 31) % 256)
        result = result .. string.format("%02X", encrypted)
    end
    
    return result
end

local function calculateChecksum(data)
    local checksum = 0
    local multiplier = 1
    
    for i = 1, #data do
        local byte = string.byte(data, i)
        checksum = (checksum + byte * multiplier) % 65536
        multiplier = (multiplier * 31) % 65536
    end
    
    return string.format("%04X", checksum)
end

-- Функция получения HWID с защитой от эмуляции
local function getSecureHWID()
    local serial = ffi.new("unsigned long[1]")
    local result = ffi.C.GetVolumeInformationA("C:\\", nil, 0, serial, nil, nil, nil, 0)
    
    if result == 0 then
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка получения HWID!', 0x7ef542)
        return nil
    end
    
    local hwid = string.format("%08X", serial[0])
    -- Проверка формата HWID
    if not hwid:match("^%x%x%x%x%x%x%x%x$") then
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка: некорректный формат HWID', 0x7ef542)
        return nil
    end
    
    return hwid
end

-- Проверка на отладчик
local function checkDebugger()
    if ffi.C.IsDebuggerPresent() then
        thisScript():unload()
        return true
    end
    return false
end

-- Проверка целостности кода
local function verifyCodeIntegrity()
    local file = io.open(thisScript().path, "rb")
    if not file then return false end
    local content = file:read("*all")
    file:close()
    
    local hash = 0
    for i = 1, #content do
        hash = (hash * 33 + string.byte(content, i)) % 0x7FFFFFFF
    end
    
    return hash == _0x1.original_hash
end

-- Улучшенная система проверки активации
local function isKeyExpired(expiration_time)
    if checkDebugger() then return true end
    
    local current_time = os.time()
    local exp_time = tonumber(expiration_time)
    return current_time >= exp_time
end

local function isValidActivationKey(key)
    if not key:match("^%d+:[%x]+:[%x]+$") then
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка: неверный формат ключа', 0x7ef542)
        return false
    end
    
    local expiration_time, hwid_hash, provided_checksum = key:match("(%d+):([%x]+):([%x]+)")
    if not expiration_time or not hwid_hash or not provided_checksum then
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка: не удалось разобрать ключ', 0x7ef542)
        return false
    end
    
    local hwid = getSecureHWID()
    if not hwid then 
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка: не удалось получить HWID', 0x7ef542)
        return false 
    end
    
    local salt = getProtectedSalt()
    local expected_hash = encryptHWID(hwid, salt)
    
    if tonumber(expiration_time) < os.time() then
        sampAddChatMessage('[AutoReport] {ffffff}Обнаружен ключ деактивации', 0x7ef542)
        
        local key_without_checksum = expiration_time .. ":" .. hwid_hash .. ":"
        local calculated_checksum = calculateChecksum(key_without_checksum)
        
        if hwid_hash == expected_hash and provided_checksum == calculated_checksum then
            sampAddChatMessage('[AutoReport] {ffffff}Скрипт успешно деактивирован', 0x7ef542)
            _0x1.is_activated = false
            active = false
            
            local license_path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
            if doesFileExist(license_path) then
                os.remove(license_path)
            end
            
            return true
        end
        return false
    end
    
    local key_without_checksum = expiration_time .. ":" .. hwid_hash .. ":"
    local calculated_checksum = calculateChecksum(key_without_checksum)
    
    return hwid_hash == expected_hash and provided_checksum == calculated_checksum
end

-- Функция для форматирования оставшегося времени
local function formatTimeLeft(expiration_time)
    local time_left = tonumber(expiration_time) - os.time()
    if time_left <= 0 then return "Истек" end
    
    local days = math.floor(time_left / (24 * 60 * 60))
    local hours = math.floor((time_left % (24 * 60 * 60)) / (60 * 60))
    local minutes = math.floor((time_left % (60 * 60)) / 60)
    
    if days > 0 then
        return string.format("%d дн. %d ч.", days, hours)
    elseif hours > 0 then
        return string.format("%d ч. %d мин.", hours, minutes)
    else
        return string.format("%d мин.", minutes)
    end
end

-- Оптимизированная функция отправки команды
local function sendOtCommand()
    local current_time = os.clock() * 1000
    if current_time - _0x1.last_send_time >= SEND_DELAY then
        -- Форсируем обновление сетевого стека
        raknetEmulPacketReceiver()
        
        -- Первая отправка
        sampSendChat('/ot')
        _0x1.last_send_time = current_time
        
        -- Вторая отправка с минимальной задержкой
        lua_thread.create(function()
            wait(1)
            sampSendChat('/ot')
        end)
        
        -- Форсируем отправку пакетов
        if FORCE_PACKET then
            memory.setint8(sampGetBase() + 0x119, 1, true)
            memory.setuint8(getModuleHandle('samp.dll') + 0x11A, 1, true)
        end
    end
end

-- Функция проверки активации с защитой
function checkActivation()
    if checkDebugger() then return false end
    
    local path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
    if not doesFileExist(path) then return false end
    
    local f = io.open(path, 'r')
    if not f then return false end
    
    local content = f:read('*all')
    f:close()
    
    if not content or #content < 20 then return false end
    
    -- Проверяем валидность ключа
    if not isValidActivationKey(content) then
        -- Если ключ невалиден, удаляем файл лицензии
        os.remove(path)
        return false
    end
    
    -- Проверяем срок действия
    local expiration_time = content:match("(%d+):")
    if expiration_time and tonumber(expiration_time) < os.time() then
        os.remove(path)
        return false
    end
    
    return true
end

-- Команды активации
function cmd_activate(arg)
    if checkDebugger() then return end
    
    if not arg or arg == '' then
        if _0x1.is_activated then
            local path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
            local f = io.open(path, 'r')
            if f then
                local content = f:read('*all')
                f:close()
                if content and content:match("(%d+):") then
                    local expiration_time = content:match("(%d+):")
                    local time_left = formatTimeLeft(expiration_time)
                    sampAddChatMessage('[AutoReport] {ffffff}Текущий статус:', 0x7ef542)
                    sampAddChatMessage('г==========================================', 0x7ef542)
                    sampAddChatMessage('¦ {00ff00}Скрипт активирован!', 0x7ef542)
                    sampAddChatMessage('¦ {ffffff}Осталось времени: {00ff00}' .. time_left, 0x7ef542)
                    sampAddChatMessage('¦ {ffffff}Успешной ловли от {ff0000}Папы Нейровайс {ffffff}¦', 0x7ef542)
                    sampAddChatMessage('L==========================================', 0x7ef542)
                end
            end
        else
            sampAddChatMessage('[AutoReport] {ffffff}Использование: /activate [ключ]', 0x7ef542)
        end
        return
    end
    
    -- Сначала проверяем валидность ключа
    if not isValidActivationKey(arg) then
        sampAddChatMessage('[AutoReport] {ffffff}Неверный ключ активации!', 0x7ef542)
        return
    end
    
    -- Проверяем на деактивацию
    local expiration_time = arg:match("(%d+):")
    if expiration_time and tonumber(expiration_time) < os.time() then
        _0x1.is_activated = false
        active = false
        
        -- Удаляем файл лицензии
        local path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
        if doesFileExist(path) then
            os.remove(path)
        end
        return
    end
    
    -- Затем проверяем, не использован ли ключ
    if isKeyUsed(arg) then
        sampAddChatMessage('[AutoReport] {ffffff}Этот ключ уже был использован!', 0x7ef542)
        return
    end
    
    -- Если все проверки пройдены, активируем ключ
    local path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
    local f = io.open(path, 'w')
    if f then
        f:write(arg)
        f:close()
        markKeyAsUsed(arg) -- Помечаем ключ как использованный только после успешной активации
        
        local expiration_time = arg:match("(%d+):")
        if expiration_time and tonumber(expiration_time) < os.time() then
            sampAddChatMessage('[AutoReport] {ffffff}Внимание!', 0x7ef542)
            sampAddChatMessage('г==========================================', 0x7ef542)
            sampAddChatMessage('¦ {ff0000}Подписка деактивирована!', 0x7ef542)
            sampAddChatMessage('¦ {ffffff}Для продолжения работы требуется новый ключ', 0x7ef542)
            sampAddChatMessage('L==========================================', 0x7ef542)
            _0x1.is_activated = false
        else
            sampAddChatMessage('[AutoReport] {ffffff}Успешно!', 0x7ef542)
            sampAddChatMessage('г==========================================', 0x7ef542)
            sampAddChatMessage('¦ {00ff00}Скрипт успешно активирован!', 0x7ef542)
            sampAddChatMessage('¦ {ffffff}Успешной ловли от {ff0000}Папы Нейровайс {ffffff}¦', 0x7ef542)
            sampAddChatMessage('L==========================================', 0x7ef542)
            _0x1.is_activated = true
        end
    end
end

function getSecureHWID()
    local serial = ffi.new("unsigned long[1]")
    local result = ffi.C.GetVolumeInformationA("C:\\", nil, 0, serial, nil, nil, nil, 0)
    
    if result == 0 then
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка получения HWID!', 0x7ef542)
        return nil
    end
    
    local hwid = string.format("%08X", serial[0])
    -- Проверка формата HWID
    if not hwid:match("^%x%x%x%x%x%x%x%x$") then
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка: некорректный формат HWID', 0x7ef542)
        return nil
    end
    
    return hwid
end

function cmd_ak(arg)
    if checkDebugger() then return end
    
    if _0x1.is_activated then
        sampAddChatMessage('[AutoReport] {ffffff}Скрипт уже активирован!', 0x7ef542)
        return
    end
    
    local hwid = getSecureHWID()
    if not hwid then
        sampAddChatMessage('[AutoReport] {ffffff}Ошибка получения HWID!', 0x7ef542)
        return
    end
    
    sampAddChatMessage('г==========================================', 0x7ef542)
    sampAddChatMessage('¦ {ffffff}Ваш код для активации:', 0x7ef542)
    sampAddChatMessage('¦ {ff0000}' .. hwid, 0x7ef542)
    sampAddChatMessage('¦ {ffffff}Отправьте этот код автору:', 0x7ef542)
    sampAddChatMessage('¦ {00ccff}Papa_Neurowise {ffffff}[Администратор Yava]', 0x7ef542)
    sampAddChatMessage('L==========================================', 0x7ef542)
end

-- Улучшенная функция обработки сетевого стека
function raknetEmulPacketReceiver()
    local rakClient = memory.getint32(sampGetBase() + 0x26E8C4)
    if rakClient ~= 0 then
        -- Максимальный приоритет и минимальные задержки
        memory.setint8(rakClient + 0x7A, 2, true) -- Повышенный приоритет
        memory.setint8(rakClient + 0x8C, 1, true)
        memory.setint8(rakClient + 0x7B, 1, true)
        memory.setint8(rakClient + 0x7C, 0, true)
        -- Дополнительные оптимизации
        memory.setint32(rakClient + 0x90, 0, true)
        memory.setint8(rakClient + 0x7D, 1, true) -- Форсированная отправка
        memory.setint8(rakClient + 0x7E, 0, true) -- Минимальная буферизация
    end
end

-- Функция обработки приоритета пакетов
function processPacketPriority()
    repeat wait(0)
        local sampPtr = getModuleHandle('samp.dll')
        if sampPtr then
            memory.setuint8(sampPtr + 0x119, 1, true)
            memory.setuint8(sampPtr + 0x11A, 1, true)
            memory.setuint8(sampPtr + 0x11B, 1, true)
            memory.setuint8(sampPtr + 0x11C, 1, true)
            break
        end
    until false
end

-- Перемещаем функцию updateCleoState за пределы main
function updateCleoState()
    if active and _0x1.is_activated then
        memory.setint8(memory_flag, 1, true)
    else
        memory.setint8(memory_flag, 0, true)
    end
end

function imgui.OnDrawFrame()
    if imgui_window.v.v then
        local sw, sh = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(350, 400), imgui.Cond.Always) -- Фиксированный размер
        
        -- Стилизация окна
        imgui.PushStyleVar(imgui.StyleVar.WindowRounding, 10)
        imgui.PushStyleVar(imgui.StyleVar.FrameRounding, 6)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.07, 0.07, 0.09, 0.95))
        imgui.PushStyleColor(imgui.Col.TitleBg, imgui.ImVec4(0.09, 0.09, 0.15, 0.95))
        imgui.PushStyleColor(imgui.Col.TitleBgActive, imgui.ImVec4(0.09, 0.09, 0.15, 0.95))
        
        imgui.Begin(u8'AutoReport | Настройки', imgui_window.v, imgui.WindowFlags.NoResize)
        
        -- Заголовок с версией
        imgui.CenterText(u8'AutoReport v' .. script_version_number)
        imgui.Spacing()
        
        -- Информация о подписке в рамке
        imgui.BeginChild('##subscription_info', imgui.ImVec2(-1, 80), true)
        local path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
        if doesFileExist(path) then
            local f = io.open(path, 'r')
            if f then
                local content = f:read('*all')
                f:close()
                if content and content:match("(%d+):") then
                    local expiration_time = content:match("(%d+):")
                    local time_left = formatTimeLeft(expiration_time)
                    imgui.CenterTextColored(imgui.ImVec4(0, 1, 0, 1), u8'ПОДПИСКА АКТИВНА')
                    imgui.CenterText(u8'Осталось времени: ' .. u8(time_left))
                end
            end
        else
            imgui.CenterTextColored(imgui.ImVec4(1, 0, 0, 1), u8'ПОДПИСКА НЕАКТИВНА')
        end
        imgui.EndChild()
        
        imgui.Spacing()
        
        -- HWID в компактной рамке
        local hwid = getSecureHWID()
        if hwid then
            imgui.BeginChild('##hwid_info', imgui.ImVec2(-1, 50), true)
            imgui.CenterText(u8'Ваш HWID:')
            imgui.CenterTextColored(imgui.ImVec4(1, 0.4, 0.4, 1), hwid)
            imgui.EndChild()
        end
        
        imgui.Spacing()
        
        -- Настройки в отдельной рамке
        imgui.BeginChild('##settings', imgui.ImVec2(-1, 160), true)
        
        -- Клавиша включения/выключения
        imgui.Text(u8'Клавиша включения/выключения:')
        if imgui_window.setting_key.v then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.8, 0.3, 1.0))
            if imgui.Button(u8'Нажмите любую клавишу...', imgui.ImVec2(-1, 25)) then
                imgui_window.setting_key.v = false
            end
            imgui.PopStyleColor()
            
            for i = 0, 255 do
                if isKeyDown(i) then
                    mainIni.main.toggleKey = i
                    inicfg.save(mainIni, directIni)
                    imgui_window.setting_key.v = false
                    break
                end
            end
        else
            if imgui.Button(string.format(u8'%s [%s]', u8'Изменить', vkeys.id_to_name(mainIni.main.toggleKey)), imgui.ImVec2(-1, 25)) then
                imgui_window.setting_key.v = true
            end
        end
        
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        
		-- настройки рекона
         if imgui.Checkbox(u8'Выключать автоловлю в реконе', disable_after_report) then
            mainIni.main.disable_after_report = disable_after_report.v
            inicfg.save(mainIni, 'autoreport.ini')
        end
        
        if disable_after_report.v then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 15)
            if imgui.Checkbox(u8'Выключать при переключении между игроками', disable_after_recon_switch) then
                mainIni.main.disable_after_recon_switch = disable_after_recon_switch.v
                inicfg.save(mainIni, 'autoreport.ini')
            end
        end
        imgui.EndChild()
        
        imgui.Spacing()
        
        -- Кнопка закрытия внизу
        if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 30)) then
            imgui_window.v.v = false
        end
        
        imgui.End()
        
        -- Восстанавливаем стили
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(3)
    end
end

-- Добавьте эти вспомогательные функции
function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX(width / 2 - calc.x / 2)
    imgui.Text(text)
end

function imgui.CenterTextColored(color, text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX(width / 2 - calc.x / 2)
    imgui.TextColored(color, text)
end
-- Главная функция
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    -- Загружаем настройки сразу после проверки SAMP
    loadSettings()
    
    -- Проверка на отладчик при запуске
    if checkDebugger() then return end
    
    -- Проверяем активацию при запуске
    _0x1.is_activated = checkActivation()
    
    -- Сохраняем хеш кода для проверки целостности
    local file = io.open(thisScript().path, "rb")
    if file then
        local content = file:read("*all")
        file:close()
        local hash = 0
        for i = 1, #content do
            hash = (hash * 33 + string.byte(content, i)) % 0x7FFFFFFF
        end
        _0x1.original_hash = hash
    end
    
    -- Инициализация ImGui
    imgui.Process = false
    if not imgui.Process then
        imgui.Process = true
        wait(500)
        imgui.Process = false
    end
    
    -- Регистрация команд
    sampRegisterChatCommand('autoreport', function()
        imgui_window.v.v = not imgui_window.v.v
        imgui.Process = imgui_window.v.v
    end)
    sampRegisterChatCommand('ak', cmd_ak)
    sampRegisterChatCommand('activate', cmd_activate)
    sampRegisterChatCommand('arupdate', function()
        checkUpdates(true)
    end)
	-- Регистрация команд
    sampRegisterChatCommand('arcooldown', function(arg)
        if arg and arg:match('^%d+$') then
            local value = tonumber(arg)
            if value >= 0 and value <= 60 then
                report_cooldown = value
                cooldown_slider.v = value
                mainIni.main.report_cooldown = value
                inicfg.save(mainIni, directIni)
                sampAddChatMessage('[AutoReport] {ffffff}Установлена задержка после репорта: {00ff00}' .. value .. ' сек.', 0x7ef542)
            else
                sampAddChatMessage('[AutoReport] {ffffff}Значение должно быть от 0 до 60 секунд', 0x7ef542)
            end
        else
            sampAddChatMessage('[AutoReport] {ffffff}Использование: /arcooldown [0-60]', 0x7ef542)
            sampAddChatMessage('[AutoReport] {ffffff}Текущая задержка: {00ff00}' .. report_cooldown .. ' сек.', 0x7ef542)
        end
    end)
    
    -- Проверяем обновления при запуске
    checkUpdates(false)
    wait(1000)
    
    -- Исправленные сообщения при загрузке
    if not update_available then
        sampAddChatMessage('Скрипт загружен. Версия: {00cc00}' .. script_version_number, 0x7ef542)
    end
    
    if not _0x1.is_activated then
        sampAddChatMessage('Используйте {00ccff}/ak{ffffff} для получения ключа', 0x7ef542)
    end
    
    processPacketPriority()
    sampAddChatMessage('Автор: {ff0000}Papa_Neurowise {ffffff}[{00ccff}Администратор Yava{ffffff}]', 0x7ef542)
    
    -- Проверяем обновления каждый час
    lua_thread.create(function()
        while true do
            wait(3600000) -- 1 час
            checkUpdates(false)  -- Добавлен параметр false
        end
    end)
    
    while true do
        wait(0)
        updateCleoState()
        imgui.Process = imgui_window.v.v
        
        -- Периодическая проверка целостности
        if os.clock() % 10 < 0.1 then
            if not verifyCodeIntegrity() or checkDebugger() then
                thisScript():unload()
                break
            end
        end
        
        -- Обработка клавиши только если скрипт активирован
        if _0x1.is_activated then
            if isKeyJustPressed(mainIni.main.toggleKey) and not isSampfuncsConsoleActive() and not sampIsChatInputActive() and not sampIsDialogActive() and not isPauseMenuActive() then
                active = not active
                printString('AutoReport: '..(active and '~g~ON' or '~r~OFF'), 5000, 6)
            end
            
            -- Анимация и рендер только если скрипт активирован
            _0x1.animation_offset = _0x1.animation_offset + 0.1
            _0x1.rainbow_offset = _0x1.rainbow_offset + 0.05
            if _0x1.animation_offset > 5 then _0x1.animation_offset = 0 end
            if _0x1.rainbow_offset > 5 then _0x1.rainbow_offset = 0 end
            
            local rainbow_r = math.floor(math.sin(_0x1.rainbow_offset) * 127 + 128)
            local rainbow_g = math.floor(math.sin(_0x1.rainbow_offset + 2) * 127 + 128)
            local rainbow_b = math.floor(math.sin(_0x1.rainbow_offset + 4) * 127 + 128)
            local rainbow_color = bit.bor(0xFF000000, bit.lshift(rainbow_r, 16), bit.lshift(rainbow_g, 8), rainbow_b)
            
            if os.clock() % 0.5 < 0.1 then
                _0x1.icon_index = _0x1.icon_index % #_0x1.icons + 1
            end
            
            renderFontDrawText(renderText, _0x1.icons[_0x1.icon_index] .. ' AutoReport: ' .. (active and '{00FF00}ON' or '{FF0000}OFF'), screenX - 120, screenY/2 - 10 + math.sin(_0x1.animation_offset) * 2, 0xFFFFFFFF)
            renderFontDrawText(renderSmallText, 'made by Papa_Neurowise', screenX - 120, screenY/2 + 5, rainbow_color)
        else
            -- Если скрипт не активирован, отключаем active
            active = false
        end
    end
end

-- Добавляем обработку переключения между игроками в реконе
function sampev.onSpectatePlayer(id, state)
    if state and active and _0x1.is_activated and disable_after_recon_switch.v then
        active = false
        printString('AutoReport: ~r~OFF', 5000, 6)
        sampAddChatMessage('Автоловля выключена (переключение в реконе)', 0x7ef542)
    end
end

function sampev.onTogglePlayerSpectating(state)
    if state and active and _0x1.is_activated then
        if disable_after_report.v then
            active = false
            printString('AutoReport: ~r~OFF', 5000, 6)
            sampAddChatMessage('Автоловля выключена (вход в рекон)', 0x7ef542)
        end
    end
end

function sampev.onServerMessage(color, text)
    if active and _0x1.is_activated then
        if text:find('%[([^%]]+)%] от ([^%[]+)%[%d+%]:') then
            local current_time = os.clock() * 1000
            if current_time - _0x1.last_report_time >= MIN_REPORT_DELAY then
                lua_thread.create(function()
                    sendOtCommand()
                    wait(1)
                    sendOtCommand()
                end)
                _0x1.last_report_time = current_time
            end
            return false
        end
    end
end

function sampev.onIncomingRpc(id, bitStream)
    if active and _0x1.is_activated and id == 93 then
        local message = raknet.receive(bitStream)
        if message and message:find('%[(%W+)%] от (%w+_%w+)%[(%d+)%]:') then
            local current_time = os.clock() * 1000
            if current_time - _0x1.last_report_time >= MIN_REPORT_DELAY then
                sendOtCommand()
                _0x1.last_report_time = current_time
            end
            return false
        end
    end
end

function sampev.onReceivePacket(id, bitStream)
    if active and _0x1.is_activated and (id == 211 or id == 93) then -- Добавляем проверку ID 93
        if bitStream and bitStream:getLength() > 0 then
            local current_time = os.clock() * 1000
            if current_time - _0x1.last_report_time >= MIN_REPORT_DELAY then
                -- Форсируем обработку пакетов
                memory.setint8(sampGetBase() + 0x119, 1, true)
                memory.setint8(sampGetBase() + 0x11A, 1, true)
                -- Агрессивная отправка
                if AGGRESSIVE_MODE then
                    lua_thread.create(function()
                        for i = 1, 3 do
                            sendOtCommand()
                            wait(1)
                        end
                    end)
                else
                    sendOtCommand()
                end
                _0x1.last_report_time = current_time
            end
            return false
        end
    end
end

