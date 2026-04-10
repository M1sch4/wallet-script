local QBCore = exports['qb-core']:GetCoreObject()
local playerLicenses = {}


-- Verstecke das NUI-Overlay beim Resource-Start
CreateThread(function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

-- Öffnet das Wallet-UI mit /wallet
RegisterCommand('wallet', function()
    local player = QBCore.Functions.GetPlayerData()
    print("WALLET PLAYERDATA", json.encode(player))
    QBCore.Functions.TriggerCallback('vehiclemanager:getKeys', function(carkeys)
        print("WALLET CARKEYS", json.encode(carkeys))
        if not carkeys then
            print("WALLET ERROR: Keine Fahrzeugschlüssel erhalten")
            carkeys = {}
        end
        QBCore.Functions.TriggerCallback('wallet:getLicenses', function(licenses)
            print("WALLET LICENSES", json.encode(licenses))
            playerLicenses = licenses or {}
            local charinfo = player.charinfo or {}
            local data = {
                action = 'open',
                name = (charinfo.firstname or player.firstname or 'Unbekannt') .. ' ' .. (charinfo.lastname or player.lastname or ''),
                birthdate = charinfo.birthdate or player.birthdate or '-',
                joindate = charinfo.joinDate or player.joindate or player.metadata.joindate or '-',
                height = charinfo.height or player.height or '-',
                hunger = player.metadata.hunger or 0,
                thirst = player.metadata.thirst or 0,
                citizenid = player.citizenid or player.identifier or '-',
                licenses = playerLicenses,
                carkeys = carkeys
            }
            print("WALLET SENDING DATA", json.encode(data))
            SendNUIMessage(data)
            SetNuiFocus(true, true)
        end, player.citizenid)
    end)
end, false)

-- NUI schließt das UI
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Lizenzaktionen (z.B. zeigen, weitergeben)
RegisterNUICallback('licenseAction', function(data, cb)
    if not data or not data.action or not data.license then
        print("WALLET ERROR: Invalid license action data")
        cb('ok')
        return
    end
    -- Robuste Fahrzeugpapier-Erkennung
    local isFahrzeugpapier = false
    if data.license.type and string.sub(data.license.type, 1, 16) == 'fahrzeugpapier_' then
        isFahrzeugpapier = true
    elseif data.license.label then
        local label = data.license.label
        if type(label) == 'string' then
            if label:find('Fahrzeugpapier') then isFahrzeugpapier = true end
            -- Prüfe auf JSON
            pcall(function()
                local l = json.decode(label)
                if l and l.label and l.label:find('Fahrzeugpapier') then isFahrzeugpapier = true end
            end)
        elseif type(label) == 'table' and label.label and label.label:find('Fahrzeugpapier') then
            isFahrzeugpapier = true
        end
    end
    if data.action == 'showSelf' then
        if isFahrzeugpapier then
            SendNUIMessage({ action = 'showLicense', license = data.license, from = nil })
            SetNuiFocus(true, true)
        else
            TriggerEvent('chat:addMessage', { args = { '^2Lizenz', 'Du zeigst deine Lizenz: ' .. (data.license.label or data.license.type) } })
        end
    elseif data.action == 'showOther' then
        local closestPlayer, dist = GetClosestPlayer()
        if closestPlayer and dist < 3.0 then
            TriggerServerEvent('wallet:showLicenseTo', GetPlayerServerId(closestPlayer), data.license)
            -- UI beim zeigenden Spieler schließen
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
        else
            TriggerEvent('chat:addMessage', { args = { '^1Fehler', 'Kein Spieler in der Nähe!' } })
        end
    end
    cb('ok')
end)

-- Empfange Lizenzanzeige von anderem Spieler
RegisterNetEvent('wallet:receiveLicense', function(license, fromName)
    if not license or not fromName then
        print("WALLET ERROR: Invalid license data received")
        return
    end
    SendNUIMessage({ action = 'showLicense', license = license, from = fromName })
end)

-- Lizenzdaten werden synchronisiert
RegisterNetEvent('wallet:setLicenses', function(licenses)
    if not licenses then
        print("WALLET ERROR: Invalid licenses data received")
        return
    end
    playerLicenses = licenses
    SendNUIMessage({ action = 'updateLicenses', licenses = playerLicenses })
end)

-- Hilfsfunktion: Finde nächsten Spieler
function GetClosestPlayer()
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local closest, closestDist = nil, 999.0
    for _,pid in ipairs(players) do
        if pid ~= PlayerId() then
            local tgtPed = GetPlayerPed(pid)
            local dist = #(GetEntityCoords(tgtPed) - pos)
            if dist < closestDist then
                closest = pid
                closestDist = dist
            end
        end
    end
    return closest, closestDist
end

-- Schlüsselübergabe (Kopie) an anderen Spieler
RegisterNUICallback('giveCarKey', function(data, cb)
    print("WALLET DEBUG: giveCarKey aufgerufen mit Daten:", json.encode(data))
    
    if not data or not data.plate then
        print("WALLET ERROR: Keine Plate in Daten gefunden")
        TriggerEvent('ox_lib:notify', {type='error', description='Ungültige Schlüsseldaten!'})
        cb('fail')
        return
    end

    local ped = PlayerPedId()
    local players = GetActivePlayers()
    local pos = GetEntityCoords(ped)
    local closest, closestDist = nil, 999.0
    
    for _,pid in ipairs(players) do
        if pid ~= PlayerId() then
            local tgtPed = GetPlayerPed(pid)
            local dist = #(GetEntityCoords(tgtPed) - pos)
            if dist < closestDist then
                closest = pid
                closestDist = dist
            end
        end
    end
    
    if closest and closestDist < 3.0 then
        local targetId = GetPlayerServerId(closest)
        print("WALLET DEBUG: Nächster Spieler gefunden, ID:", targetId)
        
        -- Direkt den Server-Event triggern mit plate
        TriggerServerEvent('vehiclemanager:server:giveCarKey', data.plate, targetId)
        TriggerEvent('ox_lib:notify', {type='success', description='Versuche Schlüssel zu übergeben...'})
        
        -- UI sofort schließen
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        
        cb('ok')
    else
        print("WALLET DEBUG: Kein Spieler in der Nähe gefunden")
        TriggerEvent('ox_lib:notify', {type='error', description='Kein Spieler in der Nähe!'})
        cb('fail')
    end
end)

-- Wallet Client: UI & Interaktion
local QBCore = exports['qb-core']:GetCoreObject()

-- UI anzeigen
RegisterNetEvent('wallet:show', function()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player then return end
    
    -- Lizenzen laden
    QBCore.Functions.TriggerCallback('wallet:getLicenses', function(licenses)
        -- Fahrzeugschlüssel laden
        TriggerServerEvent('wallet:requestVehicleKeys')
        
        -- UI öffnen
        SendNUIMessage({
            action = 'open',
            name = Player.charinfo.firstname .. ' ' .. Player.charinfo.lastname,
            birthdate = Player.charinfo.birthdate,
            citizenid = Player.citizenid,
            height = Player.charinfo.height or 170,
            hunger = Player.metadata.hunger,
            thirst = Player.metadata.thirst,
            licenses = licenses
        })
        SetNuiFocus(true, true)
    end, Player.citizenid)
end)

-- Fahrzeugschlüssel empfangen und anzeigen
RegisterNetEvent('wallet:setVehicleKeys', function(keys)
    SendNUIMessage({
        action = 'updateCarKeys',
        carkeys = keys
    })
end)

-- Lizenz anderen Spielern zeigen
RegisterNUICallback('licenseAction', function(data, cb)
    if data.action == 'showSelf' then
        TriggerEvent('wallet:receiveLicense', data.license)
    elseif data.action == 'showOther' then
        local closestPlayer, distance = QBCore.Functions.GetClosestPlayer()
        if closestPlayer ~= -1 and distance < 3.0 then
            TriggerServerEvent('wallet:showLicenseTo', GetPlayerServerId(closestPlayer), data.license)
        else
            QBCore.Functions.Notify('Niemand in der Nähe', 'error')
        end
    end
    cb('ok')
end)

-- Lizenz von anderem Spieler empfangen
RegisterNetEvent('wallet:receiveLicense', function(license, from)
    SendNUIMessage({
        action = 'showLicense',
        license = license,
        from = from
    })
    SetNuiFocus(true, true)
end)

-- Event zum Aktualisieren der Fahrzeugschlüssel
RegisterNetEvent('wallet:requestVehicleKeys', function()
    print("WALLET DEBUG: Fordere Fahrzeugschlüssel an")
    QBCore.Functions.TriggerCallback('vehiclemanager:getKeys', function(keys)
        if keys then
            print("WALLET DEBUG: Erhaltene Schlüssel:", json.encode(keys))
            SendNUIMessage({
                action = 'updateCarKeys',
                carkeys = keys
            })
        else
            print("WALLET ERROR: Keine Schlüssel erhalten")
            SendNUIMessage({
                action = 'updateCarKeys',
                carkeys = {}
            })
        end
    end)
end)

-- UI schließen (Remote)
RegisterNetEvent('wallet:close', function()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end) 