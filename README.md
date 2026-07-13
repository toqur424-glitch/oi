local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local mouse = plr:GetMouse()
local rs = ReplicatedStorage

local NCP = false
local Processing = false
local dragging = false
local dragStart = nil
local startPos = nil
local dragInput = nil

-- 💥 로블록스 물리 엔진을 터뜨려 찢어버리는 극한의 좌표
local VOID_CFRAME = CFrame.new(107.5, 9.00000049e+33, -3.86856262e+25, 1, 0, 0, 0, 0.0662516952, -0.997802973, 0, 0.997802973, 0.0662516952)

local function Notify(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = duration or 3,
    })
end

-- GUI 생성 파트
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VoidDestroyerGUI"
ScreenGui.Parent = plr:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 280, 0, 380)
MainFrame.Position = UDim2.new(0.5, -140, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 16)
Corner.Parent = MainFrame

local Shadow = Instance.new("UIStroke")
Shadow.Color = Color3.fromRGB(255, 50, 50)
Shadow.Thickness = 2
Shadow.Transparency = 0.4
Shadow.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = MainFrame
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Position = UDim2.new(0, 0, 0, 5)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🌪️ Void Destroyer GUI"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.GothamBold

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Parent = MainFrame
StatusLabel.Size = UDim2.new(1, 0, 0, 22)
StatusLabel.Position = UDim2.new(0, 0, 0, 38)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "⚪ Status: OFF"
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.GothamMedium

local TargetLabel = Instance.new("TextLabel")
TargetLabel.Parent = MainFrame
TargetLabel.Size = UDim2.new(1, 0, 0, 20)
TargetLabel.Position = UDim2.new(0, 0, 0, 62)
TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "🎯 Target: None"
TargetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
TargetLabel.TextSize = 12
TargetLabel.Font = Enum.Font.GothamMedium

local PlayerNameLabel = Instance.new("TextLabel")
PlayerNameLabel.Parent = MainFrame
PlayerNameLabel.Size = UDim2.new(1, 0, 0, 18)
PlayerNameLabel.Position = UDim2.new(0, 0, 0, 82)
PlayerNameLabel.BackgroundTransparency = 1
PlayerNameLabel.Text = "👤 Player: None"
PlayerNameLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
PlayerNameLabel.TextSize = 12
PlayerNameLabel.Font = Enum.Font.GothamMedium

local TargetInput = Instance.new("TextBox")
TargetInput.Name = "TargetInput"
TargetInput.Parent = MainFrame
TargetInput.Size = UDim2.new(0.85, 0, 0, 28)
TargetInput.Position = UDim2.new(0.075, 0, 0, 105)
TargetInput.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
TargetInput.BackgroundTransparency = 0.2
TargetInput.BorderSizePixel = 0
TargetInput.Text = ""
TargetInput.PlaceholderText = "🔍 Type Player Name..."
TargetInput.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetInput.TextSize = 13
TargetInput.Font = Enum.Font.Gotham
Instance.new("UICorner", TargetInput).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", TargetInput).Color = Color3.fromRGB(0, 200, 255)

local ToggleButton = Instance.new("TextButton")
ToggleButton.Parent = MainFrame
ToggleButton.Size = UDim2.new(0.85, 0, 0, 32)
ToggleButton.Position = UDim2.new(0.075, 0, 0, 140)
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
ToggleButton.Text = "🔴 OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 15
ToggleButton.Font = Enum.Font.GothamBold
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 8)
local BtnStroke = Instance.new("UIStroke", ToggleButton)
BtnStroke.Color = Color3.fromRGB(255, 100, 100)

local DeletePartBtn = Instance.new("TextButton")
DeletePartBtn.Parent = MainFrame
DeletePartBtn.Size = UDim2.new(0.85, 0, 0, 32)
DeletePartBtn.Position = UDim2.new(0.075, 0, 0, 178)
DeletePartBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
DeletePartBtn.Text = "📌 Delete Part (Q)"
DeletePartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DeletePartBtn.TextSize = 14
DeletePartBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", DeletePartBtn).CornerRadius = UDim.new(0, 8)

local KillPlayerBtn = Instance.new("TextButton")
KillPlayerBtn.Parent = MainFrame
KillPlayerBtn.Size = UDim2.new(0.85, 0, 0, 32)
KillPlayerBtn.Position = UDim2.new(0.075, 0, 0, 216)
KillPlayerBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
KillPlayerBtn.Text = "💀 Kill Player (E)"
KillPlayerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
KillPlayerBtn.TextSize = 14
KillPlayerBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", KillPlayerBtn).CornerRadius = UDim.new(0, 8)

