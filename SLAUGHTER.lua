-- Загружаем OrionLib
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

-- Создаём окно SLAUGHTER
local Window = OrionLib:MakeWindow({
    Name = "SLAUGHTER",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "SlaughterConfig"
})

-- ─── Настройки AimBot ────────────────────────────────────────────────────────
local AimBotEnabled = false
local AimSmoothness = 1        -- Для One Tap лучше 1 или 0
local WallCheckEnabled = true
local AutoFireEnabled = false
local AimPart = "Head"         -- Целимся в голову
local FOV = 120                -- Радиус в пикселях

-- ─── Настройки ESP ───────────────────────────────────────────────────────────
local ESPEnabled = false
local ESPColor = Color3.fromRGB(255, 0, 0)
local ESPObjects = {}

-- ─── Функции ESP ─────────────────────────────────────────────────────────────
local function createESP(model)
    if not model or not model:IsA("Model") then return end
    if not model:FindFirstChild("Humanoid") then return end
    if ESPObjects[model] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "SlaughterESP"
    highlight.Adornee = model
    highlight.FillColor = ESPColor
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = ESPColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = model

    ESPObjects[model] = highlight
end

local function updateESP()
    if not ESPEnabled then return end
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= game.Players.LocalPlayer and player.Character then
            createESP(player.Character)
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
            local isPlayer = false
            for _, player in ipairs(game.Players:GetPlayers()) do
                if player.Character == obj then
                    isPlayer = true
                    break
                end
            end
            if not isPlayer then
                createESP(obj)
            end
        end
    end
end

local function clearAllESP()
    for model, highlight in pairs(ESPObjects) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    ESPObjects = {}
end

-- ─── Функции AimBot (ИСПРАВЛЕНО ДЛЯ БОТОВ) ───────────────────────────────────
local function getBestTarget()
    local localPlayer = game.Players.LocalPlayer
    local camera = workspace.CurrentCamera
    local closest = nil
    local shortestDist = FOV
    local localChar = localPlayer.Character

    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return nil end

    -- Функция проверки дистанции до центра экрана
    local function checkTarget(targetPart, targetModel)
        if not targetPart or not targetPart.Parent then return end
        
        -- Проверка, что цель жива
        local humanoid = targetModel:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then return end

        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)).Magnitude
            if dist < shortestDist then
                if WallCheckEnabled then
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {localChar, targetModel}
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local ray = workspace:Raycast(camera.CFrame.Position, targetPart.Position - camera.CFrame.Position, rayParams)
                    if ray then return end -- Стена
                end
                shortestDist = dist
                closest = targetPart
            end
        end
    end

    -- 1. Проверяем ИГРОКОВ
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild(AimPart) or player.Character:FindFirstChild("HumanoidRootPart")
            checkTarget(targetPart, player.Character)
        end
    end

    -- 2. Проверяем БОТОВ (NPC) в Workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
            -- Пропускаем реальных игроков, чтобы не проверять дважды
            local isPlayer = false
            for _, player in ipairs(game.Players:GetPlayers()) do
                if player.Character == obj then
                    isPlayer = true
                    break
                end
            end
            
            if not isPlayer then
                local targetPart = obj:FindFirstChild(AimPart) or obj:FindFirstChild("HumanoidRootPart")
                checkTarget(targetPart, obj)
            end
        end
    end

    return closest
end

local function aimAt(target)
    local camera = workspace.CurrentCamera
    local targetPos = target.Position
    
    -- Вычисляем, куда должна смотреть камера (из текущей позиции камеры на цель)
    local newCFrame = CFrame.new(camera.CFrame.Position, targetPos)
    
    if AimSmoothness > 0 then
        -- Если плавность включена, используем слайдер как "силу магнита"
        -- Чем меньше значение, тем сильнее магнит (1 = очень быстро, 20 = очень медленно)
        local factor = 1 / (AimSmoothness * 2) -- Подбираем коэффициент для плавности
        camera.CFrame = camera.CFrame:Lerp(newCFrame, factor)
    else
        -- Если Smoothness = 0, камера жестко фиксируется на голове (мгновенно)
        camera.CFrame = newCFrame
    end
