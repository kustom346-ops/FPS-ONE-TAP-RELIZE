local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Qanuir/orion-ui/refs/heads/main/source.lua"))()

local Window = OrionLib:MakeWindow({
    Name = "SLAUGHTER",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "SlaughterConfig",
    Size = UDim2.fromOffset(600, 500)
})

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local Settings = {
    AimBotEnabled = false,
    AimSmoothness = 1,
    AutoFireEnabled = false,
    AimPart = "Head",
    SilentEnabled = false,
    SilentPart = "Hitbox_Head",
    RapidFireConstantsEnabled = false,
    RapidFireSpamEnabled = false,
    BulletsPerShot = 10,
    UltraAnimations = false,
    FOV = 200,
    VisibleCheckEnabled = true,
    MaxTargetDistance = 1000,
    ESPEnabled = false,
    ESPColor = Color3.fromRGB(255, 0, 0),
    HitboxEnabled = false,
    HitboxSize = 10.0,
    HitboxTransparency = 0.7,
    NightModeEnabled = false,
    NightIntensity = -0.2,
    NightSaturation = -0.3,
    NightTint = Color3.fromRGB(100, 120, 180),
    CurrentWeather = "None",
    CurrentTime = "None",
    FogEnd = 1000,
    FogColor = Color3.fromRGB(192, 192, 192),
    -- Halloween
    HalloweenEnabled = false,
    HalloweenIntensity = 0.6,
    HalloweenTint = Color3.fromRGB(255, 90, 0),
    PumpkinsEnabled = false,
    BatsEnabled = false,
    VignetteEnabled = false
}

local ESPObjects = {}
local WeaponConstants = nil
local OriginalHitboxes = {}

-- Визуальные эффекты
local nightModeCC = Instance.new("ColorCorrectionEffect")
nightModeCC.Name = "SlaughterNightMode"
nightModeCC.Brightness = Settings.NightIntensity
nightModeCC.Contrast = 0.1
nightModeCC.Saturation = Settings.NightSaturation
nightModeCC.TintColor = Settings.NightTint
nightModeCC.Enabled = false
nightModeCC.Parent = Lighting

local weatherFolder = Instance.new("Folder", Workspace)
weatherFolder.Name = "SlaughterWeather"

local sky = Instance.new("Sky", Lighting)
sky.Name = "SlaughterSky"

local sunRays = Instance.new("SunRaysEffect", Lighting)
sunRays.Name = "SlaughterSunRays"
sunRays.Intensity = 0.1
sunRays.Spread = 0.5

-- Звук дождя
local rainSound = Instance.new("Sound")
rainSound.SoundId = "rbxassetid://9112966288"
rainSound.Looped = true
rainSound.Volume = 0.5
rainSound.Parent = SoundService

-- [HALLOWEEN VISUAL]
local halloweenCC = Instance.new("ColorCorrectionEffect")
halloweenCC.Name = "SlaughterHalloweenCC"
halloweenCC.Brightness = -0.05
halloweenCC.Contrast = 0.2
halloweenCC.Saturation = -0.2
halloweenCC.TintColor = Color3.fromRGB(255, 90, 0)
halloweenCC.Enabled = false
halloweenCC.Parent = Lighting

local halloweenBlur = Instance.new("BlurEffect")
halloweenBlur.Name = "SlaughterHalloweenBlur"
halloweenBlur.Size = 0
halloweenBlur.Enabled = false
halloweenBlur.Parent = Lighting

-- Виньетка (чистая, без внешнего ассета — рисуем градиентом через UIGradient)
local halloweenVignette = Instance.new("Frame")
halloweenVignette.Name = "SlaughterVignette"
halloweenVignette.Size = UDim2.fromScale(1, 1)
halloweenVignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
halloweenVignette.BackgroundTransparency = 0.25
halloweenVignette.BorderSizePixel = 0
halloweenVignette.ZIndex = 10
halloweenVignette.Visible = false
halloweenVignette.Parent = game:GetService("CoreGui")

local vignetteGradient = Instance.new("UIGradient", halloweenVignette)
vignetteGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.5, 1),
    NumberSequenceKeypoint.new(1, 0)
})
vignetteGradient.Rotation = 90

-- Папка для хеллоуин-декора
local halloweenFolder = Instance.new("Folder", Workspace)
halloweenFolder.Name = "SlaughterHalloween"

-- Тыквы (чисто неон + PointLight + глаза/рот из частей — без ассетов)
local pumpkinCache = {}

local function spawnPumpkin()
    local model = Instance.new("Model")
    model.Name = "Pumpkin"

    local body = Instance.new("Part")
    body.Shape = Enum.PartType.Ball
    body.Size = Vector3.new(4, 4, 4)
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.Neon
    body.Color = Color3.fromRGB(255, 110, 0)
    body.Transparency = 0.1
    body.Parent = model

    local light = Instance.new("PointLight", body)
    light.Color = Color3.fromRGB(255, 120, 0)
    light.Range = 18
    light.Brightness = 2.5

    -- Глаза и рот (тёмные части)
    local function makeFacePart(size, offset)
        local p = Instance.new("Part")
        p.Size = size
        p.Anchored = true
        p.CanCollide = false
        p.Material = Enum.Material.SmoothPlastic
        p.Color = Color3.fromRGB(20, 0, 0)
        p.Transparency = 0.05
        p.Parent = model
        p.CFrame = body.CFrame * CFrame.new(offset)
        return p
    end

    makeFacePart(Vector3.new(0.7, 0.9, 0.1), Vector3.new(-0.9, 0.6, -1.95))
    makeFacePart(Vector3.new(0.7, 0.9, 0.1), Vector3.new(0.9, 0.6, -1.95))
    makeFacePart(Vector3.new(1.6, 0.4, 0.1), Vector3.new(0, -0.5, -1.95))

    model.PrimaryPart = body
    model.Parent = halloweenFolder
    table.insert(pumpkinCache, model)
