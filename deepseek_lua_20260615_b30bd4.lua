--[[
    ROBLOX SCRIPT: Комплексный чит с ESP и Aimbot
    Функции:
    - Меню с вкладками (Visuals, AimBot, Memory)
    - Открытие/закрытие по клавише Insert
    - ESP: здоровье, бокс, линия, скелет, имя
    - Aimbot с проверкой видимости, FOV, дистанция, цель (голова/туловище)
    - Кастомный FOV камеры, кастомный вид камеры (смещение)
--]]

-- Создание GUI меню
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

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
        fov = 100,        -- градусы
        distance = 100,   -- студия
        trigger = "Auto", -- или "OnKey"
        targetPart = "Head", -- или "Torso"
        key = "MouseButton2" -- правая кнопка мыши
    },
    memory = {
        customFOV = 70,    -- стандартное поле зрения
        customViewOffset = Vector3.new(0, 0, 0) -- смещение камеры (вид от третьего лица)
    }
}

-- Функция для проверки видимости игрока (Raycast)
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
        local hitPart = result.Instance
        -- если луч попал в часть врага, то видим
        if hitPart:IsDescendantOf(character) then
            return true
        else
            return false
        end
    else
        return true -- если луч не попал ни во что, значит цель видна (на открытой местности)
    end
end

-- Функция для получения позиции скелета (приблизительно)
local function getSkeletonPoints(character)
    local parts = {
        Head = character:FindFirstChild("Head"),
        UpperTorso = character:FindFirstChild("UpperTorso"),
        LowerTorso = character:FindFirstChild("LowerTorso"),
        LeftArm = character:FindFirstChild("LeftArm"),
        RightArm = character:FindFirstChild("RightArm"),
        LeftLeg = character:FindFirstChild("LeftLeg"),
        RightLeg = character:FindFirstChild("RightLeg")
    }
    return parts
end

-- Рисование ESP
local function drawESP()
    if not settings.visuals.espEnabled then return end
    local players = game.Players:GetPlayers()
    for _, otherPlayer in ipairs(players) do
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
                
                -- Линия к цели
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
                
                -- Скелет (соединяем части)
                if settings.visuals.skeleton then
                    local parts = getSkeletonPoints(character)
                    local connections = {
                        {parts.Head, parts.UpperTorso},
                        {parts.UpperTorso, parts.LowerTorso},
                        {parts.UpperTorso, parts.LeftArm},
                        {parts.UpperTorso, parts.RightArm},
                        {parts.LowerTorso, parts.LeftLeg},
                        {parts.LowerTorso, parts.RightLeg}
                    }
                    for _, pair in ipairs(connections) do
                        local partA, partB = pair[1], pair[2]
                        if partA and partB then
                            local posA, visA = camera:WorldToScreenPoint(partA.Position)
                            local posB, visB = camera:WorldToScreenPoint(partB.Position)
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

-- Функция для аимбота (наводит на ближайшую цель в пределах FOV)
local function aimbot()
    if not settings.aimbot.enabled then return end
    local closestAngle = settings.aimbot.fov
    local closestPlayer = nil
    local targetPartName = settings.aimbot.targetPart
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player then
            local character = otherPlayer.Character
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                -- Проверка видимости
                if isPlayerVisible(otherPlayer) then
                    local targetPart = character:FindFirstChild(targetPartName) or character.PrimaryPart
                    if targetPart then
                        local targetPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
                        if onScreen then
                            local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                            local angle = (Vector2.new(targetPos.X, targetPos.Y) - screenCenter).magnitude
                            -- Проверка расстояния
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
            -- Вычисляем угол поворота камеры (простой способ: сдвиг мыши)
            local targetScreen, isOnScreen = camera:WorldToScreenPoint(targetPart.Position)
            if isOnScreen then
                local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                local deltaX = targetScreen.X - screenCenter.X
                local deltaY = targetScreen.Y - screenCenter.Y
                -- Двигаем мышь (если активация по клавише)
                if settings.aimbot.trigger == "OnKey" then
                    if mouse.Button1Down or (settings.aimbot.key == "MouseButton2" and mouse.Button2Down) then
                        mousemoverel(deltaX, deltaY)
                    end
                else -- Auto
                    mousemoverel(deltaX, deltaY)
                end
            end
        end
    end
