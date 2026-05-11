local isOnDuty = false
local missionStatus = 0 
local blip = nil
local currentStation = nil
local workVehicle = nil
local myMoney = 0
local oldOutfit = {} 
local showHelp = false

local totalRepairs = 0 

local servicePos = vector3(733.45, -1309.28, 26.31)   
local missionPos = vector3(727.02, -1300.89, 26.27)   
local garagePos = vector3(733.41, -1291.19, 26.28)    
local vehSpawn = vector4(728.07, -1291.09, 26.28, 90.0)

local stations = {
    vector3(661.28, -1450.39, 30.80),
    vector3(448.05, -1833.07, 27.94),
    vector3(928.77, -1422.53, 31.35),
    vector3(521.93, -1310.85, 29.78),
    vector3(-145.21, -1399.61, 30.13),
    vector3(-36.29, -1574.99, 29.30),
    vector3(-71.68, -1803.19, 27.77),
    vector3(403.80, -1402.11, 29.50),
    vector3(513.16, -1416.23, 29.29),
}

local mg = {
    active = false,
    size = 3,
    path = {},
    visited = {},
    targets = {},
    walls = {},
    cTarget = 2,
    startX = 0.0, startY = 0.0, cW = 0.0, cH = 0.0,
    backtracks = 0,
    maxErrors = 6,
    timeLimit = 60,
    startTime = 0
}

local function saveOutfit(ped)
    for i = 0, 11 do
        oldOutfit[i] = { draw = GetPedDrawableVariation(ped, i), tex = GetPedTextureVariation(ped, i) }
    end
end

local function applyUniform(ped)
    SetPedComponentVariation(ped, 11, 251, 0, 0) 
    SetPedComponentVariation(ped, 8, 15, 0, 0)   
    SetPedComponentVariation(ped, 4, 98, 0, 0)   
    SetPedComponentVariation(ped, 6, 24, 0, 0)   
    SetPedComponentVariation(ped, 3, 0, 0, 0)    
end

local function restoreOutfit(ped)
    for i, data in pairs(oldOutfit) do
        SetPedComponentVariation(ped, i, data.draw, data.tex, 0)
    end
end