end

local function clearPumpkins()
    for _, m in ipairs(pumpkinCache) do
        if m and m.Parent then m:Destroy() end
    end
    pumpkinCache = {}
end

-- Летучие мыши (неон-части вместо ассета)
local bats = {}

local function spawnBat()
    local model = Instance.new("Model")
    model.Name = "Bat"

    local body = Instance.new("Part")
    body.Size = Vector3.new(0.6, 0.4, 0.6)
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.Neon
    body.Color = Color3.fromRGB(40, 0, 40)
    body.Transparency = 0.15
    body.Parent = model

    local wingL = Instance.new("Part")
    wingL.Size = Vector3.new(1.4, 0.05, 0.7)
    wingL.Anchored = true
    wingL.CanCollide = false
    wingL.Material = Enum.Material.Neon
    wingL.Color = Color3.fromRGB(60, 0, 60)
    wingL.Transparency = 0.2
    wingL.Parent = model

    local wingR = wingL:Clone()
    wingR.Parent = model

    local light = Instance.new("PointLight", body)
    light.Color = Color3.fromRGB(150, 0, 200)
    light.Range = 10
    light.Brightness = 1.5

    model.PrimaryPart = body
    model.Parent = halloweenFolder
    table.insert(bats, { model = model, body = body, wingL = wingL, wingR = wingR, phase = math.random() * math.pi * 2 })
end

local function clearBats()
    for _, b in ipairs(bats) do
        if b.model and b.model.Parent then b.model:Destroy() end
    end
    bats = {}
end

local function updateHalloween(state)
    Settings.HalloweenEnabled = state
    halloweenCC.Enabled = state
    halloweenBlur.Enabled = state
    if not state then
        clearPumpkins()
        clearBats()
        halloweenVignette.Visible = false
    end
end

-- Оригинальные настройки
local OriginalLighting = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    FogColor = Lighting.FogColor,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

-- [TIME CHANGER ЛОГИКА]
local function setTimeOfDay(timeName)
    Settings.CurrentTime = timeName
    if timeName == "None" then
        Lighting.ClockTime = OriginalLighting.ClockTime
        sunRays.Enabled = false
        sky.SkyboxBk = ""
        sky.SkyboxDn = ""
        sky.SkyboxFt = ""
        sky.SkyboxLf = ""
        sky.SkyboxRt = ""
        sky.SkyboxUp = ""
        sky.SunAngularSize = 21
        sky.MoonAngularSize = 11
        Lighting.GlobalShadows = true
        Lighting.ShadowSoftness = 0.3
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        return
    end

    sunRays.Enabled = true
    Lighting.GlobalShadows = true
    
    if timeName == "Morning" then
        Lighting.ClockTime = 6
        sunRays.Intensity = 0.1
        sunRays.Spread = 0.5
        Lighting.Brightness = 1.5
        Lighting.EnvironmentDiffuseScale = 0.1
        Lighting.EnvironmentSpecularScale = 0.1
        sky.SkyboxBk = "rbxassetid://1018282809"
        sky.SkyboxDn = "rbxassetid://1018282809"
        sky.SkyboxFt = "rbxassetid://1018282809"
        sky.SkyboxLf = "rbxassetid://1018282809"
        sky.SkyboxRt = "rbxassetid://1018282809"
        sky.SkyboxUp = "rbxassetid://1018282809"
    elseif timeName == "Day" then
        Lighting.ClockTime = 14
        sunRays.Intensity = 0.05
        sunRays.Spread = 0.8
        Lighting.Brightness = 3
        Lighting.EnvironmentDiffuseScale = 0.2
        Lighting.EnvironmentSpecularScale = 0.2
        sky.SkyboxBk = "rbxassetid://1018282809"
        sky.SkyboxDn = "rbxassetid://1018282809"
        sky.SkyboxFt = "rbxassetid://1018282809"
        sky.SkyboxLf = "rbxassetid://1018282809"
        sky.SkyboxRt = "rbxassetid://1018282809"
        sky.SkyboxUp = "rbxassetid://1018282809"
    elseif timeName == "Evening" then
        Lighting.ClockTime = 18
        sunRays.Intensity = 0.2
        sunRays.Spread = 1.0
        Lighting.Brightness = 1.0
        Lighting.EnvironmentDiffuseScale = 0.1
        Lighting.EnvironmentSpecularScale = 0.1
        sky.SkyboxBk = "rbxassetid://1018282809"
        sky.SkyboxDn = "rbxassetid://1018282809"
        sky.SkyboxFt = "rbxassetid://1018282809"
        sky.SkyboxLf = "rbxassetid://1018282809"
        sky.SkyboxRt = "rbxassetid://1018282809"
        sky.SkyboxUp = "rbxassetid://1018282809"
    elseif timeName == "Night" then
        Lighting.ClockTime = 0
        sunRays.Enabled = false
        Lighting.Brightness = 0.2
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        sky.SkyboxBk = "rbxassetid://1018282809"
        sky.SkyboxDn = "rbxassetid://1018282809"
        sky.SkyboxFt = "rbxassetid://1018282809"
        sky.SkyboxLf = "rbxassetid://1018282809"
        sky.SkyboxRt = "rbxassetid://1018282809"
        sky.SkyboxUp = "rbxassetid://1018282809"
    end
