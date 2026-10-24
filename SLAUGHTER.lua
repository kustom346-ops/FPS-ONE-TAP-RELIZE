-- Загружаем OrionLib
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Qanuir/orion-ui/refs/heads/main/source.lua"))()

-- Создаём окно SLAUGHTER
local Window = OrionLib:MakeWindow({
    Name = "SLAUGHTER",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "SlaughterConfig",
    Size = UDim2.fromOffset(600, 500) -- Окно побольше, чтобы все вкладки влезли
})

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

-- ─── НАСТРОЙКИ ───────────────────────────────────────────────────────────────
local Settings = {
    -- AimBot
    AimBotEnabled = false,
    AimSmoothness = 1,
    AutoFireEnabled = false,
    AimPart = "Head",

    -- Silent
    SilentEnabled = false,
    SilentPart = "Hitbox_Head",

    -- Rapid Fire
    RapidFireConstantsEnabled = false,
    RapidFireSpamEnabled = false,
    BulletsPerShot = 10,
    UltraAnimations = false,

    -- Общие
    FOV = 200,
    VisibleCheckEnabled = true,
    MaxTargetDistance = 1000,

    -- ESP
    ESPEnabled = false,
    ESPColor = Color3.fromRGB(255, 0, 0),

    -- HITBOX EXPANDER
    HitboxEnabled = false,
    HitboxSize = 10.0,          -- от 5 до 30
    HitboxTransparency = 0.7,
}

local ESPObjects = {}
local WeaponConstants = nil
local OriginalHitboxes = {} -- Запоминаем оригинальные размеры

-- ─── FOV Circle ──────────────────────────────────────────────────────────────
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

-- ─── Хелпер: Set персонажей игроков ─────────────────────────────────────────
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

-- ─── ESP ─────────────────────────────────────────────────────────────────────
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

-- ─── Visible Check ───────────────────────────────────────────────────────────
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

-- ─── Поиск цели ─────────────────────────────────────────────────────────────
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

-- ─── Rapid Fire: Константы ──────────────────────────────────────────────────
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

-- ─── Ускорение анимаций ─────────────────────────────────────────────────────
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

-- ─── Хук FastCast ───────────────────────────────────────────────────────────
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

-- ─── AimBot & AutoFire ──────────────────────────────────────────────────────
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

-- AutoFire для Silent без AimBot
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

-- ═══════════════════════════════════════════════════════════════════════════
-- HITBOX EXPANDER (Только для голов, не морозит)
-- ═══════════════════════════════════════════════════════════════════════════
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
        
        -- 1. Отключаем физику
        part.CanCollide = false
        part.Massless = true
        
        -- 2. Меняем размер и прозрачность
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

    -- Игроки
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local part = player.Character:FindFirstChild("Hitbox_Head") or player.Character:FindFirstChild("Head")
            if part then applyHitbox(part, true) end
        end
    end

    -- Боты
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

-- ═══════════════════════════════════════════════════════════════════════════
-- INSTANT RESPAWN
-- ═══════════════════════════════════════════════════════════════════════════
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
            
            -- Если мы мертвы и прошло больше 0.3 секунды с прошлого раза
            if humanoid and humanoid.Health <= 0 and (tick() - lastRespawnTime) > 0.3 then
                lastRespawnTime = tick()
                
                -- Нажимаем ПРОБЕЛ для вызова системного респавна (как кнопка "Возродиться")
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
        end)
    end
end

-- ─── BHop ────────────────────────────────────────────────────────────────────
local BHopEnabled = false
local BHopTargetSpeed = 49
local BHopJumpPower = 0      -- 0 = стандартный прыжок
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

-- ═══════════════════════════════════════════════════════════════════════════
-- KILL SOUND SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
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
            print("Перехвачен звук УБИЙСТВА!")
        elseif isHeadshot then
            myHeadshotSound:Play()
            print("Перехвачен звук ХЕДШОТА!")
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

-- ─── UI: COMBAT ──────────────────────────────────────────────────────────────
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

-- ─── UI: ESP ─────────────────────────────────────────────────────────────────
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

-- ─── UI: MISC ────────────────────────────────────────────────────────────────
local MiscTab = Window:MakeTab({ Name = "MISC", Icon = "rbxassetid://4483345998" })

local BHopSection = MiscTab:AddSection({ Name = "BunnyHop" })
BHopSection:AddToggle({ Name = "Enable BunnyHop", Default = false, Callback = function(state) setBHop(state) end })
BHopSection:AddSlider({ Name = "Max Speed", Min = 10, Max = 100, Default = 49, Increment = 1, Callback = function(v) BHopTargetSpeed = v end })
BHopSection:AddSlider({ Name = "Jump Power (0 = Normal)", Min = 0, Max = 200, Default = 0, Increment = 5, Callback = function(v) BHopJumpPower = v end })
BHopSection:AddLabel("Зажми ПРОБЕЛ — разгон до Max Speed и стоп выше.")

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

-- НОВАЯ СЕКЦИЯ KILL SOUND
local SoundSection = MiscTab:AddSection({ Name = "Kill Sound" })
SoundSection:AddToggle({ 
    Name = "Enable Kill Sound", 
    Default = false, 
    Callback = function(s) setKillSound(s) end 
})

-- ─── UI: SETTINGS ────────────────────────────────────────────────────────────
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
    BHopEnabled = false
    InstantRespawnEnabled = false
    KillSoundEnabled = false

    setRapidFireConstants(false)
    clearAllESP()
    restoreAllHitboxes()
    setInstantRespawn(false)
    setKillSound(false) -- Отключаем хук звуков
    
    -- Удаляем созданные кастомные звуки, чтобы не висели в памяти
    if myKillSound then myKillSound:Destroy() end
    if myHeadshotSound then myHeadshotSound:Destroy() end

    if aimConnection then aimConnection:Disconnect() end
    setBHop(false)
    
    -- Сброс JumpPower на случай, если setBHop не успел
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

-- ─── INIT ────────────────────────────────────────────────────────────────────
OrionLib:Init()
