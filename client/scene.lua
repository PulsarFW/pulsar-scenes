function DrawScene(sceneData)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(sceneData.coords.x, sceneData.coords.y, sceneData.coords.z)
    if onScreen then
        local pedCoords = GetEntityCoords(PlayerPedId())

        local dist = #(GetGameplayCamCoord() - sceneData.coords)
        local scale = ((1 / dist) * 2) * (1 / GetGameplayCamFov()) * 80
        local rangeAlpha = 10 * math.floor(scale * 40)
        if rangeAlpha > 225 then
            rangeAlpha = 225
        elseif rangeAlpha < 40 then
            rangeAlpha = 40
        end

        local fontData = _sceneFonts[sceneData.text.font]
        if fontData.file then
            -- streamed .gfx fonts get evicted if nothing keeps re-requesting them; re-pin every draw
            RegisterFontFile(fontData.file)
        end

        SetTextColour(sceneData.text.color.r, sceneData.text.color.g, sceneData.text.color.b, rangeAlpha)
		SetTextScale(0.0 * scale, sceneData.text.size * scale)
		SetTextFont(fontData.font)
		SetTextProportional(1)
		SetTextCentre(true)
		SetTextWrap(0.0, 1.0)

        if sceneData.text.outline == 'outline' then
            SetTextOutline()
        elseif sceneData.text.outline == 'shadow' then
            SetTextDropshadow(1, 255, 255, 255, 0)
        end

        local longText = string.len(sceneData.text.text) > 99

        BeginTextCommandWidth("THREESTRINGS")
		AddTextComponentString(sceneData.text.text)
        if longText then
            HandleLongString(sceneData.text.text)
        end

        local textHeight = GetTextScaleHeight(sceneData.text.size * scale, fontData.font)
		local textWidth = EndTextCommandGetWidth(fontData.font)

        SetTextEntry("THREESTRINGS")
		AddTextComponentString(sceneData.text.text)
		if longText then
			HandleLongString(sceneData.text.text)
		end

        EndTextCommandDisplayText(x, y)

        if sceneData.background and sceneData.background.type > 0 then
            if rangeAlpha > sceneData.background.opacity then
                rangeAlpha = sceneData.background.opacity
            end

            -- same eviction issue as streamed fonts: re-pin every draw or the dict can drop out
            RequestStreamedTextureDict('arpscenes', true)

            DrawSprite(
                'arpscenes',
                _sceneBackgrounds[sceneData.background.type].sprite,
                x + sceneData.background.x * scale,
                y + (sceneData.background.y + 0.01) * scale,
                textWidth + sceneData.background.w * scale,
                textHeight + sceneData.background.h * scale,
                sceneData.background.rotation + 0.0,
                sceneData.background.color.r,
                sceneData.background.color.g,
                sceneData.background.color.b,
                rangeAlpha
            )
        end
    end
end