end

local function autoFire(target)
    if not AutoFireEnabled or not target then return end
    
    -- Имитация нажатия ЛКМ для выстрела (работает в большинстве FPS на Roblox)
    local VirtualInputManager = game:GetService("VirtualInputManager")
    
    -- Нажимаем и отпускаем кнопку мыши
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.05) -- Небольшая задержка между выстрелами (подбери под оружие)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local aimConnection = nil

local function startAimBot()
    -- Отключаем старый цикл, если он был
    if aimConnection then aimConnection:Disconnect() end
    
    aimConnection = game:GetService("RunService").RenderStepped:Connect(function()
        if not AimBotEnabled then return end
        
        local target = getBestTarget()
        if target then
            aimAt(target)
            autoFire(target)
        end
    end)
end

-- ─── Вкладка COMBAT ──────────────────────────────────────────────────────────
local CombatTab = Window:MakeTab({
    Name = "COMBAT",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local AimSection = CombatTab:AddSection({ Name = "AimBot Settings" })

AimSection:AddToggle({
    Name = "Enable AimBot",
    Default = false,
    Flag = "AimBot_Toggle",
    Save = false,
    Callback = function(state)
        AimBotEnabled = state
        if state then startAimBot() end
    end
})

AimSection:AddSlider({
    Name = "Smoothness (0 = Instant)",
    Min = 0,
    Max = 20,
    Default = 1,
    Increment = 1,
    ValueName = "smooth",
    Callback = function(value) AimSmoothness = value end
})

-- НОВОЕ: Выбор части тела для наводки
AimSection:AddDropdown({
    Name = "Target Part",
    Default = "Head",
    Options = {"Head", "HumanoidRootPart", "UpperTorso"},
    Callback = function(option) AimPart = option end
})

AimSection:AddToggle({
    Name = "Wall Check",
    Default = true,
    Flag = "WallCheck_Toggle",
    Save = false,
    Callback = function(state) WallCheckEnabled = state end
})

AimSection:AddToggle({
    Name = "Auto Fire (Instant Click)",
    Default = false,
    Flag = "AutoFire_Toggle",
    Save = false,
    Callback = function(state) AutoFireEnabled = state end
})

-- ─── Вкладка ESP ─────────────────────────────────────────────────────────────
local ESPTab = Window:MakeTab({
    Name = "ESP",
    Icon = "rbxassetid://3947051614",
    PremiumOnly = false
})

local ESPSection = ESPTab:AddSection({ Name = "ESP Settings" })

ESPSection:AddToggle({
    Name = "Enable ESP",
    Default = false,
    Flag = "ESP_Toggle",
    Save = false,
    Callback = function(state)
        ESPEnabled = state
        if ESPEnabled then
            updateESP()
            task.spawn(function()
                while ESPEnabled do
                    task.wait(1)
                    updateESP()
                end
            end)
        else
            clearAllESP()
        end
    end
})

ESPSection:AddColorpicker({
    Name = "ESP Color",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        ESPColor = color
        for model, highlight in pairs(ESPObjects) do
            if highlight and highlight.Parent then
                highlight.FillColor = color
                highlight.OutlineColor = color
            end
        end
    end
})

-- ─── Вкладка SETTINGS ────────────────────────────────────────────────────────
local SettingsTab = Window:MakeTab({
    Name = "SETTINGS",
    Icon = "rbxassetid://3947051614",
    PremiumOnly = false
})

local SettingsSection = SettingsTab:AddSection({ Name = "Actions" })

SettingsSection:AddButton({
    Name = "UNLOAD SCRIPT",
    Callback = function()
        AimBotEnabled = false
        ESPEnabled = false
        clearAllESP()
        OrionLib:Destroy()
        OrionLib = nil
        Window = nil
        CombatTab = nil
        ESPTab = nil
        SettingsTab = nil
    end
})

-- Инициализация
OrionLib:Init()