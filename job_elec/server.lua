local playersMoney = {}
local activeMissions = {}
local missionPos = vector3(727.02, -1300.89, 26.27)

RegisterNetEvent('elecjob:startMission')
AddEventHandler('elecjob:startMission', function()
    local src = source
    activeMissions[src] = true
end)

RegisterNetEvent('elecjob:pay')
AddEventHandler('elecjob:pay', function()
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dist = #(coords - missionPos)
    
    if activeMissions[src] and dist < 15.0 then
        local payout = math.random(500, 1000)
        
        if not playersMoney[src] then
            playersMoney[src] = 0
        end
        
        playersMoney[src] = playersMoney[src] + payout
        activeMissions[src] = false
        
        TriggerClientEvent('elecjob:updateMoney', src, playersMoney[src])
    else
        print("Avertissement: " .. GetPlayerName(src) .. " a tente d'exploiter le paiement electrique.")
    end
end)