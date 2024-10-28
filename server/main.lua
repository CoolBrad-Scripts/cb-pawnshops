SpawnedShopPeds = {}
local pawnshops = {}

function GetActiveRequests(job)
    if not job then return {} end -- Return empty table if job is not provided
    local query = [[
        SELECT item, price, amount FROM business_requests WHERE business = ?
    ]]
    local result = SQLQuery(query, {job}) -- Execute the SQL query with the job as a parameter

    if result and #result > 0 then
        return result -- Return the result if data is found
    else
        return {} -- Return an empty table if no data is found
    end
end

function GetRequestAmount(job, item)
    local stockItems = GetActiveRequests(job) -- Get the stock items for the specified job
    for _, v in ipairs(stockItems) do
        if v.item == item then
            return v.amount -- Return the amount of the item if it exists
        end
    end
end

function DecreaseRequestAmount(job, item, amount)
    -- First, decrease the amount
    local updateQuery = [[
        UPDATE business_requests SET amount = amount - ? WHERE business = ? AND item = ?
    ]]
    local resultUpdate = SQLQuery(updateQuery, {amount, job, item}) -- Execute the SQL query with the job, item, and amount as parameters

    if resultUpdate then
        -- Check if the amount has reached 0 or less
        local checkQuery = [[
            SELECT amount FROM business_requests WHERE business = ? AND item = ?
        ]]
        local resultCheck = SQLQuery(checkQuery, {job, item})

        if resultCheck and resultCheck[1] and resultCheck[1].amount <= 0 then
            -- Delete the request if the amount is 0 or less
            local deleteQuery = [[
                DELETE FROM business_requests WHERE business = ? AND item = ?
            ]]
            SQLQuery(deleteQuery, {job, item}) -- Execute the deletion query
        end

        return true -- Return true if the update and check were successful
    else
        return false -- Return false if the update query failed
    end
end

function IncreaseRequestAmount(job, item, amount)
    local query = [[
        UPDATE business_requests SET amount = amount + ? WHERE business = ? AND item = ?
    ]]
    local result = SQLQuery(query, {amount, job, item}) -- Execute the SQL query with the job, item, and amount as parameters

    if result then
        return true -- Return true if the query was successful
    else
        return false -- Return false if the query failed
    end
end

