local QBCore = exports['qb-core']:GetCoreObject()
local configCode = LoadResourceFile(GetCurrentResourceName(), "shared/config.lua")
local WalletConfig = load(configCode, "WalletConfig", "t", _G)()

--[[
    Wallet Server: Lizenzverwaltung & Persistenz
    - Speichert Lizenzen/Dokumente in der DB
    - Synchronisiert Änderungen an alle relevanten Clients
    - Bietet Chatbefehle für Admins
]]--

-- Datenbank-Initialisierung (nur beim ersten Start nötig)
CreateThread(function()
    MySQL.query([[CREATE TABLE IF NOT EXISTS wallet_licenses (
        citizenid VARCHAR(50) NOT NULL,
        type VARCHAR(50) NOT NULL,
        label VARCHAR(100) NOT NULL,
        PRIMARY KEY (citizenid, type)
    )]])
end)

-- Lizenzen für Spieler laden
QBCore.Functions.CreateCallback('wallet:getLicenses', function(source, cb, citizenid)
    MySQL.query('SELECT * FROM wallet_licenses WHERE citizenid = ?', {citizenid}, function(result)
        cb(result or {})
    end)
end)

-- Lizenz hinzufügen
RegisterCommand('setlizenz', function(source, args, raw)
    local targetId, licType = tonumber(args[1]), args[2]
    if not targetId or not licType then return end
    local xPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xPlayer then return end
    local label = nil
    for _,v in ipairs(WalletConfig.LicenseTypes) do if v.name == licType then label = v.label end end
    if not label then return end
    MySQL.update('INSERT IGNORE INTO wallet_licenses (citizenid, type, label) VALUES (?, ?, ?)', {
        xPlayer.PlayerData.citizenid, licType, label
    })
    TriggerClientEvent('wallet:syncLicenses', -1, xPlayer.PlayerData.citizenid)
end, true)

-- Lizenz entfernen
RegisterCommand('removelizenz', function(source, args, raw)
    local targetId, licType = tonumber(args[1]), args[2]
    if not targetId or not licType then return end
    local xPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xPlayer then return end
    MySQL.update('DELETE FROM wallet_licenses WHERE citizenid = ? AND type = ?', {
        xPlayer.PlayerData.citizenid, licType
    })
    TriggerClientEvent('wallet:syncLicenses', -1, xPlayer.PlayerData.citizenid)
end, true)

-- Lizenzdaten für einen Spieler synchronisieren
RegisterNetEvent('wallet:requestLicenses', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    MySQL.query('SELECT * FROM wallet_licenses WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        TriggerClientEvent('wallet:setLicenses', src, result or {})
    end)
end)

-- Lizenz anzeigen
RegisterNetEvent('wallet:showLicenseTo', function(targetId, license)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local charinfo = Player.PlayerData.charinfo
    local name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
    TriggerClientEvent('wallet:receiveLicense', targetId, license, name)
end)

-- Sofortige Synchronisation nach Änderung
RegisterNetEvent('wallet:syncLicenses', function(citizenid)
    for _, Player in pairs(QBCore.Functions.GetPlayers()) do
        local xPlayer = QBCore.Functions.GetPlayer(Player)
        if xPlayer and xPlayer.PlayerData.citizenid == citizenid then
            MySQL.query('SELECT * FROM wallet_licenses WHERE citizenid = ?', {citizenid}, function(result)
                TriggerClientEvent('wallet:setLicenses', Player, result or {})
            end)
        end
    end
end)

-- Fahrzeugpapier für ein Fahrzeug erstellen
RegisterNetEvent('wallet:server:createVehiclePaper', function(citizenid, plate)
    if not citizenid or not plate then return end
    -- Platzhalterdaten
    local paperData = {
        inhaber = citizenid,
        anmeldedatum = os.date('%d.%m.%Y'),
        erstanmeldedatum = os.date('%d.%m.%Y'),
        baujahr = '-',
        modell = '-',
        kraftstoffart = '-'
    }
    local label = json.encode({label = 'Fahrzeugpapier '..plate, data = paperData})
    MySQL.update('INSERT IGNORE INTO wallet_licenses (citizenid, type, label) VALUES (?, ?, ?)', {
        citizenid, 'fahrzeugpapier_'..plate, label
    })
    TriggerClientEvent('wallet:syncLicenses', -1, citizenid)
end)

-- Fahrzeugschlüssel für einen Spieler laden
RegisterNetEvent('wallet:requestVehicleKeys', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Alle Schlüssel aus vehicle_keys laden
    exports.oxmysql:execute('SELECT plate, model, is_original FROM vehicle_keys WHERE citizenid = ?', {
        Player.PlayerData.citizenid
    }, function(keys)
        local allKeys = {}
        
        if keys then
            for _, v in ipairs(keys) do
                table.insert(allKeys, {
                    plate = v.plate,
                    model = v.model,
                    is_original = v.is_original == 1, -- Explizit als Boolean
                    is_copy = v.is_original == 0 -- Explizit als Boolean
                })
            end
        end
        
        -- Debug-Ausgabe
        print("^2[Wallet Debug]^7 Sende Schlüssel an Client:", json.encode(allKeys))
        
        -- An Client senden
        TriggerClientEvent('wallet:setVehicleKeys', src, allKeys)
    end)
end)

-- Schlüssel an anderen Spieler übergeben
RegisterNetEvent('wallet:giveCarKey', function(targetId, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not Target then return end
    
    -- Prüfen ob der Spieler den Schlüssel besitzt
    exports.oxmysql:execute('SELECT id, vehicle_id, model FROM vehicle_keys WHERE citizenid = ? AND plate = ? AND is_original = 0 LIMIT 1', {
        Player.PlayerData.citizenid,
        plate
    }, function(result)
        if result and result[1] then
            -- Schlüssel vom Geber entfernen
            exports.oxmysql:execute('DELETE FROM vehicle_keys WHERE id = ?', {
                result[1].id
            })
            
            -- Schlüssel dem Empfänger geben
            exports.oxmysql:execute('INSERT INTO vehicle_keys (vehicle_id, plate, model, citizenid, is_original) VALUES (?, ?, ?, ?, 0)', {
                result[1].vehicle_id,
                plate,
                result[1].model,
                Target.PlayerData.citizenid
            })
            
            -- Beide Wallets aktualisieren
            TriggerClientEvent('wallet:requestVehicleKeys', src)
            TriggerClientEvent('wallet:requestVehicleKeys', targetId)
            
            -- Benachrichtigungen senden
            TriggerClientEvent('QBCore:Notify', src, 'Schlüssel übergeben', 'success')
            TriggerClientEvent('QBCore:Notify', targetId, 'Schlüssel erhalten', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Du hast keinen Schlüssel für dieses Fahrzeug', 'error')
        end
    end)
end) 