end

-- Применение кастомного FOV
local function applyCustomFOV()
    camera.FieldOfView = settings.memory.customFOV
end

-- Применение смещения камеры (Custom View)
local function applyCustomView()
    -- Пример: меняем CFrame камеры на позицию над плечом
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local root = player.Character.HumanoidRootPart
        local offset = settings.memory.customViewOffset
        local newPos = root.Position + root.CFrame:VectorToWorldSpace(offset)
        camera.CFrame = CFrame.new(newPos, root.Position)
    end
end

-- Создание GUI (простого меню)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CheatMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

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

local tabButtons = {
    Visuals = Instance.new("TextButton"),
    AimBot = Instance.new("TextButton"),
    Memory = Instance.new("TextButton")
}
local tabs = {
    Visuals = Instance.new("ScrollingFrame"),
    AimBot = Instance.new("ScrollingFrame"),
    Memory = Instance.new("ScrollingFrame")
}
local xPos = 10
for name, btn in pairs(tabButtons) do
    btn.Size = UDim2.new(0, 90, 0, 30)
    btn.Position = UDim2.new(0, xPos, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = mainFrame
    btn.MouseButton1Click:Connect(function()
        for _,frame in pairs(tabs) do frame.Visible = false end
        tabs[name].Visible = true
        settings.tab = name
    end)
    xPos = xPos + 95
end

-- Создание вкладок
local function createCheckbox(parent, text, getter, setter, x, y)
    local cb = Instance.new("TextButton")
    cb.Size = UDim2.new(0, 150, 0, 30)
    cb.Position = UDim2.new(0, x, 0, y)
    cb.BackgroundColor3 = Color3.fromRGB(40,40,40)
    cb.Text = text .. ": OFF"
    cb.TextColor3 = Color3.new(1,1,1)
    cb.Parent = parent
    cb.MouseButton1Click:Connect(function()
        setter(not getter())
        cb.Text = text .. ": " .. (getter() and "ON" or "OFF")
    end)
    return cb
end

local function createSlider(parent, text, min, max, getter, setter, x, y)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(0, 200, 0, 40)
    sliderFrame.Position = UDim2.new(0, x, 0, y)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,0,20)
    label.Text = text .. ": " .. tostring(getter())
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.Parent = sliderFrame
    
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,10)
    bar.Position = UDim2.new(0,0,0,25)
    bar.BackgroundColor3 = Color3.fromRGB(100,100,100)
    bar.Parent = sliderFrame
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(0,200,0)
    fill.Size = UDim2.new((getter()-min)/(max-min), 0, 1,0)
    fill.Parent = bar
    
    local function updateSlider(input)
        local newVal = min + (input.Position.X.Scale) * (max-min)
        newVal = math.clamp(newVal, min, max)
        setter(newVal)
        label.Text = text .. ": " .. tostring(math.floor(newVal))
        fill.Size = UDim2.new((newVal-min)/(max-min), 0, 1,0)
    end
    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input)
        end
    end)
    bar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Заполнение вкладок
for name, frame in pairs(tabs) do
    frame.Size = UDim2.new(1,0,1,-60)
    frame.Position = UDim2.new(0,0,0,60)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    frame.BorderSizePixel = 0
    frame.CanvasSize = UDim2.new(0,0,0,300)
    frame.ScrollBarThickness = 6
    frame.Visible = false
    frame.Parent = mainFrame
end

-- Visuals
local yOff = 10
createCheckbox(tabs.Visuals, "ESP Enabled", function() return settings.visuals.espEnabled end, function(v) settings.visuals.espEnabled = v end, 10, yOff); yOff = yOff+35
createCheckbox(tabs.Visuals, "Health", function() return settings.visuals.health end, function(v) settings.visuals.health = v end, 10, yOff); yOff=yOff+35
createCheckbox(tabs.Visuals, "Box", function() return settings.visuals.box end, function(v) settings.visuals.box = v end, 10, yOff); yOff=yOff+35
createCheckbox(tabs.Visuals, "Line", function() return settings.visuals.line end, function(v) settings.visuals.line = v end, 10, yOff); yOff=yOff+35
createCheckbox(tabs.Visuals, "Skeleton", function() return settings.visuals.skeleton end, function(v) settings.visuals.skeleton = v end, 10, yOff); yOff=yOff+35
createCheckbox(tabs.Visuals, "Name", function() return settings.visuals.name end, function(v) settings.visuals.name = v end, 10, yOff)