end

-- [WEATHER CHANGER ЛОГИКА]
local function clearWeather()
    for _, v in ipairs(weatherFolder:GetChildren()) do
        v:Destroy()
    end
    rainSound:Stop()
end

local function setWeather(weatherName)
    Settings.CurrentWeather = weatherName
    clearWeather()

    if weatherName == "None" then return end

    -- Создаем часть для эмиттера, которая будет следовать за камерой
    local emitterPart = Instance.new("Part")
    emitterPart.Size = Vector3.new(10, 10, 10)
    emitterPart.Transparency = 1
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Parent = weatherFolder

    if weatherName == "Rain" then
        Lighting.FogEnd = 500
        Lighting.FogColor = Color3.fromRGB(150, 150, 150)
        
        -- Звук дождя
        rainSound:Play()
        
        local rainEmitter = Instance.new("ParticleEmitter")
        rainEmitter.Texture = "rbxassetid://241876428"
        rainEmitter.Rate = 3000
        rainEmitter.Lifetime = NumberRange.new(0.5, 1)
        rainEmitter.Speed = NumberRange.new(100, 150)
        rainEmitter.Acceleration = Vector3.new(0, -100, 0) -- Ускорение вниз
        rainEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 0.1)
        })
        rainEmitter.Rotation = NumberRange.new(0, 360)
        rainEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 255))
        rainEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 0.8)
        })
        rainEmitter.Parent = emitterPart

    elseif weatherName == "Snow" then
        Lighting.FogEnd = 800
        Lighting.FogColor = Color3.fromRGB(200, 200, 200)
        
        local snowEmitter = Instance.new("ParticleEmitter")
        snowEmitter.Texture = "rbxassetid://241876428"
        snowEmitter.Rate = 2000
        snowEmitter.Lifetime = NumberRange.new(3, 5)
        snowEmitter.Speed = NumberRange.new(5, 10)
        snowEmitter.Acceleration = Vector3.new(0, -5, 0) -- Мягкое падение
        snowEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 0.5)
        })
        snowEmitter.Rotation = NumberRange.new(0, 360)
        snowEmitter.RotSpeed = NumberRange.new(-20, 20)
        snowEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        snowEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0.9)
        })
        snowEmitter.Parent = emitterPart
    end

    -- Двигаем эмиттер за игроком (вокруг камеры)
    task.spawn(function()
        while Settings.CurrentWeather == weatherName do
            if emitterPart and emitterPart.Parent then
                emitterPart.Position = Camera.CFrame.Position + Vector3.new(0, 30, 0)
            end
            task.wait(0.05)
        end
    end)
end

-- [FOG CHANGER ЛОГИКА]
local function setFog()
    if Settings.NightModeEnabled then return end
    Lighting.FogEnd = Settings.FogEnd
    Lighting.FogColor = Settings.FogColor
end

local function updateNightMode(state)
    if state then
        nightModeCC.Enabled = true
        Lighting.Ambient = Color3.fromRGB(15, 15, 25)
        Lighting.OutdoorAmbient = Color3.fromRGB(30, 30, 50)
        Lighting.Brightness = 0.5
    else
        nightModeCC.Enabled = false
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
        Lighting.Brightness = OriginalLighting.Brightness
    end
end

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.NumSides = 60
fovCircle.Filled = false
fovCircle.Color = Color3.fromRGB(255, 0, 0)
fovCircle.Transparency = 1
fovCircle.Visible = false

RunService.RenderStepped:Connect(function()
    if Settings.AimBotEnabled or Settings.SilentEnabled or Settings.RapidFireSpamEnabled or Settings.RapidFireConstantsEnabled then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Radius = Settings.FOV
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
end)

-- [HALLOWEEN ANIMATION]
RunService.RenderStepped:Connect(function(dt)
    if not Settings.HalloweenEnabled then return end

    local camPos = Camera.CFrame.Position

    -- Виньетка
    halloweenVignette.Visible = Settings.VignetteEnabled
    if Settings.VignetteEnabled then
        halloweenVignette.BackgroundTransparency = 0.55 - (0.25 * Settings.HalloweenIntensity)
    end

    -- Тыквы
    if Settings.PumpkinsEnabled and #pumpkinCache < 8 then
        spawnPumpkin()
    end
    for i, m in ipairs(pumpkinCache) do
        if m.Parent and m.PrimaryPart then
            local t = tick() * 0.6 + i * 1.7
            local radius = 18 + math.sin(t) * 4
            m:SetPrimaryPartCFrame(CFrame.new(camPos + Vector3.new(
                math.cos(t) * radius,
                2 + math.sin(t * 1.3) * 2,
                math.sin(t) * radius
            )))
        end
    end

    -- Летучие мыши
    if Settings.BatsEnabled and #bats < 14 then
        spawnBat()
    end
    for i, b in ipairs(bats) do
        if b.model.Parent then
            local t = tick() * 1.4 + b.phase
            local pos = camPos + Vector3.new(
                math.sin(t) * 25,
                8 + math.sin(t * 2) * 5,
                math.cos(t * 1.4) * 25
            )
            b.model:PivotTo(CFrame.lookAt(pos, camPos))
            -- Взмах крыльев
            local flap = math.sin(tick() * 12 + b.phase) * 0.6
            b.wingL.CFrame = b.body.CFrame * CFrame.new(-0.9, 0, 0) * CFrame.Angles(0, 0, flap)
            b.wingR.CFrame = b.body.CFrame * CFrame.new(0.9, 0, 0) * CFrame.Angles(0, 0, -flap)
        end
    end
end)

