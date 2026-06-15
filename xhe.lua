--[[
    MOBILE ROBLOX SCRIPT: Полнофункциональный чит
    - Кнопка меню на экране (перетаскиваемая)
    - ESP: здоровье, бокс, линия, скелет, имя
    - Aimbot с проверкой видимости, FOV, дистанцией, выбором цели
    - Кастомный FOV камеры
    - Кастомное смещение камеры (вид от третьего лица)
--]]

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Настройки
local settings = {
    menuOpen = false,
    tab = "Visuals",
    visuals = {
        espEnabled = true,
        health = true,
        box = true,
        line = true,
        skeleton = true,
        name = true
    },
    aimbot = {
        enabled = false,
        fov = 100,
        distance = 100,
        trigger = "Auto", -- Auto, OnTap (касание экрана)
        targetPart = "Head"
    },
    memory = {
        customFOV = 70,
        customViewOffset = Vector3.new(0, 0, 0)
    }
}

-- Вспомогательная функция: найти индекс в таблице
local function tableFind(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then return i end
    end
    return nil
end

-- Проверка видимости игрока (Raycast)
local function isPlayerVisible(targetPlayer)
    local character = targetPlayer.Character
    if not character or not character.PrimaryPart then return false end
    local targetPart = character.PrimaryPart
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).unit * (targetPart.Position - origin).magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character, character}
    local result = workspace:Raycast(origin, direction, raycastParams)
    if result then
        return result.Instance:IsDescendantOf(character)
    else
        return true
    end
end

-- Получение частей скелета
local function getSkeletonParts(character)
    return {
        Head = character:FindFirstChild("Head"),
        UpperTorso = character:FindFirstChild("UpperTorso"),
        LowerTorso = character:FindFirstChild("LowerTorso"),
        LeftArm = character:FindFirstChild("LeftArm"),
        RightArm = character:FindFirstChild("RightArm"),
        LeftLeg = character:FindFirstChild("LeftLeg"),
        RightLeg = character:FindFirstChild("RightLeg")
    }
end

