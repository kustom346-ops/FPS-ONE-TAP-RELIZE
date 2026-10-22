-- Загружаем OrionLib
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

-- Создаём окно SLAUGHTER
local Window = OrionLib:MakeWindow({
    Name = "SLAUGHTER",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "SlaughterConfig"
})

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
    RapidFireEnabled = false,
    BulletsPerShot = 10,
    UltraAnimations = false,
    
    -- Общие
    FOV = 200, 
    VisibleCheckEnabled = true,
    
    -- ESP
    ESPEnabled = false,
    ESPColor = Color3.fromRGB(255, 0, 0),
}

local ESPObjects = {}
local WeaponConstants = nil
local fovCircle = Drawing.new("Circle")

-- ─── Визуал FOV ──────────────────────────────────────────────────────────────
fovCircle.Thickness = 1.5
fovCircle.NumSides = 60
fovCircle.Filled = false
fovCircle.Color = Color3.fromRGB(255, 0, 0)
fovCircle.Transparency = 1
fovCircle.Visible = false

RunService.RenderStepped:Connect(function()
    if Settings.AimBotEnabled or Settings.SilentEnabled or Settings.RapidFireEnabled then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Radius = Settings.FOV
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
end)

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
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            createESP(player.Character)
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
            local isPlayer = false
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character == obj then isPlayer = true; break end
            end
            if not isPlayer then createESP(obj) end
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

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {localChar, targetModel}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    
    local ray = Workspace:Raycast(origin, direction, rayParams)
    return ray == nil
end

-- ─── Поиск цели ──────────────────────────────────────────────────────────────
local function getBestTarget(targetPartName)
    local closest = nil
    local shortestDist = Settings.FOV
    local localChar = LocalPlayer.Character
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return nil end

    local function checkTarget(targetPart, targetModel)
        if not targetPart or not targetPart.Parent then return end
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
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
            local isPlayer = false
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character == obj then isPlayer = true; break end
            end
            if not isPlayer then
                local targetPart = obj:FindFirstChild(targetPartName) or obj:FindFirstChild("HumanoidRootPart")
                checkTarget(targetPart, obj)
            end
        end
    end
    return closest
end

-- ─── Rapid Fire (Константы) ──────────────────────────────────────────────────
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

-- ─── Ускорение Анимаций (Обход затвора) ──────────────────────────────────────
local function speedUpAnimations()
    if not Settings.UltraAnimations then return end
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animName = track.Animation.Name:lower()
        if animName:find("reload") or animName:find("fire") or animName:find("bolt") or animName:find("shoot") or animName:find("primary") then
            track:AdjustSpeed(1000) 
        end
    end
end

task.spawn(function()
    while true do
        speedUpAnimations()
        task.wait(0.1)
    end
end)

