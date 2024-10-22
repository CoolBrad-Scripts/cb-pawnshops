ClosedShopPeds = {}

lib.callback.register('cb-pawnshops:client:ConfirmSale', function(item, price)
    local alert = lib.alertDialog({
        header = 'Confirm Sale',
        content = 'Are you sure you want to sell ' .. GetItemLabel(item) .. ' for $' .. price .. '?',
        centered = true,
        cancel = true
    })
    return alert
end)

function OpenPricesMenu(job)
    local menuOptions = {}
    local buyRequests = lib.callback.await('cb-pawnshops:server:GetBuyRequests', false, job)
    if not buyRequests then
        table.insert(menuOptions, {
            title = 'No Buy Requests',
            description = 'You have not set any Buy Requests',
            icon = 'fa-solid fa-shopping-cart',
            disabled = true,
        })
    else
        for _, request in pairs(buyRequests) do
            -- Extract the relevant values for each request
            local requestedItem = request.item or "Unknown Item"
            local amount = request.amount or 0
            local price = request.price or 0
        
            -- Create a title and description for each buy request
            local title = string.format("%s", GetItemLabel(requestedItem))
            local description = string.format("Price: $%d\nAmount to Buy: %.0f", price, amount)
        
            -- Insert the options dynamically into the menuOptions table
            table.insert(menuOptions, {
                title = title,
                description = description,
                icon = GetItemImage(requestedItem),
                onSelect = function()
                    exports.ox_inventory:openInventory('stash', job..'_pawnshop')
                end
            })
        end
    end
    lib.registerContext({
        id = 'PricesMenu',
        title = "Active Buy Requests",
        options = menuOptions
    })
    lib.showContext('PricesMenu')
end

function EditBuyRequestMenu(job, item)
    local menuOptions = {}
    local buyRequests = lib.callback.await('cb-pawnshops:server:GetBuyRequests', false, job)
    if not buyRequests then
        table.insert(menuOptions, {
            title = 'No Buy Requests',
            description = 'You have not set any Buy Requests',
            icon = 'fa-solid fa-shopping-cart',
            disabled = true,
            onSelect = function()
                exports.ox_inventory:openInventory('stash', job..'_pawnshop')
            end
        })
    else
        for _, request in pairs(buyRequests) do
            -- Extract the relevant values for each request
            local requestedItem = request.item or "Unknown Item"
            if requestedItem == item then
                local amount = request.amount or 0
                local price = request.price or 0
            
                -- Create a title and description for each buy request
                local title = string.format("%s", GetItemLabel(requestedItem))
                local description = string.format("Price: $%d\nAmount to Buy: %.0f", price, amount)
            
                -- Insert the options dynamically into the menuOptions table
                table.insert(menuOptions, {
                    title = title,
                    description = description,
                    icon = GetItemImage(requestedItem),
                    disabled = true, -- Enable since we have valid buy requests
                })

                table.insert(menuOptions, {
                    title = "Change Price",
                    description = description,
                    icon = "fa-solid fa-money-bill-wave",
                    onSelect = function()
                        local input = lib.inputDialog('Edit Buy Request', {
                            {type = 'number', label = 'Price', description = 'Enter the price you are willing to pay!', required = true, min = 1, max = 99999},
                        })
                        lib.callback.await('cb-pawnshops:server:EditBuyRequestPrice', false, item, input[1], job)
                    end
                })

                table.insert(menuOptions, {
                    title = "Change Amount",
                    description = description,
                    icon = "fa-hashtag",
                    onSelect = function()
                        local input = lib.inputDialog('Edit Buy Request', {
                            {type = 'number', label = 'Amount', description = 'Enter the amount you are willing to buy!', required = true, min = 1, max = 99999},
                        })
                        lib.callback.await('cb-pawnshops:server:EditBuyRequestAmount', false, item, input[1], job)
                    end
                })

                table.insert(menuOptions, {
                    title = "Delete Request",
                    description = description,
                    icon = "fa-solid fa-trash",
                    onSelect = function()
                        local deleted = lib.callback.await('cb-pawnshops:server:DeleteBuyRequest', false, item, job)
                        if deleted then
                            Notify("Deleted Request", "The buy request has been deleted", "success")
                        else
                            Notify("Failed to Delete", "The buy request could not be deleted. Try again!", "error")
                        end
                    end
                })
            end
        end
    end
    lib.registerContext({
        id = 'EditBuyRequestMenu',
        title = "Edit Buy Request",
        options = menuOptions
    })
    lib.showContext('EditBuyRequestMenu')
end