-- Обновление интенсивности
RunService.Heartbeat:Connect(function()
    if not Settings.HalloweenEnabled then return end
    halloweenCC.Brightness = -0.05 * Settings.HalloweenIntensity
    halloweenCC.TintColor = Settings.HalloweenTint
    halloweenBlur.Size = 2 * Settings.HalloweenIntensity
end)

local function getPlayerCharacterSet()
    local set = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            set[player.Character] = true
        end
    end
    if LocalPlayer.Character then
        set[LocalPlayer.Character] = true
    end
    return set
end

local function createESP(model)
    if not model or not model:IsA("Model") or not model:FindFirstChild("Humanoid") then return end
    if ESPObjects[model] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "SlaughterESP"
    highlight.Adornee = model
    highlight.FillColor = Settings.ESPColor
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Settings.ESPColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = model

    ESPObjects[model] = highlight
end

local function updateESP()
    if not Settings.ESPEnabled then return end

    local playerSet = getPlayerCharacterSet()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            createESP(player.Character)
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model")
           and obj:FindFirstChild("Humanoid")
           and not playerSet[obj]
           and obj ~= LocalPlayer.Character then
            createESP(obj)
        end
    end

    for model, highlight in pairs(ESPObjects) do
        if not model.Parent or not highlight.Parent then
            if highlight and highlight.Parent then highlight:Destroy() end
            ESPObjects[model] = nil
        end
    end
end

local function clearAllESP()
    for model, highlight in pairs(ESPObjects) do
        if highlight and highlight.Parent then highlight:Destroy() end
    end
    ESPObjects = {}
end

local function isVisible(targetPart, targetModel)
    if not Settings.VisibleCheckEnabled then return true end

    local localChar = LocalPlayer.Character
    if not localChar then return false end

    local origin = Camera.CFrame.Position
    local delta = targetPart.Position - origin

    if delta.Magnitude > Settings.MaxTargetDistance then return false end

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {localChar, targetModel}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local ray = Workspace:Raycast(origin, delta, rayParams)
    return ray == nil
end

local targetCache = { part = nil, time = 0, result = nil }

local function getBestTarget(targetPartName)
    local now = tick()
    if targetCache.part == targetPartName and (now - targetCache.time) < 0.016 then
        return targetCache.result
    end

    local closest = nil
    local shortestDist = Settings.FOV
    local localChar = LocalPlayer.Character
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then
        targetCache.part = targetPartName
        targetCache.time = now
        targetCache.result = nil
        return nil
    end

    local playerSet = getPlayerCharacterSet()

    local function checkTarget(targetPart, targetModel)
        if not targetPart or not targetPart.Parent then return end
        if targetModel == LocalPlayer.Character then return end
        if targetPart:IsDescendantOf(LocalPlayer.Character) then return end
        local humanoid = targetModel:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then return end

        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
            if dist < shortestDist then
                if isVisible(targetPart, targetModel) then
                    shortestDist = dist
                    closest = targetPart
                end
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild(targetPartName) or player.Character:FindFirstChild("HumanoidRootPart")
            checkTarget(targetPart, player.Character)
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not playerSet[obj] then
            local targetPart = obj:FindFirstChild(targetPartName) or obj:FindFirstChild("HumanoidRootPart")
            checkTarget(targetPart, obj)
        end
    end

    targetCache.part = targetPartName
    targetCache.time = now
    targetCache.result = closest
    return closest
end

local function findWeaponConstants()
    if WeaponConstants then return WeaponConstants end
    for _, obj in pairs(getgc(true)) do
        if type(obj) == "table" then
            if obj.Constants and obj.Constants.DEFAULT_FIRERATE then
                WeaponConstants = obj.Constants
                return WeaponConstants
            end
        end
    end
    return nil
end

local function setRapidFireConstants(state)
    local constants = findWeaponConstants()
    if not constants then return end

    if state then
        constants.DEFAULT_FIRERATE = 0
        constants.DEFAULT_PISTOL_FIRERATE = 0
        constants.DEFAULT_RELOAD_TIME = 0
        constants.DEFAULT_PISTOL_RELOAD_TIME = 0
        constants.DEFAULT_MAGAZINE = 999999
    else
        constants.DEFAULT_FIRERATE = 2
        constants.DEFAULT_PISTOL_FIRERATE = 4
        constants.DEFAULT_RELOAD_TIME = 0.75
        constants.DEFAULT_PISTOL_RELOAD_TIME = 0.5
        constants.DEFAULT_MAGAZINE = 1
    end
end

local function speedUpAnimations()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animName = track.Animation and track.Animation.Name:lower() or ""
        if animName:find("reload") or animName:find("fire") or animName:find("bolt") or animName:find("shoot") or animName:find("primary") then
            track:AdjustSpeed(1000)
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if Settings.UltraAnimations then
            speedUpAnimations()
        end
    end
end)