-- Рисование ESP (эффективно: пересоздаём объекты каждый кадр, но без утечек)
local function drawESP()
    if not settings.visuals.espEnabled then return end
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player then
            local character = otherPlayer.Character
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                local humanoid = character.Humanoid
                local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
                if not rootPart then continue end
                local rootPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
                if not onScreen then continue end
                local headPart = character:FindFirstChild("Head")
                local headPos = headPart and camera:WorldToScreenPoint(headPart.Position) or rootPos
                local boxHeight = math.abs(rootPos.Y - headPos.Y) * 1.5
                local boxWidth = boxHeight / 2
                local boxX = headPos.X - boxWidth/2
                local boxY = headPos.Y
                
                -- Линия
                if settings.visuals.line then
                    local line = Drawing.new("Line")
                    line.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                    line.To = Vector2.new(rootPos.X, rootPos.Y)
                    line.Color = Color3.new(1,0,0)
                    line.Thickness = 1
                    line.Visible = true
                    task.wait(0.033)
                    line:Remove()
                end
                
                -- Бокс
                if settings.visuals.box then
                    local box = Drawing.new("Quad")
                    box.PointA = Vector2.new(boxX, boxY)
                    box.PointB = Vector2.new(boxX+boxWidth, boxY)
                    box.PointC = Vector2.new(boxX+boxWidth, boxY+boxHeight)
                    box.PointD = Vector2.new(boxX, boxY+boxHeight)
                    box.Color = Color3.new(0,1,0)
                    box.Thickness = 1
                    box.Filled = false
                    box.Visible = true
                    task.wait(0.033)
                    box:Remove()
                end
                
                -- Имя
                if settings.visuals.name then
                    local nameText = Drawing.new("Text")
                    nameText.Text = otherPlayer.Name
                    nameText.Position = Vector2.new(boxX + boxWidth/2, boxY - 15)
                    nameText.Size = 14
                    nameText.Color = Color3.new(1,1,1)
                    nameText.Center = true
                    nameText.Visible = true
                    task.wait(0.033)
                    nameText:Remove()
                end
                
                -- Здоровье (полоска)
                if settings.visuals.health then
                    local hpPercent = humanoid.Health / humanoid.MaxHealth
                    local healthBar = Drawing.new("Quad")
                    local barX = boxX - 5
                    local barY = boxY
                    local barWidth = 3
                    local barHeight = boxHeight * hpPercent
                    healthBar.PointA = Vector2.new(barX, barY+boxHeight-barHeight)
                    healthBar.PointB = Vector2.new(barX+barWidth, barY+boxHeight-barHeight)
                    healthBar.PointC = Vector2.new(barX+barWidth, barY+boxHeight)
                    healthBar.PointD = Vector2.new(barX, barY+boxHeight)
                    healthBar.Color = Color3.new(0,1,0)
                    healthBar.Filled = true
                    healthBar.Visible = true
                    task.wait(0.033)
                    healthBar:Remove()
                end
                
                -- Скелет
                if settings.visuals.skeleton then
                    local parts = getSkeletonParts(character)
                    local connections = {
                        {parts.Head, parts.UpperTorso},
                        {parts.UpperTorso, parts.LowerTorso},
                        {parts.UpperTorso, parts.LeftArm},
                        {parts.UpperTorso, parts.RightArm},
                        {parts.LowerTorso, parts.LeftLeg},
                        {parts.LowerTorso, parts.RightLeg}
                    }
                    for _, pair in ipairs(connections) do
                        local a, b = pair[1], pair[2]
                        if a and b then
                            local posA, visA = camera:WorldToScreenPoint(a.Position)
                            local posB, visB = camera:WorldToScreenPoint(b.Position)
                            if visA and visB then
                                local line = Drawing.new("Line")
                                line.From = Vector2.new(posA.X, posA.Y)
                                line.To = Vector2.new(posB.X, posB.Y)
                                line.Color = Color3.new(1,1,0)
                                line.Thickness = 1
                                line.Visible = true
                                task.wait(0.033)
                                line:Remove()
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Aimbot с плавным поворотом камеры (работает на телефоне и ПК)
local function aimbot()
    if not settings.aimbot.enabled then return end
    local closestAngle = settings.aimbot.fov
    local closestPlayer = nil
    local targetPartName = settings.aimbot.targetPart
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player then
            local character = otherPlayer.Character
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                if isPlayerVisible(otherPlayer) then
                    local targetPart = character:FindFirstChild(targetPartName) or character.PrimaryPart
                    if targetPart then
                        local targetPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
                        if onScreen then
                            local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                            local angle = (Vector2.new(targetPos.X, targetPos.Y) - screenCenter).magnitude
                            local distance = (camera.CFrame.Position - targetPart.Position).magnitude
                            if angle < closestAngle and distance <= settings.aimbot.distance then
                                closestAngle = angle
                                closestPlayer = otherPlayer
                            end
                        end
                    end
                end
            end
        end
    end
    if closestPlayer then
        local targetCharacter = closestPlayer.Character
        local targetPart = targetCharacter:FindFirstChild(settings.aimbot.targetPart) or targetCharacter.PrimaryPart
        if targetPart then
            -- Проверка триггера
            local shouldAim = false
            if settings.aimbot.trigger == "Auto" then
                shouldAim = true
            elseif settings.aimbot.trigger == "OnTap" then
                -- На телефоне: если палец на экране (кроме кнопок GUI)
                shouldAim = UserInputService:IsTouchEnabled() and #UserInputService:GetTouchPositions() > 0
            end
            if shouldAim then
                -- Плавный поворот камеры к цели
                local targetCFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
                camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.3)
            end
        end
    end
end

-- Кастомный FOV
local function applyCustomFOV()
    camera.FieldOfView = settings.memory.customFOV
end

-- Кастомное смещение камеры (от третьего лица)
local function applyCustomView()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local root = player.Character.HumanoidRootPart
        local offset = settings.memory.customViewOffset
        local newPos = root.Position + root.CFrame:VectorToWorldSpace(offset)
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(newPos, root.Position)
    else
        camera.CameraType = Enum.CameraType.Custom
    end
end

