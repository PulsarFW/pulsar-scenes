_expirationThread = false

_loadedScenes = {}
_hasLoadedScenes = false

_spamCheck = {}

local _tableReady = false
local function ensureScenesTable(callback)
	if _tableReady then
		if callback then
			callback()
		end
		return
	end
	plsr.Database:Query(
		"CREATE TABLE IF NOT EXISTS `scenes` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `staff` TINYINT(1) NOT NULL DEFAULT 0, `expires` BIGINT NULL, `route` INT NOT NULL DEFAULT 0, `data` JSON NOT NULL, INDEX `idx_cleanup` (`staff`, `expires`), INDEX `idx_route` (`route`))",
		nil,
		function()
			_tableReady = true
			if callback then
				callback()
			end
		end
	)
end

CreateThread(function()
	LoadScenesFromDB()
	StartExpirationThread()

	plsr.Callbacks:RegisterServerCallback("Scenes:Create", function(source, data, cb)
		local player = plsr.Fetch:Source(source)
		local timeStamp = GetGameTimer()

		if _spamCheck[source] and (timeStamp < _spamCheck[source]) and not player.Permissions:IsStaff() then
			return cb(false)
		end

		if player and data.scene and data.data then
			local wasCreated = plsr.Scenes:Create(data.scene, data.data.staff and player.Permissions:IsStaff())
			if wasCreated then
				_spamCheck[source] = timeStamp + 3500
			end
			cb(wasCreated)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Scenes:Delete", function(source, sceneId, cb)
		local player = plsr.Fetch:Source(source)
		local scene = _loadedScenes[sceneId]
		local timeStamp = GetGameTimer()

		if _spamCheck[source] and (timeStamp < _spamCheck[source]) and not player.Permissions:IsStaff() then
			return cb(false)
		end

		if scene and player then
			if scene.staff and not player.Permissions:IsStaff() then
				return cb(false, true)
			end

			_spamCheck[source] = timeStamp + 5000

			cb(plsr.Scenes:Delete(sceneId))
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Scenes:CanEdit", function(source, sceneId, cb)
		local player = plsr.Fetch:Source(source)
		local scene = _loadedScenes[sceneId]
		local timeStamp = GetGameTimer()

		if _spamCheck[source] and (timeStamp < _spamCheck[source]) and not player.Permissions:IsStaff() then
			return cb(false, false)
		end

		if scene and player then
			if scene.staff and not player.Permissions:IsStaff() then
				return cb(false, player.Permissions:IsStaff())
			end

			_spamCheck[source] = timeStamp + 5000

			cb(true, player.Permissions:IsStaff())
		else
			cb(false, false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Scenes:Edit", function(source, data, cb)
		local player = plsr.Fetch:Source(source)
		local scene = _loadedScenes[data.id]
		local timeStamp = GetGameTimer()

		if _spamCheck[source] and (timeStamp < _spamCheck[source]) and not player.Permissions:IsStaff() then
			return cb(false)
		end

		if scene and player then
			_spamCheck[source] = timeStamp + 5000

			cb(plsr.Scenes:Edit(data.id, data.scene, player.Permissions:IsStaff()))
		else
			cb(false)
		end
	end)

	plsr.Middleware:Add("Characters:Spawning", function(source)
		TriggerClientEvent("Scenes:Client:RecieveScenes", source, _loadedScenes)
	end, 5)

	plsr.Chat:RegisterCommand("scene", function(source, args, rawCommand)
		TriggerClientEvent("Scenes:Client:Creation", source, args)
	end, {
		help = "Create a Scene (Look Where You Want to Place)",
	})

	plsr.Chat:RegisterStaffCommand("scenestaff", function(source, args, rawCommand)
		TriggerClientEvent("Scenes:Client:Creation", source, args, true)
	end, {
		help = "[Staff] Create a Scene (Look Where You Want to Place)",
	})

	plsr.Chat:RegisterCommand("scenedelete", function(source, args, rawCommand)
		TriggerClientEvent("Scenes:Client:Deletion", source)
	end, {
		help = "Delete a Scene (Look at Scene You Want to Delete)",
	})

	plsr.Chat:RegisterCommand("sceneedit", function(source, args, rawCommand)
		TriggerClientEvent("Scenes:Client:StartEdit", source)
	end, {
		help = "Edit a Scene (Look at Scene You Want to Edit)",
	})
end)

AddEventHandler("Characters:Server:PlayerDropped", function(source, message)
	_spamCheck[source] = nil
end)

_SCENES = {
	Create = function(self, scene, isStaff)
		if scene and scene.coords then
			scene.coords = {
				x = scene.coords.x,
				y = scene.coords.y,
				z = scene.coords.z,
			}

			if not scene.length and not isStaff then
				return false
			end

			if scene.length then
				if scene.length > 24 then
					scene.length = 24
				elseif scene.length < 1 then
					scene.length = 1
				end

				scene.expires = os.time() + (3600 * scene.length)
				scene.staff = false
			else
				scene.expires = false
				scene.staff = true
			end

			if type(scene.distance) ~= "number" or scene.distance > 10.0 or scene.distance < 1.0 then
				scene.distance = 7.5
			end
			
            scene.text.text = SanitizeEmojis(scene.text.text)

			local p = promise.new()
			ensureScenesTable(function()
				plsr.Database:Insert(
					"INSERT INTO `scenes` (`staff`, `expires`, `route`, `data`) VALUES (?, ?, ?, ?)",
					{ scene.staff and 1 or 0, scene.expires or nil, scene.route or 0, json.encode(scene) },
					function(success, newId)
						if success then
							scene._id = newId
							p:resolve(scene)
							_loadedScenes[scene._id] = scene
							TriggerClientEvent("Scenes:Client:AddScene", -1, scene._id, scene)
						else
							p:resolve(false)
						end
					end
				)
			end)

			return Citizen.Await(p)
		end
	end,
	Edit = function(self, id, newData, isStaff)
		if newData and newData.coords then
			newData.coords = {
				x = newData.coords.x,
				y = newData.coords.y,
				z = newData.coords.z,
			}

			if not newData.length and not isStaff then
				return false
			end

			if newData.length then
				if newData.length > 24 then
					newData.length = 24
				elseif newData.length < 1 then
					newData.length = 1
				end

				newData.expires = os.time() + (3600 * newData.length)
				newData.staff = false
			else
				newData.expires = false
				newData.staff = true
			end

			if type(newData.distance) ~= "number" or newData.distance > 10.0 or newData.distance < 1.0 then
				newData.distance = 7.5
			end

			newData._id = nil

			local p = promise.new()
			ensureScenesTable(function()
				-- Mongo's `$set` only overwrites the given top-level keys, leaving the rest of the
				-- stored document untouched; fetch+merge here reproduces that for the `data` blob.
				plsr.Database:Single("SELECT `data` FROM `scenes` WHERE `id` = ?", { id }, function(success, row)
					if not success or row == nil then
						p:resolve(false)
						return
					end

					local ok, existing = pcall(json.decode, row.data)
					if not ok or type(existing) ~= "table" then
						existing = {}
					end
					for k, v in pairs(newData) do
						existing[k] = v
					end

					plsr.Database:Update(
						"UPDATE `scenes` SET `staff` = ?, `expires` = ?, `route` = ?, `data` = ? WHERE `id` = ?",
						{ newData.staff and 1 or 0, newData.expires or nil, existing.route or 0, json.encode(existing), id },
						function(updateSuccess)
							if updateSuccess then
								newData._id = id
								p:resolve(newData)
								_loadedScenes[id] = newData
								TriggerClientEvent("Scenes:Client:AddScene", -1, newData._id, newData)
							else
								p:resolve(false)
							end
						end
					)
				end)
			end)

			return Citizen.Await(p)
		end
	end,
	Delete = function(self, id)
		local p = promise.new()
		ensureScenesTable(function()
			plsr.Database:Update("DELETE FROM `scenes` WHERE `id` = ?", { id }, function(success)
				p:resolve(success)

				if success and _loadedScenes[id] then
					_loadedScenes[id] = nil
					TriggerClientEvent("Scenes:Client:RemoveScene", -1, id)
				end
			end)
		end)

		return Citizen.Await(p)
	end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Scenes", _SCENES)
end)

function DeleteExpiredScenes(deleteRouted)
	local p = promise.new()

	local sql = "DELETE FROM `scenes` WHERE `staff` = 0 AND `expires` <= ?"
	if deleteRouted then -- Delete Routed
		sql = "DELETE FROM `scenes` WHERE (`staff` = 0 AND `expires` <= ?) OR `route` <> 0"
	end

	ensureScenesTable(function()
		plsr.Database:Update(sql, { os.time() }, function(success, deleted)
			if success then
				p:resolve(deleted)
			else
				p:resolve(false)
			end
		end)
	end)

	return Citizen.Await(p)
end

function LoadScenesFromDB()
	if not _hasLoadedScenes then
		_hasLoadedScenes = true
		DeleteExpiredScenes(true)

		ensureScenesTable(function()
			plsr.Database:Query("SELECT `id`, `data` FROM `scenes`", nil, function(success, results)
				if success and results and #results > 0 then
					for k, row in ipairs(results) do
						local ok, decoded = pcall(json.decode, row.data)
						if ok and type(decoded) == "table" then
							decoded._id = row.id
							_loadedScenes[row.id] = decoded
						end
					end
				end
			end)
		end)
	end
end

function StartExpirationThread()
	if not _expirationThread then
		_expirationThread = true

		CreateThread(function()
			while true do
				Wait(60 * 1000 * 30)
				if _hasLoadedScenes then
					local deleteScenes = {}
					local timeStamp = os.time()

					for k, v in pairs(_loadedScenes) do
						if v.expires and timeStamp >= v.expires then
							if plsr.Scenes:Delete(v._id) then
								table.insert(deleteScenes, v._id)
							end
						end
					end

					TriggerClientEvent("Scenes:Client:RemoveScenes", -1, deleteScenes)
				end
			end
		end)
	end
end