local function hookFastCast()
    local success, FastCastRedux = pcall(function()
        return require(Workspace.Parent.ReplicatedStorage.Common.Components.FastCastRedux)
    end)

    if not success or not FastCastRedux then return false end

    local originalFire = FastCastRedux.Fire or (FastCastRedux.ActiveCast and FastCastRedux.ActiveCast.Fire)
    if not originalFire then return false end

    local newFire = function(self, origin, direction, ...)
        local extraArgs = table.pack(...)

        local isLocalShot = false
        if origin then
            local distToCamera = (origin - Camera.CFrame.Position).Magnitude
            if distToCamera < 25 then isLocalShot = true end
        end

        if isLocalShot then
            if Settings.SilentEnabled then
                local target = getBestTarget(Settings.SilentPart)
                if target then
                    origin = Camera.CFrame.Position
                    direction = (target.Position - origin).Unit
                end
            end

            if Settings.RapidFireSpamEnabled then
                task.spawn(function()
                    for i = 1, Settings.BulletsPerShot do
                        if not Settings.RapidFireSpamEnabled then break end
                        originalFire(self, origin, direction, table.unpack(extraArgs, 1, extraArgs.n))
                        task.wait(0.05)
                    end
                end)
                return
            end
        end

        return originalFire(self, origin, direction, table.unpack(extraArgs, 1, extraArgs.n))
    end

    if FastCastRedux.Fire then FastCastRedux.Fire = newFire
    elseif FastCastRedux.ActiveCast then FastCastRedux.ActiveCast.Fire = newFire end
    return true
end

task.spawn(function()
    while not hookFastCast() do task.wait(2) end
end)

local aimConnection = nil
local lastFireTime = 0

local function getAngleDelta(fromCF, toCF)
    local dot = math.clamp(fromCF.LookVector:Dot(toCF.LookVector), -1, 1)
    return math.deg(math.acos(dot))
end

local function aimAt(target, dt)
    local desired = CFrame.new(Camera.CFrame.Position, target.Position)

    if Settings.AimSmoothness <= 0 then
        Camera.CFrame = desired
        return
    end

    local speedDegPerSec = 720 / Settings.AimSmoothness
    local angle = getAngleDelta(Camera.CFrame, desired)
    if angle < 0.1 then
        Camera.CFrame = desired
        return
    end

    local step = math.clamp((speedDegPerSec * dt) / angle, 0, 1)
    Camera.CFrame = Camera.CFrame:Lerp(desired, step)
end

local function smartAutoFire(aimTarget)
    if not Settings.AutoFireEnabled then return end
    if not aimTarget then return end

    local now = tick()
    if now - lastFireTime < 0.1 then return end

    local screenPos, onScreen = Camera:WorldToViewportPoint(aimTarget.Position)
    if not onScreen then return end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    if (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude > 50 then return end

    lastFireTime = now
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function startAimBot()
    if aimConnection then aimConnection:Disconnect() end

    aimConnection = RunService.RenderStepped:Connect(function(dt)
        if not Settings.AimBotEnabled then return end

        local target = getBestTarget(Settings.AimPart)
        if target then
            aimAt(target, dt)
            smartAutoFire(target)
        end
    end)
end

startAimBot()

task.spawn(function()
    while task.wait(0.05) do
        if Settings.AutoFireEnabled and Settings.SilentEnabled and not Settings.AimBotEnabled then
            local target = getBestTarget(Settings.SilentPart)
            if target then
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.03)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end
        end
    end
end)

local function applyHitbox(part, expand)
    if not part or not part:IsA("BasePart") then return end

    if expand then
        if not OriginalHitboxes[part] then
            OriginalHitboxes[part] = {
                Size = part.Size,
                Transparency = part.Transparency,
                CanCollide = part.CanCollide,
                Massless = part.Massless,
            }
        end

        part.CanCollide = false
        part.Massless = true
        part.Size = OriginalHitboxes[part].Size * Settings.HitboxSize
        part.Transparency = Settings.HitboxTransparency

    else
        local orig = OriginalHitboxes[part]
        if orig then
            part.Size = orig.Size
            part.Transparency = orig.Transparency
            part.CanCollide = orig.CanCollide
            part.Massless = orig.Massless
            OriginalHitboxes[part] = nil
        end
    end
end

local function updateHitboxes()
    if not Settings.HitboxEnabled then return end
    local playerSet = getPlayerCharacterSet()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local part = player.Character:FindFirstChild("Hitbox_Head") or player.Character:FindFirstChild("Head")
            if part then applyHitbox(part, true) end
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not playerSet[obj] and obj ~= LocalPlayer.Character then
            local part = obj:FindFirstChild("Hitbox_Head") or obj:FindFirstChild("Head")
            if part then applyHitbox(part, true) end
        end
    end
end

local function restoreAllHitboxes()
    for part, _ in pairs(OriginalHitboxes) do
        applyHitbox(part, false)
    end
    OriginalHitboxes = {}
end

task.spawn(function()
    while task.wait(0.5) do
        if Settings.HitboxEnabled then
            updateHitboxes()
        end
    end
end)

local InstantRespawnEnabled = false
local respawnConnection = nil
local lastRespawnTime = 0

local function setInstantRespawn(state)
    InstantRespawnEnabled = state

    if respawnConnection then
        respawnConnection:Disconnect()
        respawnConnection = nil
    end

    if state then
        respawnConnection = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local humanoid = char:FindFirstChildOfClass("Humanoid")

            if humanoid and humanoid.Health <= 0 and (tick() - lastRespawnTime) > 0.3 then
                lastRespawnTime = tick()

                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
        end)
    end
end

local BHopEnabled = false
local BHopTargetSpeed = 49
local BHopJumpPower = 0
local BHopJumping = false
local originalWalkSpeed = nil
local originalJumpPower = nil

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        BHopJumping = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Space then
        BHopJumping = false
    end
end)

UserInputService.WindowFocusReleased:Connect(function()
    BHopJumping = false
end)