local function drawText(text, x, y, scale, r, g, b)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, 255)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawMoneyHUD()
    SetTextFont(4)
    SetTextScale(0.7, 0.7)
    SetTextColour(114, 204, 114, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString("$ " .. tostring(myMoney))
    DrawText(0.9, 0.85)
    
    SetTextScale(0.4, 0.4)
    SetTextColour(200, 200, 200, 255)
    SetTextEntry("STRING")
    AddTextComponentString("Reparations: " .. tostring(totalRepairs))
    DrawText(0.9, 0.90)
end

local function failMinigame(reason)
    mg.active = false
    PlaySoundFrontend(-1, "Hack_Failed", "IG_HACK_USA_SOUNDS", false)
    ClearPedTasksImmediately(PlayerPedId())
    
    if blip then RemoveBlip(blip) end
    blip = AddBlipForCoord(missionPos.x, missionPos.y, missionPos.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 2)
    SetBlipRoute(blip, true)
    
    missionStatus = 0 
    TriggerEvent('chat:addMessage', { args = { "^1[Dispatch] ^0Echec : " .. reason .. " ! Retournez au QG pour une nouvelle mission." } })
end

local function generateSolvableGrid()
    local gridPath = {}
    local visitedGen = {}

    local function dfs(x, y)
        table.insert(gridPath, {x = x, y = y})
        visitedGen[x][y] = true
        if #gridPath == mg.size * mg.size then return true end

        local dirs = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}}
        for i = #dirs, 2, -1 do
            local j = math.random(i)
            dirs[i], dirs[j] = dirs[j], dirs[i]
        end

        for _, d in ipairs(dirs) do
            local nx, ny = x + d[1], y + d[2]
            if nx >= 1 and nx <= mg.size and ny >= 1 and ny <= mg.size and not visitedGen[nx][ny] then
                if dfs(nx, ny) then return true end
            end
        end
        visitedGen[x][y] = false
        table.remove(gridPath)
        return false
    end

    local success = false
    while not success do
        gridPath = {}
        for i = 1, mg.size do 
            visitedGen[i] = {} 
            for j = 1, mg.size do visitedGen[i][j] = false end 
        end
        
        local startX, startY
        if mg.size % 2 == 1 then
            repeat
                startX = math.random(1, mg.size)
                startY = math.random(1, mg.size)
            until (startX + startY) % 2 == 0
        else
            startX = math.random(1, mg.size)
            startY = math.random(1, mg.size)
        end
        
        success = dfs(startX, startY)
    end

    local targetCount = mg.size
    mg.targets = {}
    table.insert(mg.targets, {x = gridPath[1].x, y = gridPath[1].y, num = 1})

    local step = math.floor((#gridPath - 2) / (targetCount - 1))
    for i = 1, targetCount - 2 do
        local idx = 1 + (i * step) + math.random(0, math.floor(step/2))
        table.insert(mg.targets, {x = gridPath[idx].x, y = gridPath[idx].y, num = i + 1})
    end
    table.insert(mg.targets, {x = gridPath[#gridPath].x, y = gridPath[#gridPath].y, num = targetCount})

    local pathLinks = {}
    for i = 1, #gridPath - 1 do
        local p1, p2 = gridPath[i], gridPath[i+1]
        pathLinks[p1.x.."_"..p1.y.."_"..p2.x.."_"..p2.y] = true
        pathLinks[p2.x.."_"..p2.y.."_"..p1.x.."_"..p1.y] = true
    end

    for i = 1, mg.size do
        for j = 1, mg.size do
            if i < mg.size and not pathLinks[i.."_"..j.."_"..(i+1).."_"..j] and math.random() < 0.4 then
                mg.walls[i][j].right = true
            end
            if j < mg.size and not pathLinks[i.."_"..j.."_"..i.."_"..(j+1)] and math.random() < 0.4 then
                mg.walls[i][j].bottom = true
            end
        end
    end
end

local function initMinigame()
    math.randomseed(GetGameTimer())
    
    if totalRepairs < 20 then
        mg.size = 3
        mg.maxErrors = 6
    elseif totalRepairs < 50 then
        mg.size = 4
        mg.maxErrors = 9
    elseif totalRepairs < 250 then
        mg.size = 5
        mg.maxErrors = 12
    else
        mg.size = 6
        mg.maxErrors = 30
    end

    mg.cW = 0.20 / mg.size
    mg.cH = 0.35 / mg.size
    mg.startX = 0.5 - (mg.cW * mg.size) / 2
    mg.startY = 0.5 - (mg.cH * mg.size) / 2

    mg.path, mg.visited, mg.walls = {}, {}, {}
    for i = 1, mg.size do
        mg.visited[i], mg.walls[i] = {}, {}
        for j = 1, mg.size do
            mg.visited[i][j] = false
            mg.walls[i][j] = {right = false, bottom = false}
        end
    end

    generateSolvableGrid()

    mg.cTarget = 2
    local startCell = mg.targets[1]
    mg.path = {{x = startCell.x, y = startCell.y}}
    mg.visited[startCell.x][startCell.y] = true
    
    mg.backtracks = 0
    mg.timeLimit = mg.size * 12
    mg.startTime = GetGameTimer()
    
    mg.active = true
end

local function processMove(nx, ny)
    local last = mg.path[#mg.path]
    if last.x == nx and last.y == ny then return end

    if #mg.path > 1 and mg.path[#mg.path - 1].x == nx and mg.path[#mg.path - 1].y == ny then
        mg.backtracks = mg.backtracks + 1
        PlaySoundFrontend(-1, "Hack_Failed", "IG_HACK_USA_SOUNDS", false)
        
        mg.visited[last.x][last.y] = false
        for _, t in ipairs(mg.targets) do
            if t.x == last.x and t.y == last.y and t.num == mg.cTarget - 1 then
                mg.cTarget = mg.cTarget - 1
            end
        end
        table.remove(mg.path)
        
        if mg.backtracks >= mg.maxErrors then
            failMinigame("Trop d'erreurs de parcours (" .. mg.maxErrors .. " max)")
        end
        return
    end

    if not mg.visited[nx][ny] then
        local dx, dy = math.abs(last.x - nx), math.abs(last.y - ny)
        if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) then
            local blocked = false
            if dx == 1 then
                local minX = math.min(last.x, nx)
                if mg.walls[minX][last.y].right then blocked = true end
            else
                local minY = math.min(last.y, ny)
                if mg.walls[last.x][minY].bottom then blocked = true end
            end

            if not blocked then
                local isTarget, tNum = false, 0
                for _, t in ipairs(mg.targets) do
                    if t.x == nx and t.y == ny then isTarget, tNum = true, t.num end
                end

                if not isTarget or tNum == mg.cTarget then
                    PlaySoundFrontend(-1, "Click", "DLC_HEIST_HACKING_SNAKE_SOUNDS", false)
                    table.insert(mg.path, {x = nx, y = ny})
                    mg.visited[nx][ny] = true
                    if isTarget then mg.cTarget = mg.cTarget + 1 end
                end
            end
        end
    end
end

RegisterNetEvent('elecjob:updateMoney')
AddEventHandler('elecjob:updateMoney', function(amount) myMoney = amount end)

RegisterCommand('addborne', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    print("vector3(" .. string.format("%.2f", coords.x) .. ", " .. string.format("%.2f", coords.y) .. ", " .. string.format("%.2f", coords.z) .. "),")
    TriggerEvent('chat:addMessage', { args = { "Coordonnees envoyees dans la console F8 !" } })
end)

RegisterCommand('setrepairs', function(source, args)
    if args[1] then
        totalRepairs = tonumber(args[1])
        TriggerEvent('chat:addMessage', { args = { "^2[Dev] ^0Nombre de réparations défini sur : " .. totalRepairs } })
    end
end)

local adminBlips, showingAdminBlips = {}, false
RegisterCommand('showbornes', function()
    showingAdminBlips = not showingAdminBlips
    if showingAdminBlips then
        for i, c in ipairs(stations) do
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, 354) SetBlipColour(b, 2) table.insert(adminBlips, b)
        end
    else
        for _, b in ipairs(adminBlips) do RemoveBlip(b) end
        adminBlips = {}
    end
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        if isOnDuty then
            sleep = 0
            drawMoneyHUD()
        end
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    local hqBlip = AddBlipForCoord(servicePos.x, servicePos.y, servicePos.z)
    SetBlipSprite(hqBlip, 354)
    SetBlipColour(hqBlip, 5)
    SetBlipAsShortRange(hqBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Entreprise Electrique")
    EndTextCommandSetBlipName(hqBlip)

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        local distService = #(coords - servicePos)
        if distService < 10.0 then
            sleep = 0
            DrawMarker(1, servicePos.x, servicePos.y, servicePos.z - 1.0, 0,0,0, 0,0,0, 1.5, 1.5, 1.0, 255, 255, 0, 150, false, false, 2, false, nil, nil, false)
            if distService < 2.0 then
                if not isOnDuty then
                    drawText("Appuyez sur E pour prendre votre service", 0.5, 0.8, 0.5)
                    if IsControlJustPressed(1, 51) then
                        isOnDuty = true
                        saveOutfit(ped)
                        applyUniform(ped)
                    end
                else
                    drawText("Appuyez sur E pour terminer votre service", 0.5, 0.8, 0.5)
                    if IsControlJustPressed(1, 51) then
                        isOnDuty = false
                        missionStatus = 0
                        restoreOutfit(ped)
                        if blip then RemoveBlip(blip) blip = nil end
                        if DoesEntityExist(workVehicle) then DeleteVehicle(workVehicle) end
                    end
                end
            end
        end

        if isOnDuty then
            local distGarage = #(coords - garagePos)
            if distGarage < 10.0 then
                sleep = 0
                DrawMarker(1, garagePos.x, garagePos.y, garagePos.z - 1.0, 0,0,0, 0,0,0, 1.5, 1.5, 1.0, 0, 150, 255, 150, false, false, 2, false, nil, nil, false)
                if distGarage < 2.0 then
                    if DoesEntityExist(workVehicle) then
                        drawText("Appuyez sur E pour ranger le vehicule", 0.5, 0.8, 0.5)
                        if IsControlJustPressed(1, 51) then
                            DeleteVehicle(workVehicle)
                            workVehicle = nil
                        end
                    else
                        drawText("Appuyez sur E pour sortir un vehicule", 0.5, 0.8, 0.5)
                        if IsControlJustPressed(1, 51) then
                            local hash = GetHashKey("boxville2")
                            RequestModel(hash)
                            while not HasModelLoaded(hash) do Citizen.Wait(10) end
                            workVehicle = CreateVehicle(hash, vehSpawn.x, vehSpawn.y, vehSpawn.z, vehSpawn.w, true, false)
                            SetPedIntoVehicle(ped, workVehicle, -1)
                            SetModelAsNoLongerNeeded(hash)
                        end
                    end
                end
            end

            local distMission = #(coords - missionPos)
            if distMission < 10.0 then
                sleep = 0
                DrawMarker(1, missionPos.x, missionPos.y, missionPos.z - 1.0, 0,0,0, 0,0,0, 1.5, 1.5, 1.0, 0, 255, 0, 150, false, false, 2, false, nil, nil, false)
                if distMission < 2.0 then
                    if missionStatus == 0 then
                        drawText("Appuyez sur E pour prendre une mission", 0.5, 0.8, 0.5)
                        if IsControlJustPressed(1, 51) then
                            currentStation = stations[math.random(#stations)]
                            if blip then RemoveBlip(blip) end
                            blip = AddBlipForCoord(currentStation.x, currentStation.y, currentStation.z)
                            SetBlipSprite(blip, 1)
                            SetBlipColour(blip, 5)
                            SetBlipRoute(blip, true)
                            missionStatus = 1
                            TriggerServerEvent("elecjob:startMission")
                        end
                    elseif missionStatus == 3 then
                        drawText("Appuyez sur E pour valider la mission", 0.5, 0.8, 0.5)
                        if IsControlJustPressed(1, 51) then
                            TriggerServerEvent("elecjob:pay")
                            totalRepairs = totalRepairs + 1
                            if blip then RemoveBlip(blip) blip = nil end
                            missionStatus = 0 
                        end
                    elseif missionStatus == 1 or missionStatus == 2 then
                        drawText("Vous avez deja une mission en cours", 0.5, 0.8, 0.5)
                    end
                end
            end

            if missionStatus == 1 then
                local distStation = #(coords - currentStation)
                if distStation < 15.0 then
                    sleep = 0
                    DrawMarker(1, currentStation.x, currentStation.y, currentStation.z - 1.0, 0,0,0, 0,0,0, 1.5, 1.5, 1.0, 255, 0, 0, 150, false, false, 2, false, nil, nil, false)
                    if distStation < 2.0 then
                        drawText("Appuyez sur E pour lancer le diagnostic", 0.5, 0.8, 0.5)
                        if IsControlJustPressed(1, 51) then
                            TaskStartScenarioInPlace(ped, "WORLD_HUMAN_WELDING", 0, true)
                            initMinigame()
                            missionStatus = 2
                        end
                    end
                end
            elseif missionStatus == 2 and mg.active then
                sleep = 0
                local timeLeft = mg.timeLimit - math.floor((GetGameTimer() - mg.startTime) / 1000)
                if timeLeft <= 0 then
                    failMinigame("Temps ecoule")
                end

                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 172, true)
                DisableControlAction(0, 173, true)
                DisableControlAction(0, 174, true)
                DisableControlAction(0, 175, true)
                SetMouseCursorActiveThisFrame()

                local isHelpOpen = IsDisabledControlPressed(0, 74)

                DrawRect(0.5, 0.5, 0.28, 0.50, 20, 25, 30, 250)
                drawText("DIAGNOSTIC", 0.5, 0.26, 0.5, 255, 255, 255)
                
                local colorTime = {255, 255, 255}
                if timeLeft <= 10 then colorTime = {255, 50, 50} end
                drawText("Temps: " .. timeLeft .. "s | Erreurs: " .. mg.backtracks .. "/" .. mg.maxErrors, 0.5, 0.29, 0.35, colorTime[1], colorTime[2], colorTime[3])

                if not isHelpOpen then
                    drawText("Maintenez [H] pour voir les regles", 0.5, 0.72, 0.35, 180, 180, 180)
                end

                for i = 1, mg.size do
                    for j = 1, mg.size do
                        local cX, cY = mg.startX + (i - 1) * mg.cW, mg.startY + (j - 1) * mg.cH
                        local r, g, b = 50, 60, 70
                        local textR, textG, textB = 255, 255, 255
                        
                        if mg.visited[i][j] then
                            r, g, b = 40, 180, 100
                            textR, textG, textB = 0, 0, 0
                        end

                        DrawRect(cX, cY, mg.cW - 0.004, mg.cH - 0.007, r, g, b, 255)

                        for _, t in ipairs(mg.targets) do
                            if t.x == i and t.y == j then
                                drawText(tostring(t.num), cX, cY - 0.015, 0.4, textR, textG, textB)
                            end
                        end
                    end
                end

                for k = 1, #mg.path - 1 do
                    local p1, p2 = mg.path[k], mg.path[k+1]
                    local x1, y1 = mg.startX + (p1.x - 1) * mg.cW, mg.startY + (p1.y - 1) * mg.cH
                    local x2, y2 = mg.startX + (p2.x - 1) * mg.cW, mg.startY + (p2.y - 1) * mg.cH
                    
                    local midX, midY = (x1 + x2) / 2, (y1 + y2) / 2
                    local w, h = math.abs(x1 - x2) + (mg.cW * 0.4), math.abs(y1 - y2) + (mg.cH * 0.4)
                    
                    if p1.x == p2.x then w = mg.cW * 0.4 end
                    if p1.y == p2.y then h = mg.cH * 0.4 end
                    DrawRect(midX, midY, w, h, 40, 180, 100, 255)
                end

                for i = 1, mg.size do
                    for j = 1, mg.size do
                        local cX, cY = mg.startX + (i - 1) * mg.cW, mg.startY + (j - 1) * mg.cH
                        if mg.walls[i][j].right then DrawRect(cX + (mg.cW / 2), cY, 0.006, mg.cH, 10, 10, 10, 255) end
                        if mg.walls[i][j].bottom then DrawRect(cX, cY + (mg.cH / 2), mg.cW, 0.010, 10, 10, 10, 255) end
                    end
                end

                if isHelpOpen then
                    DrawRect(0.5, 0.5, 0.28, 0.50, 15, 15, 15, 240) 
                    drawText("~y~COMMENT JOUER~w~", 0.5, 0.32, 0.5)
                    drawText("1. Reliez tous les points dans l'ordre", 0.5, 0.40, 0.35)
                    drawText("2. Passez par TOUTES les cases", 0.5, 0.45, 0.35)
                    drawText("3. Pas de diagonales", 0.5, 0.50, 0.35)
                    drawText("4. Les murs noirs bloquent", 0.5, 0.55, 0.35)
                    drawText("Relachez [H] pour reprendre", 0.5, 0.65, 0.35, 255, 100, 100)
                else
                    local mx, my = GetControlNormal(0, 239), GetControlNormal(0, 240)
                    local hoverX = math.floor((mx - mg.startX + (mg.cW / 2)) / mg.cW) + 1
                    local hoverY = math.floor((my - mg.startY + (mg.cH / 2)) / mg.cH) + 1

                    if hoverX >= 1 and hoverX <= mg.size and hoverY >= 1 and hoverY <= mg.size then
                        if IsDisabledControlPressed(0, 24) then processMove(hoverX, hoverY) end
                    end

                    local head = mg.path[#mg.path]
                    local nx, ny = head.x, head.y
                    if IsDisabledControlJustPressed(0, 172) then ny = ny - 1 end
                    if IsDisabledControlJustPressed(0, 173) then ny = ny + 1 end
                    if IsDisabledControlJustPressed(0, 174) then nx = nx - 1 end
                    if IsDisabledControlJustPressed(0, 175) then nx = nx + 1 end
                    
                    if nx >= 1 and nx <= mg.size and ny >= 1 and ny <= mg.size then processMove(nx, ny) end

                    if #mg.path == (mg.size * mg.size) and mg.cTarget > #mg.targets then
                        mg.active = false
                        PlaySoundFrontend(-1, "Hack_Success", "IG_HACK_USA_SOUNDS", false)
                        ClearPedTasksImmediately(ped)
                        if blip then RemoveBlip(blip) end
                        blip = AddBlipForCoord(missionPos.x, missionPos.y, missionPos.z)
                        SetBlipSprite(blip, 1) SetBlipColour(blip, 2) SetBlipRoute(blip, true)
                        missionStatus = 3
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    local serviceModel = GetHashKey("s_m_m_autoshop_02")
    RequestModel(serviceModel)
    while not HasModelLoaded(serviceModel) do Citizen.Wait(10) end
    local servicePed = CreatePed(4, serviceModel, servicePos.x, servicePos.y, servicePos.z - 1.0, 90.0, false, true)
    FreezeEntityPosition(servicePed, true) SetEntityInvincible(servicePed, true) SetBlockingOfNonTemporaryEvents(servicePed, true)
    TaskStartScenarioInPlace(servicePed, "WORLD_HUMAN_CLIPBOARD", 0, true)

    local garageModel = GetHashKey("s_m_y_xmech_01") 
    RequestModel(garageModel)
    while not HasModelLoaded(garageModel) do Citizen.Wait(10) end
    local garagePed = CreatePed(4, garageModel, garagePos.x, garagePos.y, garagePos.z - 1.0, 90.0, false, true)
    FreezeEntityPosition(garagePed, true) SetEntityInvincible(garagePed, true) SetBlockingOfNonTemporaryEvents(garagePed, true)
    TaskStartScenarioInPlace(garagePed, "WORLD_HUMAN_STAND_MOBILE", 0, true) 
end)