-- СОЗДАНИЕ GUI (МЕНЮ С КНОПКОЙ ОТКРЫТИЯ ДЛЯ ТЕЛЕФОНА)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CheatMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Кнопка открытия/закрытия меню (перетаскиваемая)
local toggleButton = Instance.new("ImageButton")
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(0, 20, 1, -70)
toggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
toggleButton.BackgroundTransparency = 0.2
toggleButton.Image = "rbxassetid://0"  -- прозрачная
toggleButton.Parent = screenGui

local buttonText = Instance.new("TextLabel")
buttonText.Size = UDim2.new(1,0,1,0)
buttonText.BackgroundTransparency = 1
buttonText.Text = "MENU"
buttonText.TextColor3 = Color3.new(1,1,1)
buttonText.TextScaled = true
buttonText.Parent = toggleButton

-- Перетаскивание кнопки
local dragging = false
local dragStartPos
local buttonStartPos
toggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStartPos = input.Position
        buttonStartPos = toggleButton.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStartPos
        toggleButton.Position = UDim2.new(buttonStartPos.X.Scale, buttonStartPos.X.Offset + delta.X,
                                         buttonStartPos.Y.Scale, buttonStartPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Основное меню (Frame)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.BackgroundColor3 = Color3.fromRGB(20,20,20)
title.Text = "Cheat Menu"
title.TextColor3 = Color3.new(1,1,1)
title.Parent = mainFrame

-- Закрыть меню крестиком
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(60,0,0)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Parent = mainFrame
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    settings.menuOpen = false
end)

-- Табы
local tabs = {}
local currentTab = "Visuals"
local tabButtons = {}
local tabY = 30
local tabNames = {"Visuals", "AimBot", "Memory"}
for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 0, 30)
    btn.Position = UDim2.new(0, 10 + (i-1)*95, 0, tabY)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = mainFrame
    local tabFrame = Instance.new("ScrollingFrame")
    tabFrame.Size = UDim2.new(1,0,1,-60)
    tabFrame.Position = UDim2.new(0,0,0,60)
    tabFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    tabFrame.BorderSizePixel = 0
    tabFrame.CanvasSize = UDim2.new(0,0,0,400)
    tabFrame.ScrollBarThickness = 6
    tabFrame.Visible = (name == currentTab)
    tabFrame.Parent = mainFrame
    tabs[name] = tabFrame
    tabButtons[name] = btn
    btn.MouseButton1Click:Connect(function()
        currentTab = name
        for _, f in pairs(tabs) do f.Visible = false end
        tabFrame.Visible = true
    end)
end

-- Вспомогательная функция для создания чекбокса
local function createCheckbox(parent, text, getter, setter, y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 150, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    btn.Text = text .. ": " .. (getter() and "ON" or "OFF")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = parent
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.Text = text .. ": " .. (getter() and "ON" or "OFF")
    end)
    return btn
end