-- AimBot
yOff = 10
createCheckbox(tabs.AimBot, "Aimbot", function() return settings.aimbot.enabled end, function(v) settings.aimbot.enabled = v end, 10, yOff); yOff=yOff+35
createSlider(tabs.AimBot, "FOV", 0, 200, function() return settings.aimbot.fov end, function(v) settings.aimbot.fov = v end, 10, yOff); yOff=yOff+45
createSlider(tabs.AimBot, "Distance", 0, 150, function() return settings.aimbot.distance end, function(v) settings.aimbot.distance = v end, 10, yOff); yOff=yOff+45
-- Trigger Type
local triggerDrop = Instance.new("TextButton")
triggerDrop.Size = UDim2.new(0, 150, 0, 30)
triggerDrop.Position = UDim2.new(0, 10, 0, yOff)
triggerDrop.BackgroundColor3 = Color3.fromRGB(40,40,40)
triggerDrop.Text = "Trigger: " .. settings.aimbot.trigger
triggerDrop.TextColor3 = Color3.new(1,1,1)
triggerDrop.Parent = tabs.AimBot
triggerDrop.MouseButton1Click:Connect(function()
    local options = {"Auto", "OnKey"}
    local current = settings.aimbot.trigger
    local newIdx = (table.find(options, current) % #options) + 1
    settings.aimbot.trigger = options[newIdx]
    triggerDrop.Text = "Trigger: " .. settings.aimbot.trigger
end)
yOff=yOff+35
-- Target Part
local targetDrop = Instance.new("TextButton")
targetDrop.Size = UDim2.new(0, 150, 0, 30)
targetDrop.Position = UDim2.new(0, 10, 0, yOff)
targetDrop.BackgroundColor3 = Color3.fromRGB(40,40,40)
targetDrop.Text = "Target: " .. settings.aimbot.targetPart
targetDrop.TextColor3 = Color3.new(1,1,1)
targetDrop.Parent = tabs.AimBot
targetDrop.MouseButton1Click:Connect(function()
    local options = {"Head", "Torso"}
    local current = settings.aimbot.targetPart
    local newIdx = (table.find(options, current) % #options) + 1
    settings.aimbot.targetPart = options[newIdx]
    targetDrop.Text = "Target: " .. settings.aimbot.targetPart
end)

-- Memory
yOff = 10
createSlider(tabs.Memory, "Custom FOV", 1, 120, function() return settings.memory.customFOV end, function(v) settings.memory.customFOV = v; applyCustomFOV() end, 10, yOff); yOff=yOff+45
createSlider(tabs.Memory, "Custom View X", -10, 10, function() return settings.memory.customViewOffset.X end, function(v) settings.memory.customViewOffset = Vector3.new(v, settings.memory.customViewOffset.Y, settings.memory.customViewOffset.Z); applyCustomView() end, 10, yOff); yOff=yOff+45
createSlider(tabs.Memory, "Custom View Y", -10, 10, function() return settings.memory.customViewOffset.Y end, function(v) settings.memory.customViewOffset = Vector3.new(settings.memory.customViewOffset.X, v, settings.memory.customViewOffset.Z); applyCustomView() end, 10, yOff); yOff=yOff+45
createSlider(tabs.Memory, "Custom View Z", -10, 10, function() return settings.memory.customViewOffset.Z end, function(v) settings.memory.customViewOffset = Vector3.new(settings.memory.customViewOffset.X, settings.memory.customViewOffset.Y, v); applyCustomView() end, 10, yOff)

-- Открытие/закрытие меню по Insert
local userInputService = game:GetService("UserInputService")
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        settings.menuOpen = not settings.menuOpen
        mainFrame.Visible = settings.menuOpen
    end
end)

-- Основные циклы
game:GetService("RunService").RenderStepped:Connect(function()
    if settings.visuals.espEnabled then
        drawESP()
    end
    aimbot()
    applyCustomFOV()
    applyCustomView()
end)