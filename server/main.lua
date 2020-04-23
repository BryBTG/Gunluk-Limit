local PlayersWorking = {}
ESX = nil
local limit = 10000
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local function Work(source, item)

	SetTimeout(item[1].time, function()

		if PlayersWorking[source] == true then

			local xPlayer = ESX.GetPlayerFromId(source)
			if xPlayer == nil then
				return
			end

			for i=1, #item, 1 do
				local itemQtty = 0
				if item[i].name ~= _U('delivery') then
					itemQtty = xPlayer.getInventoryItem(item[i].db_name).count
				end

				local requiredItemQtty = 0
				if item[1].requires ~= "nothing" then
					requiredItemQtty = xPlayer.getInventoryItem(item[1].requires).count
				end

				if item[i].name ~= _U('delivery') and itemQtty >= item[i].max then
					TriggerClientEvent('esx:showNotification', source, _U('max_limit', item[i].name))
				elseif item[i].requires ~= "nothing" and requiredItemQtty <= 0 then
					TriggerClientEvent('esx:showNotification', source, _U('not_enough', item[1].requires_name))
				else
					if item[i].name ~= _U('delivery') then
						-- Chances to drop the item
						if item[i].drop == 100 then
							xPlayer.addInventoryItem(item[i].db_name, item[i].add)
						else
							local chanceToDrop = math.random(100)
							if chanceToDrop <= item[i].drop then
								xPlayer.addInventoryItem(item[i].db_name, item[i].add)
							end
						end
					else
						if CheckJobLimit(source, item[i].price) == true then
							xPlayer.addMoney(item[i].price)
						elseif CheckJobLimit(source, item[i].price) == false then
							TriggerClientEvent('esx:showNotification', source, "Günlük limitine ulaştın!")
							return
						end
					end
				end
			end

			if item[1].requires ~= "nothing" then
				local itemToRemoveQtty = xPlayer.getInventoryItem(item[1].requires).count
				if itemToRemoveQtty > 0 then
					xPlayer.removeInventoryItem(item[1].requires, item[1].remove)
				end
			end

			Work(source, item)

		end
	end)
end

function ResetJobLimits()
    local sqlresult = MySQL.Sync.fetchAll("SELECT * FROM characters")

    for i = 1, #sqlresult, 1 do
        MySQL.Async.execute("UPDATE characters SET joblimit = @joblimit WHERE identifier = @identifier", {
            ["@joblimit"] = 0,
            ["@identifier"] = sqlresult[i].identifier
        })
    end
    print("^1Meslek limitleri sıfırlandı.^0")
end

function CheckJobLimit(source, amount)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local result = MySQL.Sync.fetchAll("SELECT joblimit FROM characters WHERE identifier = @identifier", {
        ["@identifier"] = xPlayer.identifier,
	})

    if result[1].joblimit >= limit then -- limit sayısı
    	return false
    else
        MySQL.Async.execute("UPDATE characters SET joblimit = @joblimit WHERE identifier = @identifier", {
            ["@joblimit"] = result[1].joblimit + amount, -- günlük limiti aşmayıp satış yaptığı için sql de o kişinin satışını arttırma
            ["@identifier"] = xPlayer.identifier
        })
        return true
    end
end

RegisterServerEvent('esx_jobs:startWork')
AddEventHandler('esx_jobs:startWork', function(item)
	if not PlayersWorking[source] then
		PlayersWorking[source] = true
		Work(source, item)
	else
		print(('esx_jobs: %s attempted to exploit the marker!'):format(GetPlayerIdentifiers(source)[1]))
	end
end)

RegisterServerEvent('esx_jobs:stopWork')
AddEventHandler('esx_jobs:stopWork', function()
	PlayersWorking[source] = false
end)

RegisterServerEvent('esx_jobs:caution')
AddEventHandler('esx_jobs:caution', function(cautionType, cautionAmount, spawnPoint, vehicle)
	local xPlayer = ESX.GetPlayerFromId(source)

	if cautionType == "take" then
		TriggerEvent('esx_addonaccount:getAccount', 'caution', xPlayer.identifier, function(account)
			xPlayer.removeAccountMoney('bank', cautionAmount)
			account.addMoney(cautionAmount)
		end)

		TriggerClientEvent('esx:showNotification', source, _U('bank_deposit_taken', ESX.Math.GroupDigits(cautionAmount)))
		TriggerClientEvent('esx_jobs:spawnJobVehicle', source, spawnPoint, vehicle)
	elseif cautionType == "give_back" then

		if cautionAmount > 1 then
			print(('esx_jobs: %s is using cheat engine!'):format(xPlayer.identifier))
			return
		end

		TriggerEvent('esx_addonaccount:getAccount', 'caution', xPlayer.identifier, function(account)
			local caution = account.money
			local toGive = ESX.Math.Round(caution * cautionAmount)

			xPlayer.addAccountMoney('bank', toGive)
			account.removeMoney(toGive)
			TriggerClientEvent('esx:showNotification', source, _U('bank_deposit_returned', ESX.Math.GroupDigits(toGive)))
		end)
	end
end)

TriggerEvent('cron:runAt', 24, 0, ResetJobLimits)