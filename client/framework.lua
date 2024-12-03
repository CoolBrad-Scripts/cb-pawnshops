CreateThread(function()
    Framework = "qb-core"
    UsingOxInventory = false
    if GetResourceState('qbx_core') == 'started' then
        Framework = "qbox"
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = "qb-core"
    end
    if GetResourceState('ox_inventory') == 'started' then
        UsingOxInventory = true
    end
end)

function GetPlayerData()
    if Framework == "qb-core" then
        return QBCore.Functions.GetPlayerData()
    elseif Framework == "qbox" then
        return QBX.PlayerData
    end
end

function HasItemClient(item, amount)
    if amount == nil then amount = 1 end
    local itemCount = exports.ox_inventory:GetItemCount(item)
    if not itemCount then
        return false
    elseif itemCount >= amount then
        return true
    else
        return false
    end
end

function Notify(label, message, type)
    lib.notify({
        title = label,
        description = message,
        duration = 7500,
        type = type
    })
end

function GetPlayerJob()
   return GetPlayerData().job.name
end

function GetPlayerJobLabel()
    return GetPlayerData().job.label
end

function IsOnDuty()
    return GetPlayerData().job.onduty
end

function IsPlayerBoss()
    return GetPlayerData().job.isboss
end

function HasEnoughCash(amount)
    local player = GetPlayerData()
    if player.money.cash >= amount then
        return true
    else
        return false
    end
end

function GetItemLabel(item)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:Items(item).label
    else
        return QBCore.Shared.Items[item].label
    end
end

function GetItemImage(item)
    if GetResourceState('ox_inventory') == 'started' then           
        if exports.ox_inventory:Items(item).client ~= nil then
            return exports.ox_inventory:Items(item).client.image
        else
            return "nui://" .. Config.InventoryImage .. item .. ".png"
        end
    else
        return "nui://" .. Config.InventoryImage .. QBCore.Shared.Items[item].image
    end
end

RegisterNetEvent('cb-pawnshops:client:Notify', function(label, message, type)
    Notify(label, message, type)
end)

RegisterNetEvent('cb-pawnshops:client:NotEnoughSpace', function()
    lib.notify({
        title = "Not Enough Space",
        description = "You don't have enough space in your inventory to take more items!",
        duration = 7500,
        position = 'center-right',
        icon = 'ban',
        iconColor = '#C53030'
    })
end)