-- ─── Хук FastCast (Silent Aim + Rapid Fire) ──────────────────────────────────
local function hookFastCast()
    local success, FastCastRedux = pcall(function()
        return require(Workspace.Parent.ReplicatedStorage.Common.Components.FastCastRedux)
    end)
    
    if not success or not FastCastRedux then return false end

    local originalFire = FastCastRedux.Fire or (FastCastRedux.ActiveCast and FastCastRedux.ActiveCast.Fire)
    
    if originalFire then
        local newFire = function(self, origin, direction, ...)
            local extraArgs = table.pack(...)
            
            local isLocalShot = false
            if origin then
                local distToCamera = (origin - Camera.CFrame.Position).Magnitude
                if distToCamera < 15 then isLocalShot = true end
            end

            if isLocalShot then
                if Settings.SilentEnabled then
                    local target = getBestTarget(Settings.SilentPart)
                    if target then
                        origin = Camera.CFrame.Position
                        direction = (target.Position - origin).Unit
                    end
                end

                if Settings.RapidFireEnabled then
                    task.spawn(function()
                        for i = 1, Settings.BulletsPerShot do
                            if not Settings.RapidFireEnabled then break end
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
    return false
end

task.spawn(function()
    while not hookFastCast() do task.wait(2) end
end)

-- ─── AimBot & AutoFire ───────────────────────────────────────────────────────
local function aimAt(target)
    local targetPos = target.Position
    local newCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    
    if Settings.AimSmoothness > 0 then
        local factor = 1 / (Settings.AimSmoothness * 2)
        Camera.CFrame = Camera.CFrame:Lerp(newCFrame, factor)
    else
        Camera.CFrame = newCFrame
    end
end

local lastFireTime = 0
local function smartAutoFire()
    if not Settings.AutoFireEnabled then return end
    
    local now = tick()
    if now - lastFireTime < 0.1 then return end
    
    local shouldFire = false
    
    if Settings.AimBotEnabled then
        local aimTarget = getBestTarget(Settings.AimPart)
        if aimTarget then
            local screenPos = Camera:WorldToViewportPoint(aimTarget.Position)
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            if (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude < 50 then
                shouldFire = true
            end
        end
    elseif Settings.SilentEnabled then
        local silentTarget = getBestTarget(Settings.SilentPart)
        if silentTarget then
            shouldFire = true
        end
    end
    
    if shouldFire then
        lastFireTime = now
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end
end

local aimConnection = nil
local function startAimBot()
    if aimConnection then aimConnection:Disconnect() end
    
    aimConnection = RunService.RenderStepped:Connect(function()
        if Settings.AimBotEnabled then
            local target = getBestTarget(Settings.AimPart)
            if target then
                aimAt(target)
            end
        end
        smartAutoFire()
    end)
end

-- ─── UI ──────────────────────────────────────────────────────────────────────
local CombatTab = Window:MakeTab({ Name = "COMBAT", Icon = "rbxassetid://4483345998" })

local CommonSection = CombatTab:AddSection({ Name = "General Settings" })
CommonSection:AddSlider({ Name = "FOV Radius", Min = 50, Max = 600, Default = 200, Increment = 10, Callback = function(v) Settings.FOV = v end })
CommonSection:AddToggle({ Name = "Visible Check", Default = true, Callback = function(s) Settings.VisibleCheckEnabled = s end })
CommonSection:AddToggle({ Name = "Auto Fire", Default = false, Callback = function(s) Settings.AutoFireEnabled = s end })

local AimSection = CombatTab:AddSection({ Name = "AimBot Settings" })
AimSection:AddToggle({ Name = "Enable AimBot", Default = false, Callback = function(s) Settings.AimBotEnabled = s; if s then startAimBot() end end })
AimSection:AddSlider({ Name = "Smoothness", Min = 0, Max = 20, Default = 1, Increment = 1, Callback = function(v) Settings.AimSmoothness = v end })
AimSection:AddDropdown({ Name = "Target Part", Default = "Head", Options = {"Head", "HumanoidRootPart", "UpperTorso"}, Callback = function(o) Settings.AimPart = o end })

local SilentSection = CombatTab:AddSection({ Name = "Silent Aim Settings" })
SilentSection:AddToggle({ Name = "Enable Silent Aim", Default = false, Callback = function(s) Settings.SilentEnabled = s end })
SilentSection:AddDropdown({ Name = "Silent Target Part", Default = "Hitbox_Head", Options = {"Hitbox_Head", "Head", "HumanoidRootPart"}, Callback = function(o) Settings.SilentPart = o end })

local RapidSection = CombatTab:AddSection({ Name = "Rapid Fire Settings" })
RapidSection:AddToggle({ Name = "Enable Rapid Fire (Constants)", Default = false, Callback = function(s) Settings.RapidFireEnabled = s; setRapidFireConstants(s) end })
RapidSection:AddToggle({ Name = "Enable Ultra Animations (Bolt)", Default = false, Callback = function(s) Settings.UltraAnimations = s end })
RapidSection:AddSlider({ Name = "Bullets Per Shot (Spam)", Min = 1, Max = 50, Default = 10, Increment = 1, Callback = function(v) Settings.BulletsPerShot = v end })

local ESPTab = Window:MakeTab({ Name = "ESP", Icon = "rbxassetid://3947051614" })
local ESPSection = ESPTab:AddSection({ Name = "ESP Settings" })
ESPSection:AddToggle({ Name = "Enable ESP", Default = false, Callback = function(s)
    Settings.ESPEnabled = s
    if s then updateESP(); task.spawn(function() while Settings.ESPEnabled do task.wait(1); updateESP() end end) else clearAllESP() end
end })
ESPSection:AddColorpicker({ Name = "ESP Color", Default = Color3.fromRGB(255, 0, 0), Callback = function(c)
    Settings.ESPColor = c
    for model, highlight in pairs(ESPObjects) do
        if highlight and highlight.Parent then highlight.FillColor = c; highlight.OutlineColor = c end
    end
end })

local SettingsTab = Window:MakeTab({ Name = "SETTINGS", Icon = "rbxassetid://3947051614" })
local SettingsSection = SettingsTab:AddSection({ Name = "Actions" })
SettingsSection:AddButton({ Name = "UNLOAD SCRIPT", Callback = function()
    Settings.AimBotEnabled = false
    Settings.ESPEnabled = false
    Settings.SilentEnabled = false
    Settings.AutoFireEnabled = false
    Settings.RapidFireEnabled = false
    Settings.UltraAnimations = false
    setRapidFireConstants(false)
    clearAllESP()
    if fovCircle then fovCircle:Remove() end
    OrionLib:Destroy()
end })

OrionLib:Init()