local bhopConnection = RunService.Heartbeat:Connect(function()
    if not BHopEnabled then return end

    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    if not originalWalkSpeed then
        originalWalkSpeed = humanoid.WalkSpeed
    end
    if not originalJumpPower then
        originalJumpPower = humanoid.JumpPower
    end

    humanoid.WalkSpeed = BHopTargetSpeed

    if BHopJumpPower > 0 then
        humanoid.JumpPower = BHopJumpPower
        humanoid.UseJumpPower = true
    else
        humanoid.JumpPower = originalJumpPower
    end

    if BHopJumping and humanoid.FloorMaterial ~= Enum.Material.Air then
        humanoid.Jump = true
    end
end)

local function setBHop(state)
    BHopEnabled = state
    if not state then
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if originalWalkSpeed then
                    humanoid.WalkSpeed = originalWalkSpeed
                end
                if originalJumpPower then
                    humanoid.JumpPower = originalJumpPower
                end
            end
        end
        originalWalkSpeed = nil
        originalJumpPower = nil
        BHopJumping = false
    end
end

-- [МАГНИТ (MAGNET) ЛОГИКА - HARD LOCK]
local MagnetEnabled = false
local MagnetTargetPlayers = true
local MagnetTargetBots = true
local MagnetConnection = nil
local SavedAnchors = {}

local function startMagnet()
    if MagnetConnection then MagnetConnection:Disconnect() end
    
    MagnetConnection = RunService.RenderStepped:Connect(function()
        if not MagnetEnabled then return end
        
        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
        
        local playerSet = getPlayerCharacterSet()
        local targetPoint = Camera.CFrame.Position + (Camera.CFrame.LookVector * 10)
        
        local function pullModel(model)
            if not model then return end
            local targetPart = model:FindFirstChild("Head") or model:FindFirstChild("Hitbox_Head")
            if not targetPart then return end
            
            local hum = model:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            
            if model == myChar then return end
            
            if not targetPart.Anchored then
                targetPart.Anchored = true
                SavedAnchors[targetPart] = true
            end
            
            targetPart.CFrame = CFrame.new(targetPoint, targetPoint + Camera.CFrame.LookVector)
            
            local root = model:FindFirstChild("HumanoidRootPart")
            if root then
                if not root.Anchored then
                    root.Anchored = true
                    SavedAnchors[root] = true
                end
                root.CFrame = targetPart.CFrame * CFrame.new(0, -1.5, 0)
            end
        end

        if MagnetTargetPlayers then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    pullModel(player.Character)
                end
            end
        end

        if MagnetTargetBots then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not playerSet[obj] and obj ~= myChar then
                    pullModel(obj)
                end
            end
        end
    end)
end

local function stopMagnet()
    if MagnetConnection then MagnetConnection:Disconnect() end
    for part, _ in pairs(SavedAnchors) do
        if part and part.Parent then
            part.Anchored = false
        end
    end
    SavedAnchors = {}
end

local KillSoundEnabled = false
local killSoundConnection = nil

local CUSTOM_KILL_ID = "rbxassetid://8679627751"
local CUSTOM_HEADSHOT_ID = "rbxassetid://8679627751"
local ORIGINAL_KILL_ID = "128825426756691"
local ORIGINAL_HEADSHOT_ID = "75228431293068"

local myKillSound = Instance.new("Sound")
myKillSound.SoundId = CUSTOM_KILL_ID
myKillSound.Volume = 2
myKillSound.Parent = SoundService

local myHeadshotSound = Instance.new("Sound")
myHeadshotSound.SoundId = CUSTOM_HEADSHOT_ID
myHeadshotSound.Volume = 2
myHeadshotSound.Parent = SoundService

local function handleNewSound(sound)
    if not sound:IsA("Sound") then return end

    local isKill = string.find(sound.SoundId, ORIGINAL_KILL_ID)
    local isHeadshot = string.find(sound.SoundId, ORIGINAL_HEADSHOT_ID)

    if isKill or isHeadshot then
        sound.Volume = 0
        sound.Playing = false

        if isKill then
            myKillSound:Play()
        elseif isHeadshot then
            myHeadshotSound:Play()
        end

        task.delay(1, function()
            if sound and sound.Parent then sound:Destroy() end
        end)
    end
end

local function setKillSound(state)
    KillSoundEnabled = state

    if killSoundConnection then
        killSoundConnection:Disconnect()
        killSoundConnection = nil
    end

    if state then
        killSoundConnection = game.DescendantAdded:Connect(function(obj)
            if obj:IsA("Sound") then
                spawn(function()
                    task.wait(0.01)
                    handleNewSound(obj)
                end)
            end
        end)
    end
end

local CombatTab = Window:MakeTab({ Name = "COMBAT", Icon = "rbxassetid://4483345998" })

local CommonSection = CombatTab:AddSection({ Name = "General Settings" })
CommonSection:AddSlider({ Name = "FOV Radius", Min = 50, Max = 600, Default = 200, Increment = 10, Callback = function(v) Settings.FOV = v end })
CommonSection:AddSlider({ Name = "Max Target Distance", Min = 100, Max = 5000, Default = 1000, Increment = 100, Callback = function(v) Settings.MaxTargetDistance = v end })
CommonSection:AddToggle({ Name = "Visible Check", Default = true, Callback = function(s) Settings.VisibleCheckEnabled = s end })
CommonSection:AddToggle({ Name = "Auto Fire", Default = false, Callback = function(s) Settings.AutoFireEnabled = s end })