function OpenShopMenu(job)
    local menuOptions = {}
    local itemOptions = {}
    local buyRequests = lib.callback.await('cb-pawnshops:server:GetBuyRequests', false, job)
    if not buyRequests then
        table.insert(menuOptions, {
            title = 'No Buy Requests',
            description = 'You have not set any Buy Requests',
            icon = 'fa-solid fa-shopping-cart',
            disabled = true,
            onSelect = function()
                exports.ox_inventory:openInventory('stash', job..'_pawnshop')
            end
        })
    else
        for _, request in pairs(buyRequests) do
            -- Extract the relevant values for each request
            local item = request.item or "Unknown Item"
            local amount = request.amount or 0
            local price = request.price or 0
        
            -- Create a title and description for each buy request
            local title = string.format("%s", GetItemLabel(item))
            local description = string.format("Price: $%d\nAmount to Buy: %.0f", price, amount)
        
            -- Insert the options dynamically into the menuOptions table
            table.insert(menuOptions, {
                title = title,
                description = description,
                icon = GetItemImage(item),
                disabled = false, -- Enable since we have valid buy requests
                onSelect = function()
                    EditBuyRequestMenu(job, item)
                end
            })
        end
    end

    for k, v in pairs(Config.ClosedShops) do
        if v.job == job then
            for key, value in pairs(v.allowedItems) do
                table.insert(itemOptions, {value = value, label = GetItemLabel(value)})
            end
        end
    end    
    
    table.insert(menuOptions, {
        title = 'Create Buy Request',
        description = 'Create a Buy Request for a specific item',
        icon = 'fa-solid fa-money-bill-wave',
        iconColor = "green",
        onSelect = function()
            local input = lib.inputDialog('Amount', {
                {type = 'select', label = 'Item', description = 'Select the item you want to purchase from civilians', required = true, options = itemOptions },
                {type = 'number', label = 'Amount', description = 'Enter the number of items to buy', required = true, min = 1, max = 999},
                {type = 'number', label = 'Price', description = 'Enter the price you are willing to pay!', required = true, min = 1, max = 999},
            })
            lib.callback.await('cb-pawnshops:server:AddBuyRequest', false, input[1], input[2], input[3], job)
        end
    })

    lib.registerContext({
        id = 'OpenShopMenu',
        title = GetPlayerJobLabel(),
        options = menuOptions
    })
    lib.showContext('OpenShopMenu')
end

local function spawnClosedShopPedForPlayer(job)
    local closedShopModel = `a_m_y_business_02`
    
    -- Load the model
    RequestModel(closedShopModel)
    local tries = 0
    while not HasModelLoaded(closedShopModel) and tries < 10 do
        Wait(500)
        tries = tries + 1
    end

    if HasModelLoaded(closedShopModel) then
        -- Find the shop configuration for the given job
        local shopData = nil
        for _, shop in pairs(Config.ClosedShops) do
            if job == shop.job then
                shopData = shop
                break
            end
        end

        if shopData and shopData.coords then
            local coords = shopData.coords
            local closedShopPed = CreatePed(5, closedShopModel, coords.x, coords.y, coords.z, coords.w, true, true)
            
            if DoesEntityExist(closedShopPed) then
                FreezeEntityPosition(closedShopPed, true)
                SetEntityInvincible(closedShopPed, true)
                Wait(100)
                TaskStartScenarioInPlace(closedShopPed, "WORLD_HUMAN_CLIPBOARD", 0, true)
                if not ClosedShopPeds[job] then
                    ClosedShopPeds[job] = {}
                end
                table.insert(ClosedShopPeds[job], closedShopPed)

                exports.ox_target:addLocalEntity(closedShopPed, {
                    {
                        label = "View Prices",
                        icon = "fa-solid fa-money-bill-wave",
                        distance = shopData.targetDistance,
                        onSelect = function()
                            OpenPricesMenu(job)
                        end,
                    },
                    {
                        label = shopData.label,
                        icon = "fa-solid fa-shopping-cart",
                        distance = shopData.targetDistance,
                        onSelect = function()
                            exports.ox_inventory:openInventory('stash', job.."_pawnshop")
                        end,
                    },
                    {
                        label = "Manage Shop",
                        icon = "fa-solid fa-briefcase",
                        distance = shopData.targetDistance,
                        onSelect = function()
                            OpenShopMenu(job)
                        end,
                        canInteract = function()
                            local PlayerData = GetPlayerData()
                            local playerJob = PlayerData.job.name
                            return (ClosedShopPeds[playerJob] ~= nil) and (playerJob == job)
                        end
                    },
                })
            else
                lib.print.error("Failed to create the shop ped at " .. tostring(coords))
            end
        end
        SetModelAsNoLongerNeeded(closedShopModel)
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cb-pawnshops:server:OnLoadSpawnShopPeds')
end)

RegisterNetEvent('cb-pawnshops:client:SpawnClosedShopPed')
AddEventHandler('cb-pawnshops:client:SpawnClosedShopPed', function(job)
    spawnClosedShopPedForPlayer(job)
end)

RegisterNetEvent('cb-pawnshops:client:DeleteClosedShopPed')
AddEventHandler('cb-pawnshops:client:DeleteClosedShopPed', function(job)
    if ClosedShopPeds[job] then
        for _, ped in ipairs(ClosedShopPeds[job]) do
            if DoesEntityExist(ped) then
                TriggerServerEvent('cb-pawnshops:server:DeletePed', ped)
            end
        end
        ClosedShopPeds[job] = nil -- Clear the table for this job
    end
end)

RegisterNetEvent('cb-pawnshops:client:DeletePed', function(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end)