-- Слайдер для телефона (работает через касание и перетаскивание)
local function createSlider(parent, text, min, max, getter, setter, y)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 40)
    frame.Position = UDim2.new(0, 10, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,0,20)
    label.Text = text .. ": " .. tostring(math.floor(getter()))
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.Parent = frame
    
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,10)
    bar.Position = UDim2.new(0,0,0,25)
    bar.BackgroundColor3 = Color3.fromRGB(100,100,100)
    bar.Parent = frame
    
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(0,200,0)
    fill.Size = UDim2.new((getter()-min)/(max-min), 0, 1,0)
    fill.Parent = bar
    
    local function updateFromPosition(inputPos)
        local relX = math.clamp((inputPos.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local newVal = min + relX * (max - min)
        newVal = math.floor(newVal)
        setter(newVal)
        label.Text = text .. ": " .. tostring(newVal)
        fill.Size = UDim2.new((newVal-min)/(max-min), 0, 1,0)
    end
    
    local active = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            active = true
            updateFromPosition(input.Position)
        end
    end)
    bar.InputEnded:Connect(function(input)
        active = false
    end)
    UserInputService.InputChanged:Connect(function(input)
        if active and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            updateFromPosition(input.Position)
        end
    end)
end

-- Заполнение вкладок
local y = 10
-- Visuals
createCheckbox(tabs.Visuals, "ESP Enabled", function() return settings.visuals.espEnabled end, function(v) settings.visuals.espEnabled = v end, y); y=y+35
createCheckbox(tabs.Visuals, "Health", function() return settings.visuals.health end, function(v) settings.visuals.health = v end, y); y=y+35
createCheckbox(tabs.Visuals, "Box", function() return settings.visuals.box end, function(v) settings.visuals.box = v end, y); y=y+35
createCheckbox(tabs.Visuals, "Line", function() return settings.visuals.line end, function(v) settings.visuals.line = v end, y); y=y+35
createCheckbox(tabs.Visuals, "Skeleton", function() return settings.visuals.skeleton end, function(v) settings.visuals.skeleton = v end, y); y=y+35
createCheckbox(tabs.Visuals, "Name", function() return settings.visuals.name end, function(v) settings.visuals.name = v end, y)

-- AimBot
y=10
createCheckbox(tabs.AimBot, "Aimbot", function() return settings.aimbot.enabled end, function(v) settings.aimbot.enabled = v end, y); y=y+35
createSlider(tabs.AimBot, "FOV", 0, 200, function() return settings.aimbot.fov end, function(v) settings.aimbot.fov = v end, y); y=y+45
createSlider(tabs.AimBot, "Distance", 0, 150, function() return settings.aimbot.distance end, function(v) settings.aimbot.distance = v end, y); y=y+45

-- Выбор триггера
local triggerBtn = Instance.new("TextButton")
triggerBtn.Size = UDim2.new(0, 150, 0, 30)
triggerBtn.Position = UDim2.new(0, 10, 0, y)
triggerBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
triggerBtn.Text = "Trigger: " .. settings.aimbot.trigger
triggerBtn.TextColor3 = Color3.new(1,1,1)
triggerBtn.Parent = tabs.AimBot
triggerBtn.MouseButton1Click:Connect(function()
    local options = {"Auto", "OnTap"}
    local idx = tableFind(options, settings.aimbot.trigger) or 1
    local newIdx = idx % #options + 1
    settings.aimbot.trigger = options[newIdx]
    triggerBtn.Text = "Trigger: " .. settings.aimbot.trigger
end)
y=y+35

-- Выбор цели
local targetBtn = Instance.new("TextButton")
targetBtn.Size = UDim2.new(0, 150, 0, 30)
targetBtn.Position = UDim2.new(0, 10, 0, y)
targetBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
targetBtn.Text = "Target: " .. settings.aimbot.targetPart
targetBtn.TextColor3 = Color3.new(1,1,1)
targetBtn.Parent = tabs.AimBot
targetBtn.MouseButton1Click:Connect(function()
    local options = {"Head", "Torso"}
    local idx = tableFind(options, settings.aimbot.targetPart) or 1
    local newIdx = idx % #options + 1
    settings.aimbot.targetPart = options[newIdx]
    targetBtn.Text = "Target: " .. settings.aimbot.targetPart
end)

-- Memory
y=10
createSlider(tabs.Memory, "Custom FOV", 1, 120, function() return settings.memory.customFOV end, function(v) settings.memory.customFOV = v applyCustomFOV() end, y); y=y+45
createSlider(tabs.Memory, "View Offset X", -5, 5, function() return settings.memory.customViewOffset.X end, function(v) settings.memory.customViewOffset = Vector3.new(v, settings.memory.customViewOffset.Y, settings.memory.customViewOffset.Z) applyCustomView() end, y); y=y+45
createSlider(tabs.Memory, "View Offset Y", -5, 5, function() return settings.memory.customViewOffset.Y end, function(v) settings.memory.customViewOffset = Vector3.new(settings.memory.customViewOffset.X, v, settings.memory.customViewOffset.Z) applyCustomView() end, y); y=y+45
createSlider(tabs.Memory, "View Offset Z", -5, 5, function() return settings.memory.customViewOffset.Z end, function(v) settings.memory.customViewOffset = Vector3.new(settings.memory.customViewOffset.X, settings.memory.customViewOffset.Y, v) applyCustomView() end, y)

-- Открытие/закрытие меню по кнопке
toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    settings.menuOpen = mainFrame.Visible
end)

-- Основные циклы
game:GetService("RunService").RenderStepped:Connect(function()
    drawESP()
    aimbot()
    applyCustomFOV()
    applyCustomView()
end)

-- Настройка камеры для кастомного вида
wait(1)
applyCustomView()