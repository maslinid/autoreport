script_name("AutoRep Sync")
script_version("1.0")
script_author("Papa_Neurowise")

require 'lib.moonloader'
local sampev = require 'lib.samp.events'
local inicfg = require 'inicfg'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

-- Конфигурация
local directIni = 'moonloader\\config\\autoreport_sync.ini'
local mainIni = inicfg.load({
    main = {
        enabled = true,
        show_markers = true
    },
    style = {
        author_color = 0xFF0000FF, -- красный
        user_color = 0x7ef542FF,   -- зеленый
        author_text = "AutoRep Developer",
        user_text = "AutoRep User"
    }
}, directIni)
inicfg.save(mainIni, directIni)

-- Глобальные переменные
local active_users = {}
local sync_timer = 0
local SYNC_INTERVAL = 5
local SYNC_TIMEOUT = 10
local MY_NICKNAME = "Papa_Neurowise"
local renderText = renderCreateFont('Arial', 8, FCR_BOLD + FCR_BORDER)

-- Проверка статуса основного скрипта
function checkMainScript()
    local handle = io.open(getGameDirectory() .. '\\moonloader\\config\\autoreport_license.txt', 'r')
    if handle then
        handle:close()
        return true
    end
    return false
end

-- Отправка синхронизации
function sendSync()
    local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if result then
        local nickname = sampGetPlayerNickname(id)
        local isAuthor = nickname == MY_NICKNAME
        -- Отправляем синхронизацию только если основной скрипт активен
        if checkMainScript() then
            sampSendChat("/c [AR2.0:" .. (mainIni.main.enabled and "1" or "0") .. ":" .. (isAuthor and "1" or "0") .. "]")
        end
    end
end

-- Отрисовка меток
function renderAdminMarkers()
    if not mainIni.main.show_markers then return end
    
    for id, data in pairs(active_users) do
        if sampIsPlayerConnected(id) then
            local result, ped = sampGetCharHandleBySampPlayerId(id)
            if result and doesCharExist(ped) then
                local x, y, z = getCharCoordinates(ped)
                local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
                
                if getDistanceBetweenCoords3d(myX, myY, myZ, x, y, z) < 50.0 then
                    local sx, sy = convert3DCoordsToScreen(x, y, z + 0.8)
                    if sx and sy then
                        local marker = data.isAuthor and mainIni.style.author_text or mainIni.style.user_text
                        local color = data.isAuthor and mainIni.style.author_color or mainIni.style.user_color
                        renderFontDrawText(renderText, marker, sx - 30, sy, color)
                    end
                end
            end
        end
    end
end

-- Обработчики событий
function sampev.onServerMessage(color, text)
    local status, isAuthor = text:match("%[AR2%.0:(%d):(%d)%]")
    if status then
        local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if result then
            active_users[id] = {
                time = os.time(),
                active = (status == "1"),
                isAuthor = (isAuthor == "1")
            }
        end
        return false
    end
    return true
end

-- Команды
function cmd_arsync(arg)
    if arg == "markers" then
        mainIni.main.show_markers = not mainIni.main.show_markers
        inicfg.save(mainIni, directIni)
        sampAddChatMessage("[AutoRep Sync] Отображение меток " .. (mainIni.main.show_markers and "включено" or "выключено"), 0x7ef542)
    else
        sampAddChatMessage("[AutoRep Sync] Команды:", 0x7ef542)
        sampAddChatMessage("/arsync markers - включить/выключить отображение меток", 0x7ef542)
    end
end

-- Главный цикл
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    -- Регистрация команд
    sampRegisterChatCommand("arsync", cmd_arsync)
    
    -- Проверка наличия основного скрипта
    if not checkMainScript() then
        sampAddChatMessage("[AutoRep Sync] Основной скрипт не найден!", 0x7ef542)
        return
    end
    
    sampAddChatMessage("[AutoRep Sync] Скрипт успешно загружен!", 0x7ef542)
    
    while true do
        wait(0)
        
        -- Синхронизация
        if os.time() - sync_timer >= SYNC_INTERVAL then
            sendSync()
            sync_timer = os.time()
            
            -- Очистка неактивных пользователей
            for id, data in pairs(active_users) do
                if os.time() - data.time > SYNC_TIMEOUT then
                    active_users[id] = nil
                end
            end
        end
        
        -- Отрисовка меток
        renderAdminMarkers()
    end
end