function NewTransaction(payload)
    local toInventory = payload.toInventory
    local fromInventory = payload.fromInventory
    local match = false
    local uniquename = nil
    local Player = GetPlayer(payload.source)
    if Player == nil then return false end
    local job = Player.PlayerData.job.name
    local fullName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    local cid = Player.PlayerData.citizenid
    for k, v in pairs(Config.BusinessPawnShops) do
        uniquename = v.job.."_pawnshop"
        if (toInventory == uniquename) or (fromInventory == uniquename) then
            match = true
            break
        end
    end

    if fromInventory == uniquename then
        if payload.action == 'swap' or payload.action == 'give' then
            TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Allowed", "You are unable to perform this action right now!", "error")
            return false
        elseif payload.action == 'move' or payload.action == 'stack' then
            if job.."_pawnshop" ~= uniquename then
                TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Stealing?", "Are you trying to steal from me?", "error")
                return false
            else
                if payload.action == 'move' then
                    if (payload.count == payload.fromSlot.count) then
                        TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Too Much", "You must leave at least one in the stash at all times!", "warning")
                        return false
                    end
                elseif payload.action == 'stack' then
                    if payload.fromSlot.count == 0 then
                        TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Too Much", "You must leave at least one in the stash at all times!", "warning")
                        return false
                    end
                end
                DiscordLog(string.format("%s (%s) has removed `%.0fx %s` from the `%s` Pawn Shop", fullName, cid, payload.count, payload.fromSlot.name, job))
                return true
            end
        end
    end

    if not match then
        return true
    else
        local item = nil
        for key, value in pairs(payload.fromSlot) do
            if key == "name" then
                item = value
            end
        end

        if payload.fromType == 'player' and payload.toType == 'player' then
            TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Allowed", "You are unable to perform this action right now!", "error")
            return false
        end

        if payload.fromType == 'stash' then
            TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Stealing?", "Are you trying to steal from me?", "error")
            return false
        end

        if payload.action == 'swap' then
            if payload.toType == "player" then
                TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Stealing?", "Are you trying to steal from me?", "error")
                return false
            else
                TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Allowed", "You are unable to perform this action right now!", "error")
                return false
            end
        elseif payload.action == 'move' then
            if payload.toType == "player" then
                TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Allowed", "You are unable to perform this action right now!", "error")
                return false
            elseif payload.toInventory == uniquename then
                TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Allowed", "You are unable to perform this action right now!", "error")
                return false
            end
        elseif payload.action == 'stack' then
            if payload.toType == "player" then
                TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Allowed", "You are unable to perform this action right now!", "error")
                return false
            else
                for _, shop in pairs(Config.BusinessPawnShops) do
                    if shop.job.."_pawnshop" == toInventory then
                        if payload.toType == "stash" then
                            local stockItems = GetActiveRequests(shop.job)
                            for _, v in ipairs(stockItems) do
                                if v.item == item then
                                    local confirmSale = lib.callback.await('cb-pawnshops:client:ConfirmSale', payload.source, item, v.price)
                                    if confirmSale == 'confirm' then
                                        local requestedAmount = GetRequestAmount(shop.job, item)
                                        if requestedAmount == 0 then
                                            TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Buying", "We don't need any more of this right now. Try again later!", "error")
                                            return false
                                        elseif payload.count > requestedAmount then
                                            TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Too Much", string.format("We only need %.0f more %s!", requestedAmount, GetItemLabel(item)), "error")
                                            return false
                                        else
                                            local result = DecreaseRequestAmount(shop.job, item, payload.count)
                                            if result then
                                                if AddCash(payload.source, v.price * payload.count) then
                                                    DiscordLog(string.format("%s (%s) has sold `%.0fx %s` to the `%s` Pawn Shop", fullName, cid, payload.count, payload.fromSlot.name, job))
                                                    return true
                                                else
                                                    IncreaseRequestAmount(shop.job, item, payload.count)
                                                    return false
                                                end
                                            else
                                                return false
                                            end
                                        end
                                    elseif confirmSale == 'cancel' then
                                        return false
                                    else
                                        return false
                                    end
                                end
                            end
                            TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Buying", "We don't need any more of this right now. Try again later!", "error")
                            return false
                        end
                    end
                end
            end
        elseif payload.action == 'give' then
            if payload.toType == "player" then
                TriggerClientEvent('cb-pawnshops:client:Notify', payload.source, "Not Allowed", "You are unable to perform this action right now!", "error")
                return false
            end
        end
    end
end

AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    local src = source
    local Player = GetPlayer(src)
    local job = Player.PlayerData.job.name
    -- Loop through all closed shops in the config
    for _, shop in pairs(Config.BusinessPawnShops) do
        if job == shop.job then
            if GetDutyCount(job) == 0 then
                -- Spawn the shop ped if no one is on duty
                TriggerClientEvent('cb-pawnshops:client:spawnBusinessPawnShopPed', -1, job)
                SpawnedShopPeds[job] = true
            else
                -- Delete the shop ped if someone is on duty
                if (SpawnedShopPeds[job] ~= nil) then
                    TriggerClientEvent('cb-pawnshops:client:DeleteBusinessPawnShopPed', -1, job)
                    SpawnedShopPeds[job] = false
                end
            end
        end
    end
end)

RegisterNetEvent('cb-pawnshops:server:OnLoadSpawnShopPeds')
AddEventHandler('cb-pawnshops:server:OnLoadSpawnShopPeds', function()
    for _, shop in pairs(Config.BusinessPawnShops) do
        local onDuty = GetDutyCount(shop.job)
        if onDuty <= 0 then
            TriggerClientEvent('cb-pawnshops:client:spawnBusinessPawnShopPed', -1, shop.job)
            SpawnedShopPeds[shop.job] = true
            UpdateBusinessPawnShop(shop.job)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    -- Loop through each closed shop in the config
    for _, shop in pairs(Config.BusinessPawnShops) do
        local onDuty = GetDutyCount(shop.job)
        if onDuty == nil then onDuty = 0 end        
        -- If no one is on duty for the job related to this shop, spawn the ped
        if onDuty == 0 then
            Citizen.Wait(1500)
            TriggerClientEvent('cb-pawnshops:client:spawnBusinessPawnShopPed', -1, shop.job)
            SpawnedShopPeds[shop.job] = true
        end
    end

    -- Call any other necessary update functions after spawning the peds
    for _, shop in pairs(Config.BusinessPawnShops) do
        UpdateBusinessPawnShop(shop.job)
    end
end)