local AimSection = CombatTab:AddSection({ Name = "AimBot Settings" })
AimSection:AddToggle({ Name = "Enable AimBot", Default = false, Callback = function(s) Settings.AimBotEnabled = s end })
AimSection:AddSlider({ Name = "Smoothness", Min = 0, Max = 20, Default = 1, Increment = 1, Callback = function(v) Settings.AimSmoothness = v end })
AimSection:AddDropdown({ Name = "Target Part", Default = "Head", Options = {"Head", "HumanoidRootPart", "UpperTorso"}, Callback = function(o) Settings.AimPart = o end })

local SilentSection = CombatTab:AddSection({ Name = "Silent Aim Settings" })
SilentSection:AddToggle({ Name = "Enable Silent Aim", Default = false, Callback = function(s) Settings.SilentEnabled = s end })
SilentSection:AddDropdown({ Name = "Silent Target Part", Default = "Hitbox_Head", Options = {"Hitbox_Head", "Head", "HumanoidRootPart"}, Callback = function(o) Settings.SilentPart = o end })

local RapidSection = CombatTab:AddSection({ Name = "Rapid Fire Settings" })
RapidSection:AddToggle({ Name = "Rapid Fire (Constants)", Default = false, Callback = function(s) Settings.RapidFireConstantsEnabled = s; setRapidFireConstants(s) end })
RapidSection:AddToggle({ Name = "Multi-Bullet Spam (Hook)", Default = false, Callback = function(s) Settings.RapidFireSpamEnabled = s end })
RapidSection:AddToggle({ Name = "Ultra Animations (Bolt)", Default = false, Callback = function(s) Settings.UltraAnimations = s end })
RapidSection:AddSlider({ Name = "Bullets Per Shot (Spam)", Min = 1, Max = 50, Default = 10, Increment = 1, Callback = function(v) Settings.BulletsPerShot = v end })

local ESPTab = Window:MakeTab({ Name = "ESP", Icon = "rbxassetid://3947051614" })
local ESPSection = ESPTab:AddSection({ Name = "ESP Settings" })

ESPSection:AddToggle({ Name = "Enable ESP", Default = false, Callback = function(s)
    Settings.ESPEnabled = s
    if s then
        updateESP()
        task.spawn(function()
            while Settings.ESPEnabled do
                task.wait(1)
                updateESP()
            end
        end)
    else
        clearAllESP()
    end
end })

ESPSection:AddColorpicker({ Name = "ESP Color", Default = Color3.fromRGB(255, 0, 0), Callback = function(c)
    Settings.ESPColor = c
    for model, highlight in pairs(ESPObjects) do
        if highlight and highlight.Parent then
            highlight.FillColor = c
            highlight.OutlineColor = c
        end
    end
end })

-- ВКЛАДКА VISUAL
local VisualTab = Window:MakeTab({ Name = "VISUAL", Icon = "rbxassetid://4483345998" })

-- Night Mode
local VisualSection = VisualTab:AddSection({ Name = "Night Mode Settings" })

VisualSection:AddToggle({
    Name = "Enable Night Mode",
    Default = false,
    Callback = function(s)
        Settings.NightModeEnabled = s
        updateNightMode(s)
    end
})

VisualSection:AddSlider({
    Name = "Night Intensity (Brightness)",
    Min = -1.0, Max = 0.0, Default = -0.2, Increment = 0.05,
    Callback = function(v)
        Settings.NightIntensity = v
        nightModeCC.Brightness = v
    end
})

VisualSection:AddSlider({
    Name = "Night Saturation",
    Min = -1.0, Max = 1.0, Default = -0.3, Increment = 0.05,
    Callback = function(v)
        Settings.NightSaturation = v
        nightModeCC.Saturation = v
    end
})

VisualSection:AddColorpicker({
    Name = "Night Tint Color",
    Default = Color3.fromRGB(100, 120, 180),
    Callback = function(c)
        Settings.NightTint = c
        nightModeCC.TintColor = c
    end
})

-- Weather Changer
local WeatherSection = VisualTab:AddSection({ Name = "Weather Changer" })
WeatherSection:AddDropdown({
    Name = "Select Weather",
    Default = "None",
    Options = {"None", "Rain", "Snow"},
    Callback = function(option)
        setWeather(option)
    end
})

-- Time Changer
local TimeSection = VisualTab:AddSection({ Name = "Time Changer" })
TimeSection:AddDropdown({
    Name = "Select Time",
    Default = "None",
    Options = {"None", "Morning", "Day", "Evening", "Night"},
    Callback = function(option)
        setTimeOfDay(option)
    end
})

-- Fog Changer
local FogSection = VisualTab:AddSection({ Name = "Fog Changer" })
FogSection:AddSlider({
    Name = "Fog Distance (End)",
    Min = 100, Max = 5000, Default = 1000, Increment = 100,
    Callback = function(v)
        Settings.FogEnd = v
        setFog()
    end
})
FogSection:AddColorpicker({
    Name = "Fog Color",
    Default = Color3.fromRGB(192, 192, 192),
    Callback = function(c)
        Settings.FogColor = c
        setFog()
    end
})

-- HALLOWEEN
local HalloweenSection = VisualTab:AddSection({ Name = "Halloween Vibe" })

HalloweenSection:AddToggle({
    Name = "Enable Halloween Mode",
    Default = false,
    Callback = function(s) updateHalloween(s) end
})

HalloweenSection:AddSlider({
    Name = "Intensity",
    Min = 0.0, Max = 2.0, Default = 0.6, Increment = 0.1,
    Callback = function(v) Settings.HalloweenIntensity = v end
})

