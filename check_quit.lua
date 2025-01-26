script_name('Players Quit Logger')
script_version('1.0')
script_author('Papa_Neurowise')

require 'lib.moonloader'
local sampev = require 'lib.samp.events'
local renderFont = renderCreateFont('Arial', 10, FCR_BORDER)

-- Структура для хранения информации
local quitInfo = {}
local playerPositions = {}
local lastDisconnectTime = {}

-- Проверка активации AutoReport
local function isAutoReportActivated()
    local path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
    if not doesFileExist(path) then return false end
    local f = io.open(path, 'r')
    if not f then return false end
    local content = f:read('*all')
    f:close()
    if not content or #content < 20 then return false end
    local expiration_time = content:match("(%d+):")
    if not expiration_time then return false end
    return tonumber(expiration_time) > os.time()
end

-- Проверка, находится ли игрок в зоне стриминга
local function isPlayerInStreamingRange(playerId)
    if not playerPositions[playerId] then return false end
    local pos = playerPositions[playerId]
    local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
    local dist = getDistanceBetweenCoords3d(pos.x, pos.y, pos.z, myX, myY, myZ)
    return dist <= 150.0 -- Стандартная дистанция стриминга SA:MP
end

-- Проверка активации AutoReport
local function isAutoReportActivated()
    local path = getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt'
    if not doesFileExist(path) then 
        return false 
    end
    
    local f = io.open(path, 'r')
    if not f then 
        return false 
    end
    
    local content = f:read('*all')
    f:close()
    
    if not content or #content < 20 then 
        return false 
    end
    
    local expiration_time = content:match("(%d+):")
    if not expiration_time then 
        return false 
    end
    
    -- Проверяем, не истек ли срок действия
    return tonumber(expiration_time) > os.time()
end

-- Остальные функции остаются без изменений
function sampev.onPlayerStreamIn(playerId, team, model, position, rotation, color, fightingStyle)
    if not isAutoReportActivated() then return end
    
    playerPositions[playerId] = {
        x = position.x,
        y = position.y,
        z = position.z
    }
    
    if lastDisconnectTime[playerId] then
        local timeDiff = os.time() - lastDisconnectTime[playerId]
        if timeDiff < 30 then
            for i = #quitInfo, 1, -1 do
                if quitInfo[i].nickname == sampGetPlayerNickname(playerId) then
                    table.remove(quitInfo, i)
                    break
                end
            end
        end
        lastDisconnectTime[playerId] = nil
    end
end

function sampev.onPlayerSync(playerId, data)
    if not isAutoReportActivated() then return end
    
    if data.position then
        playerPositions[playerId] = {
            x = data.position.x,
            y = data.position.y,
            z = data.position.z
        }
    end
end

function sampev.onPlayerQuit(playerId, reason)
    if not isAutoReportActivated() then return end
    
    if sampIsPlayerConnected(playerId) then
        local nickname = sampGetPlayerNickname(playerId)
        local reasonText = "вышел"
        
        if reason == 0 then
            reasonText = "вышел"
            lastDisconnectTime[playerId] = os.time()
        elseif reason == 1 then
            reasonText = "кикнут"
        elseif reason == 2 then
            reasonText = "бан"
        end
        
        local pos = playerPositions[playerId]
        if pos then
            table.insert(quitInfo, {
                x = pos.x,
                y = pos.y,
                z = pos.z + 0.5,
                text = string.format("%s\nПричина: %s\nВремя: %s", nickname, reasonText, getCurrentTime()),
                time = os.time(),
                nickname = nickname
            })
            
            -- Сообщение в чат только если игрок был в зоне стриминга
            if isPlayerInStreamingRange(playerId) then
                sampAddChatMessage(string.format('[Quit Logger] Игрок %s %s на позиции: %.1f, %.1f, %.1f', 
                    nickname, reasonText, pos.x, pos.y, pos.z), 0x7ef542)
            end
        end
        
        playerPositions[playerId] = nil
    end
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    if not isAutoReportActivated() then
        sampAddChatMessage('[Quit Logger] {ffffff}Для работы требуется активированный AutoReport!', 0x7ef542)
        thisScript():unload()
        return
    end
    
    sampRegisterChatCommand("clearquit", function()
        if not isAutoReportActivated() then
            sampAddChatMessage('[Quit Logger] {ffffff}Для работы требуется активированный AutoReport!', 0x7ef542)
            return
        end
        
        quitInfo = {}
        playerPositions = {}
        lastDisconnectTime = {}
        sampAddChatMessage('[Quit Logger] {ffffff}Все записи очищены!', 0x7ef542)
    end)
    
    while true do
        wait(0)
        
        if not isAutoReportActivated() then
            sampAddChatMessage('[Quit Logger] {ffffff}AutoReport деактивирован. Выгружаем скрипт...', 0x7ef542)
            thisScript():unload()
            break
        end
        
        local currentTime = os.time()
        for i = #quitInfo, 1, -1 do
            local info = quitInfo[i]
            
            if currentTime - info.time > 300 then
                table.remove(quitInfo, i)
            else
                local dist = getDistanceBetweenCoords3d(info.x, info.y, info.z, getCharCoordinates(PLAYER_PED))
                if dist < 30.0 then
                    local sx, sy = convert3DCoordsToScreen(info.x, info.y, info.z)
                    if sx and sy then
                        renderFontDrawText(renderFont, info.text, sx, sy, 0xFFFFFFFF)
                    end
                end
            end
        end
    end
end

function getCurrentTime()
    return os.date("%H:%M:%S")
end