CreateThread(function()
    if UsingOxInventory then
        local hookId = exports.ox_inventory:registerHook('buyItem', function(payload)
            for _, shop in pairs(Config.BusinessPawnShops) do
                if payload.shopType == (shop.job.."_pawnshop") then
                    return false
                end
            end
        end, {})

        local hookId2 = exports.ox_inventory:registerHook('swapItems', function(payload)
            local result = NewTransaction(payload)
            return result
        end, {{inventoryFilter = pawnshops}})
    end
end)

lib.callback.register('cb-pawnshops:server:GetBuyRequests', function(source, job)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return end

    local query = [[
        SELECT item, price, amount FROM business_requests WHERE business = ?
    ]]
    local result = SQLQuery(query, {job})
    if result and #result > 0 then
        return result
    else
        return false
    end
end)

lib.callback.register('cb-pawnshops:server:hasRequiredItem', function(source, item)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return end
    if HasItem(src, item, 1) then
        return true
    else
        return false
    end
end)

function DeleteOldRequests(job)
    local requests = GetActiveRequests(job)
    -- Get the pawn shop configuration for this job
    local pawnShopConfig = nil
    for _, shop in pairs(Config.BusinessPawnShops) do
        if shop.job == job then
            pawnShopConfig = shop
            break
        end
    end

    -- Ensure the pawn shop configuration exists for the job
    if not pawnShopConfig then return end

    local allowedItems = pawnShopConfig.allowedItems or {}
    local allowedItemsSet = {}
    -- Convert allowed items list to a set for fast lookup
    for _, itemName in pairs(allowedItems) do
        allowedItemsSet[itemName] = true
    end

    for _, request in pairs(requests) do
        if not allowedItemsSet[request.item] then
            local deleteQuery = [[
                DELETE FROM business_requests WHERE business = ? AND item = ?
            ]]
            SQLQuery(deleteQuery, {job, request.item})
            DiscordLog(string.format("Removed an unauthorized request for %s from %s resulting in $%.0f being lost by the business", request.item, job, request.price * request.amount))
        end
    end
end

lib.callback.register('cb-pawnshops:server:EditBuyRequestPrice', function(source, item, newPrice, job)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return false end
    local playerJob = Player.PlayerData.job.name
    if job ~= playerJob then
        return false
    end

    -- Fetch the old price first
    local fetchQuery = [[
        SELECT price, amount FROM business_requests WHERE business = ? AND item = ?
    ]]
    local resultOld = SQLQuery(fetchQuery, {job, item})
    
    if resultOld and resultOld[1] then
        local oldPrice = resultOld[1].price  -- Store the old price
        if oldPrice > newPrice then
            if AddCash(src, (oldPrice - newPrice) * resultOld[1].amount) then
                local updateQuery = [[
                    UPDATE business_requests SET price = ? WHERE business = ? AND item = ?
                ]]
                local resultUpdate = SQLQuery(updateQuery, {newPrice, job, item})

                if resultUpdate then
                    UpdateBusinessPawnShop(job)
                    return true, oldPrice -- Return true and the old price
                end
            else
                return false
            end
        elseif newPrice > oldPrice then
            if RemoveCash(src, (newPrice - oldPrice) * resultOld[1].amount) then
                local updateQuery = [[
                    UPDATE business_requests SET price = ? WHERE business = ? AND item = ?
                ]]
                local resultUpdate = SQLQuery(updateQuery, {newPrice, job, item})

                if resultUpdate then
                    UpdateBusinessPawnShop(job)
                    return true, oldPrice -- Return true and the old price
                end
            else
                TriggerClientEvent('cb-pawnshops:client:Notify', src, "Insufficient Funds", "You don't have enough cash to complete the request!", "error")
                return false
            end
        elseif newPrice == oldPrice then
            TriggerClientEvent('cb-pawnshops:client:Notify', src, "Same Price", "You already have a Buy Request for this price!", "error")
            return false
        else
            return false
        end
    end
    return false
end)