HalloweenSection:AddColorpicker({
    Name = "Halloween Tint",
    Default = Color3.fromRGB(255, 90, 0),
    Callback = function(c) Settings.HalloweenTint = c end
})

HalloweenSection:AddToggle({
    Name = "Floating Pumpkins",
    Default = false,
    Callback = function(s)
        Settings.PumpkinsEnabled = s
        if not s then clearPumpkins() end
    end
})

HalloweenSection:AddToggle({
    Name = "Bats Swarm",
    Default = false,
    Callback = function(s)
        Settings.BatsEnabled = s
        if not s then clearBats() end
    end
})

HalloweenSection:AddToggle({
    Name = "Vignette (Dark Corners)",
    Default = false,
    Callback = function(s)
        Settings.VignetteEnabled = s
        halloweenVignette.Visible = s and Settings.HalloweenEnabled
    end
})

local MiscTab = Window:MakeTab({ Name = "MISC", Icon = "rbxassetid://4483345998" })

local BHopSection = MiscTab:AddSection({ Name = "BunnyHop" })
BHopSection:AddToggle({ Name = "Enable BunnyHop", Default = false, Callback = function(state) setBHop(state) end })
BHopSection:AddSlider({ Name = "Max Speed", Min = 10, Max = 100, Default = 49, Increment = 1, Callback = function(v) BHopTargetSpeed = v end })
BHopSection:AddSlider({ Name = "Jump Power (0 = Normal)", Min = 0, Max = 200, Default = 0, Increment = 5, Callback = function(v) BHopJumpPower = v end })

-- СЕКЦИЯ: MAGNET
local MagnetSection = MiscTab:AddSection({ Name = "Magnet (Hard Lock)" })

MagnetSection:AddToggle({ 
    Name = "Enable Magnet", 
    Default = false, 
    Callback = function(s) 
        MagnetEnabled = s 
        if s then startMagnet() else stopMagnet() end
    end 
})

MagnetSection:AddToggle({ 
    Name = "Target Players", 
    Default = true, 
    Callback = function(s) MagnetTargetPlayers = s end 
})

MagnetSection:AddToggle({ 
    Name = "Target Bots", 
    Default = true, 
    Callback = function(s) MagnetTargetBots = s end 
})

local HitboxSection = MiscTab:AddSection({ Name = "Hitbox Expander" })
HitboxSection:AddToggle({
    Name = "Enable Hitbox Expander",
    Default = false,
    Callback = function(s)
        Settings.HitboxEnabled = s
        if not s then restoreAllHitboxes() end
    end
})
HitboxSection:AddSlider({
    Name = "Head Size",
    Min = 5.0, Max = 30.0, Default = 10.0, Increment = 1.0,
    Callback = function(v) Settings.HitboxSize = v end
})
HitboxSection:AddSlider({
    Name = "Transparency",
    Min = 0.0, Max = 1.0, Default = 0.7, Increment = 0.1,
    Callback = function(v) Settings.HitboxTransparency = v end
})

local RespawnSection = MiscTab:AddSection({ Name = "Respawn" })
RespawnSection:AddToggle({
    Name = "Instant Respawn",
    Default = false,
    Callback = function(s) setInstantRespawn(s) end
})

local SoundSection = MiscTab:AddSection({ Name = "Kill Sound" })
SoundSection:AddToggle({
    Name = "Enable Kill Sound",
    Default = false,
    Callback = function(s) setKillSound(s) end
})

local SettingsTab = Window:MakeTab({ Name = "SETTINGS", Icon = "rbxassetid://6031094667" })
local SettingsSection = SettingsTab:AddSection({ Name = "Actions" })

SettingsSection:AddButton({ Name = "UNLOAD SCRIPT", Callback = function()
    Settings.AimBotEnabled = false
    Settings.ESPEnabled = false
    Settings.SilentEnabled = false
    Settings.AutoFireEnabled = false
    Settings.RapidFireConstantsEnabled = false
    Settings.RapidFireSpamEnabled = false
    Settings.UltraAnimations = false
    Settings.HitboxEnabled = false
    Settings.NightModeEnabled = false
    BHopEnabled = false
    InstantRespawnEnabled = false
    KillSoundEnabled = false
    MagnetEnabled = false

    setRapidFireConstants(false)
    clearAllESP()
    restoreAllHitboxes()
    setInstantRespawn(false)
    setKillSound(false)
    stopMagnet()
    updateNightMode(false)
    setWeather("None")
    setTimeOfDay("None")
    
    Settings.HalloweenEnabled = false
    Settings.PumpkinsEnabled = false
    Settings.BatsEnabled = false
    Settings.VignetteEnabled = false
    clearPumpkins()
    clearBats()

    if nightModeCC then nightModeCC:Destroy() end
    if halloweenCC then halloweenCC:Destroy() end
    if halloweenBlur then halloweenBlur:Destroy() end
    if halloweenVignette then halloweenVignette:Destroy() end
    if halloweenFolder then halloweenFolder:Destroy() end
    if sky then sky:Destroy() end
    if sunRays then sunRays:Destroy() end
    if weatherFolder then weatherFolder:Destroy() end
    if rainSound then rainSound:Destroy() end

    if myKillSound then myKillSound:Destroy() end
    if myHeadshotSound then myHeadshotSound:Destroy() end

    if aimConnection then aimConnection:Disconnect() end
    setBHop(false)

    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and originalJumpPower then
            hum.JumpPower = originalJumpPower
        end
    end

    if bhopConnection then bhopConnection:Disconnect() end
    if fovCircle then fovCircle:Remove() end

    OrionLib:Destroy()
end })

OrionLib:Init()