local DestroyButton = Instance.new("TextButton")
DestroyButton.Parent = MainFrame
DestroyButton.Size = UDim2.new(0.85, 0, 0, 32)
DestroyButton.Position = UDim2.new(0.075, 0, 0, 270)
DestroyButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
DestroyButton.Text = "🗑️ Destroy All Toys"
DestroyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DestroyButton.TextSize = 14
DestroyButton.Font = Enum.Font.GothamBold
Instance.new("UICorner", DestroyButton).CornerRadius = UDim.new(0, 8)

local ClearShurikenButton = Instance.new("TextButton")
ClearShurikenButton.Parent = MainFrame
ClearShurikenButton.Size = UDim2.new(0.85, 0, 0, 32)
ClearShurikenButton.Position = UDim2.new(0.075, 0, 0, 308)
ClearShurikenButton.BackgroundColor3 = Color3.fromRGB(150, 50, 150)
ClearShurikenButton.Text = "🔪 Clear All Shurikens"
ClearShurikenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearShurikenButton.TextSize = 14
ClearShurikenButton.Font = Enum.Font.GothamBold
Instance.new("UICorner", ClearShurikenButton).CornerRadius = UDim.new(0, 8)

local function UpdateUI()
    if NCP then
        StatusLabel.Text = "🟢 Status: ON"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        ToggleButton.Text = "🟢 ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        Shadow.Color = Color3.fromRGB(0, 255, 100)
        BtnStroke.Color = Color3.fromRGB(0, 255, 100)
    else
        StatusLabel.Text = "⚪ Status: OFF"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        ToggleButton.Text = "🔴 OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        Shadow.Color = Color3.fromRGB(255, 50, 50)
        BtnStroke.Color = Color3.fromRGB(255, 100, 100)
    end
end

ToggleButton.MouseButton1Click:Connect(function()
    NCP = not NCP
    UpdateUI()
end)

local function GetPlayerFromInput()
    local text = string.lower(TargetInput.Text)
    if text == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            if string.sub(string.lower(p.Name), 1, #text) == text or string.sub(string.lower(p.DisplayName), 1, #text) == text then
                return p
            end
        end
    end
    return nil
end

local function GetPlayerFromPart(part)
    if not part then return nil end
    local current = part
    while current and current ~= Workspace do
        if current:IsA("Model") and current:FindFirstChild("Humanoid") then
            return Players:GetPlayerFromCharacter(current)
        end
        current = current.Parent
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    local lockedPlayer = GetPlayerFromInput()
    if lockedPlayer then
        TargetLabel.Text = "🎯 Target: [Locked] " .. lockedPlayer.Name
        PlayerNameLabel.Text = "👤 Player: " .. lockedPlayer.DisplayName
    else
        local tt = mouse.Target
        if tt and tt:IsA("BasePart") then
            local player = GetPlayerFromPart(tt)
            TargetLabel.Text = "🎯 Target: " .. (player and ("["..player.Name.."] "..tt.Name) or tt.Name)
            PlayerNameLabel.Text = "👤 Player: " .. (player and player.Name or "None")
        else
            TargetLabel.Text = "🎯 Target: None"
            PlayerNameLabel.Text = "👤 Player: None"
        end
    end
end)

-- 🎯 실시간 강제 부착 및 우주 추방 함수 (스폰 위치 버그 수정 버전)
local function AttackTargetCharacter(targetChar, actionName)
    if not NCP or Processing or not targetChar then return end
    
    local char = plr.Character or plr.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    
    if not hrp or not torso or not inv then return end
    Processing = true

    -- 🛡️ [보안 강화] 내 캐릭터 정면 8스턴 앞, 3스턴 위 공중에 안전하게 소환 (내 머리/몸뚱이에 붙는 스폰 버그 영구 방지)
    local safeSpawnCFrame = hrp.CFrame * CFrame.new(0, 3, -8)

    task.spawn(function()
        pcall(function() rs.MenuToys.SpawnToyRemoteFunction:InvokeServer("NinjaShuriken", safeSpawnCFrame, Vector3.zero) end)
    end)

    local kunai = nil
    for i = 1, 30 do
        task.wait(0.05)
        kunai = inv:FindFirstChild("NinjaShuriken")
        if kunai then break end
    end

    if not kunai then 
        Notify("⚠️ Error", "Failed to spawn toy.", 2)
        Processing = false 
        return 
    end

    local stickyPart = kunai:FindFirstChild("StickyPart")
    local soundPart = kunai:FindFirstChild("SoundPart")

    if stickyPart and soundPart then
        local hitPart = nil
        local children = targetChar:GetChildren()
        
        for _, child in ipairs(children) do
            if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
                hitPart = child
                break
            end
        end
        
        if not hitPart then
            hitPart = targetChar:FindFirstChildWhichIsA("BasePart")
        end

        if hitPart then
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(soundPart, CFrame.lookAt(torso.Position, soundPart.Position))
                task.wait(0.05)
                rs.PlayerEvents.StickyPartEvent:FireServer(stickyPart, hitPart, VOID_CFRAME)
            end)
            Notify("✅ " .. actionName, "Successfully attached to " .. hitPart.Name .. "!", 2)
        else
            Notify("⚠️ Error", "No hittable part found!", 2)
        end
    end

    kunai.Name = "" 
    Processing = false