lib.callback.register('cb-pawnshops:server:EditBuyRequestAmount', function(source, item, newAmount, job)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return false end
    local playerJob = Player.PlayerData.job.name
    if job ~= playerJob then
        return false
    end

    -- Fetch the old amount first
    local fetchQuery = [[
        SELECT amount, price FROM business_requests WHERE business = ? AND item = ?
    ]]
    local resultOld = SQLQuery(fetchQuery, {job, item})
    
    if resultOld and resultOld[1] then
        local oldAmount = resultOld[1].amount  -- Store the old amount
        if oldAmount > newAmount then
            if AddCash(src, resultOld[1].price * (oldAmount - newAmount)) then
                local updateQuery = [[
                    UPDATE business_requests SET amount = ? WHERE business = ? AND item = ?
                ]]
                local resultUpdate = SQLQuery(updateQuery, {newAmount, job, item})

                if resultUpdate then
                    UpdateBusinessPawnShop(job)
                    return true, oldAmount -- Return true and the old amount
                end
            else
                return false
            end
        elseif newAmount > oldAmount then
            if RemoveCash(src, resultOld[1].price * (newAmount - oldAmount)) then
                local updateQuery = [[
                    UPDATE business_requests SET amount = ? WHERE business = ? AND item = ?
                ]]
                local resultUpdate = SQLQuery(updateQuery, {newAmount, job, item})

                if resultUpdate then
                    UpdateBusinessPawnShop(job)
                    return true, oldAmount -- Return true and the old amount
                end
            else
                TriggerClientEvent('cb-pawnshops:client:Notify', src, "Insufficient Funds", "You don't have enough cash to complete the request!", "error")
                return false
            end
        elseif newAmount == oldAmount then
            TriggerClientEvent('cb-pawnshops:client:Notify', src, "Same Amount", "You already have a Buy Request for this amount!", "error")
            return false
        else
            return false
        end
    end
    return false
end)

lib.callback.register('cb-pawnshops:server:DeleteBuyRequest', function(source, item, job)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return false end
    local playerJob = Player.PlayerData.job.name
    if job ~= playerJob then
        return false
    end

    local query = [[
        DELETE FROM business_requests WHERE business = ? AND item = ?
    ]]
    local result = SQLQuery(query, {job, item})

    if result then
        UpdateBusinessPawnShop(job)
        return true
    else
        return false
    end
end)

