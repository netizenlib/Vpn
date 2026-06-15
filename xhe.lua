--[[
    ROBLOX SCRIPT: ESP + Aimbot + Custom View
    Всё работает автоматически после запуска.
    Никаких кнопок и меню.
--]]

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- НАСТРОЙКИ (меняй здесь под себя)
local settings = {
    -- ESP
    espEnabled = true,
    espBox = true,
    espLine = true,
    espHealth = true,
    espSkeleton = true,
    espName = true,
    -- Aimbot
    aimbotEnabled = true,
    aimbotFOV = 100,
    aimbotDistance = 100,
    aimbotTarget = "Head", -- "Head" или "Torso"
    aimbotTrigger = "Auto", -- Auto (всегда) или OnTap (при касании экрана)
    -- Камера
    customFOV = 80,
    customViewOffset = Vector3.new(0, 2, -5) -- X, Y, Z смещение (вид сверху сзади)
}

-- Вспомогательная функция: поиск в таблице
local function tableFind(tbl, val)
    for i, v in ipairs(tbl) do if v == val then return i end end
    return nil
end

-- Проверка видимости игрока (лучом)
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

-- Отрисовка ESP (создаём объекты и сразу удаляем — работает на любом executor'е)
local function drawESP()
    if not settings.espEnabled then return end
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
                
                -- Линия (от низа экрана до цели)
                if settings.espLine then
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
                if settings.espBox then
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
                if settings.espName then
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
                if settings.espHealth then
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
                if settings.espSkeleton then
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

-- Aimbot (плавный поворот камеры к цели)
local function aimbot()
    if not settings.aimbotEnabled then return end
    local closestAngle = settings.aimbotFOV
    local closestPlayer = nil
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player then
            local character = otherPlayer.Character
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                if isPlayerVisible(otherPlayer) then
                    local targetPart = character:FindFirstChild(settings.aimbotTarget) or character.PrimaryPart
                    if targetPart then
                        local targetPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
                        if onScreen then
                            local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                            local angle = (Vector2.new(targetPos.X, targetPos.Y) - screenCenter).magnitude
                            local distance = (camera.CFrame.Position - targetPart.Position).magnitude
                            if angle < closestAngle and distance <= settings.aimbotDistance then
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
        local targetPart = targetCharacter:FindFirstChild(settings.aimbotTarget) or targetCharacter.PrimaryPart
        if targetPart then
            local shouldAim = false
            if settings.aimbotTrigger == "Auto" then
                shouldAim = true
            elseif settings.aimbotTrigger == "OnTap" then
                shouldAim = UserInputService:IsTouchEnabled() and #UserInputService:GetTouchPositions() > 0
            end
            if shouldAim then
                local targetCFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
                camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.3)
            end
        end
    end
end

-- Применение кастомного FOV
local function applyCustomFOV()
    camera.FieldOfView = settings.customFOV
end

-- Применение кастомного обзора (вид от третьего лица)
local function applyCustomView()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local root = player.Character.HumanoidRootPart
        local offset = settings.customViewOffset
        local newPos = root.Position + root.CFrame:VectorToWorldSpace(offset)
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(newPos, root.Position)
    else
        camera.CameraType = Enum.CameraType.Custom
    end
end

-- Запуск всех функций в цикле
game:GetService("RunService").RenderStepped:Connect(function()
    drawESP()
    aimbot()
    applyCustomFOV()
    applyCustomView()
end)

-- Небольшая задержка для правильной инициализации камеры
wait(1)
applyCustomView()