end

-- 1. 파트(땅) 지우기 함수 (스폰 위치 버그 수정 버전)
local function DeletePart()
    local tt = mouse.Target
    if not tt or not tt:IsA("BasePart") then return end
    
    if tt.Name == "PlotBarrier" then 
        local success, check = pcall(function() return tt.Parent.Parent:FindFirstChild("PlotArea") end)
        if success and check and check:IsA("BasePart") then tt = check else return end
    end
    
    if not NCP or Processing then return end
    local char = plr.Character or plr.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    if not hrp or not torso or not inv then return end
    
    Processing = true
    
    -- 🛡️ [보안 강화] 동일한 안전 소환 구역 적용
    local safeSpawnCFrame = hrp.CFrame * CFrame.new(0, 3, -8)
    
    task.spawn(function() pcall(function() rs.MenuToys.SpawnToyRemoteFunction:InvokeServer("NinjaShuriken", safeSpawnCFrame, Vector3.zero) end) end)
    local kunai = nil
    for i = 1, 30 do task.wait(0.05) kunai = inv:FindFirstChild("NinjaShuriken") if kunai then break end end
    if kunai then
        local stickyPart = kunai:FindFirstChild("StickyPart")
        local soundPart = kunai:FindFirstChild("SoundPart")
        if stickyPart and soundPart then
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(soundPart, CFrame.lookAt(torso.Position, soundPart.Position))
                task.wait(0.05)
                rs.PlayerEvents.StickyPartEvent:FireServer(stickyPart, tt, VOID_CFRAME)
            end)
        end
        kunai.Name = ""
    end
    Processing = false
end

-- 2. 플레이어 죽이기 함수 (E 키)
local function KillPlayer()
    local targetPlayer = GetPlayerFromInput()
    local targetChar = nil
    
    if targetPlayer then
        targetChar = targetPlayer.Character
    else
        local tt = mouse.Target
        if tt then
            targetPlayer = GetPlayerFromPart(tt)
            if targetPlayer then
                targetChar = targetPlayer.Character
            end
        end
    end

    if not targetChar or not targetPlayer then 
        Notify("⚠️ Warning", "No valid target character found!", 2)
        return 
    end
    
    if targetPlayer == plr then
        Notify("⚠️ Error", "You can't kill yourself!", 2)
        return
    end

    AttackTargetCharacter(targetChar, "Player Murdered")
end

DeletePartBtn.MouseButton1Click:Connect(DeletePart)
KillPlayerBtn.MouseButton1Click:Connect(KillPlayer)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and NCP then
        if UserInputService:GetFocusedTextBox() then return end
        
        if input.KeyCode == Enum.KeyCode.Q then
            DeletePart() 
        elseif input.KeyCode == Enum.KeyCode.E then
            KillPlayer()
        end
    end
end)

-- 나머지 청소 함수들
local function DestroyAllToys()
    local toyFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    if toyFolder then
        local count = 0
        for _, toy in ipairs(toyFolder:GetChildren()) do
            if toy.Name ~= "ToyNumber" and toy.Name ~= "완전한 사람" and not Players:GetPlayerFromCharacter(toy) then
                pcall(function() rs:WaitForChild("MenuToys"):WaitForChild("DestroyToy"):FireServer(toy) count = count + 1 end)
            end
        end
        Notify("🗑️ Cleaned", count .. " toys destroyed!", 2)
    end
end

local function ClearAllShurikens()
    local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    if not inv then return end
    local count = 0
    local destroyRemote = rs:FindFirstChild("MenuToys") and rs.MenuToys:FindFirstChild("DestroyToy")
    if destroyRemote then
        for _, child in pairs(inv:GetChildren()) do
            if child.Name == "NinjaShuriken" or child.Name == "" then
                pcall(function() destroyRemote:FireServer(child) count = count + 1 end)
            end
        end
        Notify("🔪 Cleared", count .. " shurikens deleted!", 2)
    end
end

DestroyButton.MouseButton1Click:Connect(DestroyAllToys)
ClearShurikenButton.MouseButton1Click:Connect(ClearAllShurikens)

-- UI 드래그 기능
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if UserInputService:GetFocusedTextBox() then return end
        dragging = true dragStart = input.Position startPos = MainFrame.Position
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
        if dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)
MainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

UpdateUI()