lib.callback.register('cb-pawnshops:server:AddBuyRequest', function(source, item, amount, price)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return false end

    local job = Player.PlayerData.job.name
    local coords = GetPlayerCoords(src)

    -- Check if player is too far from the pawnshop
    for k, v in pairs(Config.BusinessPawnShops) do
        if v.job == job then
            local dist = #(vector3(v.coords.x, v.coords.y, v.coords.z) - coords)
            if dist > 5.0 then
                DiscordLog(string.format("%s attempted to add a request to %s from a distance of %.0f. Possibly Cheating", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, job, dist))
                return false
            end
        end
    end

    -- Check if the item already exists for the given business in the database
    local checkQuery = [[
        SELECT amount FROM business_requests WHERE business = ? AND item = ?
    ]]
    local result = SQLQuery(checkQuery, {job, item})

    if result and #result > 0 then
        local existingAmount = tonumber(result[1].amount)        
        -- If the item exists and amount is not zero, return false
        if existingAmount ~= 0 then
            TriggerClientEvent('cb-pawnshops:client:Notify', src, "Item Out of Stock", "This item is out of stock!", "error")
            return false
        else
            -- If the item exists and amount is zero, update the row with the new data
            local updateQuery = [[
                UPDATE business_requests SET amount = ?, price = ?, updated_at = CURRENT_TIMESTAMP WHERE business = ? AND item = ?
            ]]
            local updateResult = SQLQuery(updateQuery, {amount, price, job, item})

            -- Only remove cash if the update operation was successful
            if updateResult then
                local newPrice = price * amount

                if RemoveCash(src, newPrice) then
                    UpdateBusinessPawnShop(job)
                    return true
                else
                    -- If player doesn't have enough cash, rollback the update
                    local rollbackQuery = [[
                        UPDATE business_requests SET amount = 0 WHERE business = ? AND item = ?
                    ]]
                    SQLQuery(rollbackQuery, {job, item})
                    TriggerClientEvent('cb-pawnshops:client:Notify', src, "Insufficient Funds", "You don't have enough cash to complete the request!", "error")
                    return false
                end
            else
                TriggerClientEvent('cb-pawnshops:client:Notify', src, "Database Error", "Unable to update the request, please try again.", "error")
                return false
            end
        end
    else
        -- If the item does not exist, insert a new row
        local insertQuery = [[
            INSERT INTO business_requests (business, item, amount, price, updated_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
        ]]
        local insertResult = SQLQuery(insertQuery, {job, item, amount, price})

        -- Only remove cash if the insert operation was successful
        if insertResult then
            local newPrice = price * amount

            if RemoveCash(src, newPrice) then
                UpdateBusinessPawnShop(job)
                return true
            else
                -- If player doesn't have enough cash, rollback the insert
                local deleteQuery = [[
                    DELETE FROM business_requests WHERE business = ? AND item = ?
                ]]
                SQLQuery(deleteQuery, {job, item})
                TriggerClientEvent('cb-pawnshops:client:Notify', src, "Insufficient Funds", "You don't have enough cash to complete the request!", "error")
                return false
            end
        else
            TriggerClientEvent('cb-pawnshops:client:Notify', src, "Database Error", "Unable to add the request, please try again.", "error")
            return false
        end
    end
end)

lib.callback.register('cb-pawnshops:server:RemoveStock', function(source, item, amount)
    local src = source
    if src == nil then return false end

    local Player = GetPlayer(src)
    if Player == nil then return false end

    local job = Player.PlayerData.job.name
    local coords = GetPlayerCoords(src)
    for k, v in pairs(Config.BusinessPawnShops) do
        if v.job == job then
            local dist = #(vector3(v.coords.x, v.coords.y, v.coords.z) - coords)
            if dist > 5.0 then
                DiscordLog(string.format("%s attempted to remove a request from %s from a distance of %.0f. Possibly Cheating", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, job, dist))
                return false
            end
        end
    end


    if UsingOxInventory then
        -- Query to get the current amount of the item in stock for the player's job/business
        local query = [[
            SELECT amount FROM business_requests WHERE business = ? AND item = ?
        ]]
        local result = SQLQuery(query, {job, item})

        if result and #result > 0 then
            local currentAmount = result[1].amount
        
            -- Check if there's enough stock to remove
            if currentAmount >= amount then
                -- Retrieve the price of the item
                local priceQuery = [[
                    SELECT price FROM business_requests WHERE business = ? AND item = ?
                ]]
                local priceResult = SQLQuery(priceQuery, {job, item})
        
                -- Ensure the price query was successful
                if priceResult and #priceResult > 0 then
                    local itemPrice = priceResult[1].price
        
                    -- Calculate the total amount to add (price * amount)
                    local addAmount = itemPrice * amount
        
                    -- Update the stock, reducing the item count
                    local updateQuery = [[
                        UPDATE business_requests SET amount = amount - ? WHERE business = ? AND item = ?
                    ]]
                    local updateResult = SQLQuery(updateQuery, {amount, job, item})
        
                    -- If update is successful, return true
                    if updateResult then
                        -- Add cash to the player
                        if AddCash(source, addAmount) then
                            UpdateBusinessPawnShop(job)
                            return true
                        else
                            TriggerClientEvent('cb-pawnshops:client:Notify', source, "Inventory Error", "There was an issue adding the item! Please try again!", "error")
                            return false
                        end
                    else
                        return false
                    end
                else
                    -- Price not found for the item
                    TriggerClientEvent('cb-pawnshops:client:Notify', source, "No Price", "Unable to find the price for " .. GetItemLabel(item) .. ".", "error")
                    return false
                end
            else
                -- Not enough stock to remove the requested amount
                TriggerClientEvent('cb-pawnshops:client:Notify', source, "Not Enough Stock", "Not enough stock of " .. GetItemLabel(item) .. " to remove.", "error")
                return false
            end
        else
            -- Item not found in stock
            TriggerClientEvent('cb-pawnshops:client:Notify', source, "No Requests", "You haven't made any Buy Requests!", "error")
            return false
        end        
    else
        return false
    end
end)

function RemoveFromStock(item, amount, job)
    if UsingOxInventory then
        -- Query to get the current amount of the item in stock
        local query = [[
            SELECT amount FROM business_requests WHERE business = ? AND item = ?
        ]]
        local result = SQLQuery(query, {job, item})

        if result and #result > 0 then
            local currentAmount = result[1].amount

            -- Check if there's enough stock to remove
            if currentAmount >= amount then
                -- Update the stock, reducing the item count
                local updateQuery = [[
                    UPDATE business_requests SET amount = amount - ? WHERE business = ? AND item = ?
                ]]
                local updateResult = SQLQuery(updateQuery, {amount, job, item})

                -- If update is successful, return true
                if updateResult then
                    return true
                else
                    -- Handle failure of stock update
                    return false
                end
            else
                -- Not enough stock to remove the requested amount
                return false
            end
        else
            -- Item not found in stock
            return false
        end
    else
        -- OxInventory is not in use, handle accordingly
        return false
    end
end

function UpdateBusinessPawnShop(job)
    if UsingOxInventory then
        -- Query to get the items and prices from the database for the specified job
        local query = [[
            SELECT item, price, amount FROM business_requests WHERE business = ?
        ]]
        local result = SQLQuery(query, {job})  -- Use the passed job to query

        -- Prepare the inventory dynamically based on the result from the database
        local inventory = {}
        if result and #result > 0 then
            for i = 1, #result do
                table.insert(inventory, {
                    name = result[i].item,
                    price = result[i].price,
                    count = result[i].amount,
                    currency = 'money'
                })
            end
        end
        for _, shop in pairs(Config.BusinessPawnShops) do
            if shop.job == job then
                local uniquename = shop.job.."_pawnshop"
                exports.ox_inventory:RegisterStash(uniquename, shop.label, #shop.allowedItems, shop.weight)

                -- Fetch all items in the stash
                local stashItems = exports.ox_inventory:GetInventoryItems(uniquename)
                local stashItemNames = {}
                local totalStashItems = 0
                if stashItems then
                    for _, stashItem in pairs(stashItems) do
                        stashItemNames[stashItem.name] = stashItem.count -- Keep track of the item and its count
                        totalStashItems = totalStashItems + 1
                    end
                end
                DeleteOldRequests(job)
                for stashItemName, stashItemCount in pairs(stashItemNames) do
                    local isAllowed = false
                    for _, allowedItem in ipairs(shop.allowedItems) do
                        if stashItemName == allowedItem then
                            isAllowed = true
                            break
                        end
                    end
                    if not isAllowed then
                        -- If the item is not allowed, remove it from the stash
                        print(string.format("Unauthorized item found: %s, Removing %d from %s", stashItemName, stashItemCount, uniquename))
                        if exports.ox_inventory:RemoveItem(uniquename, stashItemName, stashItemCount) then
                            DiscordLog(string.format("Unauthorized item. Removed %.0fx %s from %s", stashItemCount, GetItemLabel(stashItemName), uniquename))
                        end
                    end
                end

                -- Check if any allowed items are missing and add them
                for _, item in ipairs(shop.allowedItems) do
                    if stashItemNames[item] == 0 or stashItemNames[item] == nil then
                        -- Item is not in the stash, add it
                        print(string.format("Adding missing allowed item: %s to %s", item, uniquename))
                        exports.ox_inventory:AddItem(uniquename, item, 1)
                    end
                end
                pawnshops[#pawnshops + 1] = uniquename
            end
        end
    end
end


RegisterNetEvent('cb-pawnshops:server:DeletePed')
AddEventHandler('cb-pawnshops:server:DeletePed', function(ped)
    TriggerClientEvent('cb-pawnshops:client:DeletePed', -1, ped)
end)