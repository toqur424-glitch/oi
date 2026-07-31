--=============================================
-- [초기 로드 및 게임 체크]
--=============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

if game.PlaceId ~= 6961824067 then 
    Rayfield:Notify({Title = "Error", Content = "이 게임을 지원하지 않습니다.", Duration = 3})
    return 
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rs = ReplicatedStorage

--=============================================
-- [UI 생성]
--=============================================
local Window = Rayfield:CreateWindow({
    Name = "🔥 FSOF Extreme Kick Hub (Fixed)",
    LoadingTitle = "최적화 및 로딩 중...",
    LoadingSubtitle = "by Extreme Script",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [GRAB 탭] - 극대화된 킥 그랩 (F키)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (속도/고정력 최상) ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil
local fAttackTarget = nil

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer
    fAttackConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        if not myRoot or not tgtRoot then return end
        
        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        if tgtHum then tgtHum.PlatformStand = true end
        
        local camCF = camera.CFrame
        pcall(function() tgtRoot.CFrame = CFrame.new(camCF.Position + camCF.LookVector * 20) end)
        
        for i = 1, 4 do
            pcall(function()
                rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
            end)
        end
    end)
end

GrabTab:CreateKeybind({
    Name = "F키 조준 킥 그랩",
    CurrentKeybind = "F",
    Callback = function()
        if not getgenv().KickGrabActive then getgenv().KickGrabActive = true end
        if getgenv().FKeyAttackActive then 
            getgenv().FKeyAttackActive = false
            if fAttackConnection then fAttackConnection:Disconnect() end
            return 
        end
        local target = nil 
        for _, p in pairs(Players:GetPlayers()) do 
            if p ~= plr and p.Character then target = p break end 
        end
        if target then startFKeyAttack(target) end
    end
})

--=============================================
-- [KICK 탭] - 단일 타겟 셋오너 & 디트로이트 교차 고정 및 범위 이탈 감지 룹티피
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local blobLoopT4 = false
local recoveringTargets = {} 

local selectedKickPlayer = nil

KickTab:CreateInput({
    Name = "Add Target (타겟 닉네임 입력)",
    PlaceholderText = "예: Player1",
    RemoveTextAfterFocusLost = true,
    Callback = function(v)
        if v == "" then return end
        local found = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(v:lower()) or (p.DisplayName and p.DisplayName:lower():find(v:lower())) then
                found = p
                break
            end
        end
        
        if not found then 
            Rayfield:Notify({Title = "오류", Content = "해당 유저를 찾을 수 없습니다.", Duration = 2})
            return 
        end
        
        selectedKickPlayer = found
        Rayfield:Notify({Title = "타겟 설정됨", Content = found.Name .. "님이 타겟으로 설정되었습니다.", Duration = 2})
    end
})

function loopPlayerBlobF4()
    local initialized = false
    
    while blobLoopT4 do
        local player = selectedKickPlayer
        
        if not player or not player.Character then
            initialized = false
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        
        -- pcld 우선 탐색, 없으면 HRP
        local pcldPart = player.Character:FindFirstChild("pcld") or player.Character:FindFirstChild("Pcld")
        local charHRP = player.Character:FindFirstChild("HumanoidRootPart")
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        local targetPart = pcldPart or charHRP
        
        if myHRP and targetPart then
            local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
            local currentDist = (targetPart.Position - targetCF.Position).Magnitude
            
            -- 거리가 멀어지면 가져오기(Fetch) 실행
            if (currentDist > 15 or not initialized) and not recoveringTargets[name] then
                recoveringTargets[name] = true
                initialized = true 
                
                task.spawn(function()
                    local originalCF = myHRP.CFrame
                    
                    -- 1. 상대방 위치로 이동 후 '서버 인식 대기' (핵심)
                    pcall(function() myHRP.CFrame = targetPart.CFrame * CFrame.new(0, 0, 2) end)
                    task.wait(0.15) 
                    
                    -- 2. 확실하게 소유권 강탈
                    for _ = 1, 4 do
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(targetPart, CFrame.new())
                            rs.GrabEvents.SetNetworkOwner:FireServer(targetPart, CFrame.lookAt(myHRP.Position, targetPart.Position))
                        end)
                        task.wait(0.05)
                    end
                    
                    -- 3. 내 원래 자리로 타겟을 먼저 보내고 나도 복귀
                    pcall(function()
                        targetPart.CFrame = originalCF * CFrame.new(0, 20, 0)
                        targetPart.AssemblyLinearVelocity = Vector3.zero
                        myHRP.CFrame = originalCF
                    end)
                    task.wait(0.1)
                    
                    recoveringTargets[name] = false
                end)
            end
            
            -- 추적/복귀 중이 아닐 때만 룹티피(고정) 실행하여 충돌 방지
            if not recoveringTargets[name] then
                pcall(function()
                    targetPart.CFrame = targetCF
                    targetPart.AssemblyLinearVelocity = Vector3.zero
                    targetPart.AssemblyAngularVelocity = Vector3.zero
                    
                    if charHUM then
                        charHUM.PlatformStand = true
                        charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                    end
                    
                    -- 무리한 연사(for i=1,3) 삭제. 이벤트 씹힘 현상을 막고 가장 강력한 F키 로직 그대로 적용
                    rs.GrabEvents.CreateGrabLine:FireServer(targetPart, CFrame.new())
                    rs.GrabEvents.SetNetworkOwner:FireServer(targetPart, CFrame.lookAt(myHRP.Position, targetPart.Position))
                    rs.GrabEvents.DestroyGrabLine:FireServer(targetPart)
                end)
            end
        end
        RunService.RenderStepped:Wait()
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (범위 이탈 자동 추적)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            blobLoopT4 = false
            return
        end
        blobLoopT4 = v
        if v then task.spawn(loopPlayerBlobF4) end
    end
})

--=============================================
-- [새로운 Pallet Ragdoll (Invis) 통합]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis)",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
        local lpName = plr.Name

        local function clearAttackLoop()
            if getgenv().ragdollSteppedConn then
                getgenv().ragdollSteppedConn:Disconnect()
                getgenv().ragdollSteppedConn = nil
            end
        end

        if Value then
            if not selectedKickPlayer then
                Rayfield:Notify({Title = "알림", Content = "Select target first (타겟을 먼저 입력해주세요)", Duration = 3})
                return
            end

            getgenv().palletRagdollActive = true
            getgenv().PalletForRagdoll = nil
            
            if getgenv().palletCacheConn then
                getgenv().palletCacheConn:Disconnect()
            end
            clearAttackLoop()

            local toysFolder = workspace:WaitForChild(lpName .. "SpawnedInToys", 5)
            if not toysFolder then
                Rayfield:Notify({Title = "오류", Content = "생성된 토이 폴더를 찾을 수 없습니다.", Duration = 3})
                return
            end

            getgenv().palletCacheConn = toysFolder.ChildAdded:Connect(function(child)
                if not getgenv().palletRagdollActive then return end
                if child.Name ~= "PalletLightBrown" and child.Name ~= "PalletForRagdoll" then return end

                local soundPart = child:WaitForChild("SoundPart", 3)
                if not soundPart then return end

                pcall(function()
                    SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                    DestroyLine:FireServer(soundPart)
                end)

                local partOwner = soundPart:WaitForChild("PartOwner", 1)
                if partOwner and partOwner.Value == lpName then
                    for _, v in pairs(child:GetChildren()) do
                        if v:IsA("BasePart") then
                            v.CanCollide = false
                            v.CanQuery = false
                            v.Transparency = 1 
                        end
                    end

                    child.Name = "PalletForRagdoll"
                    getgenv().PalletForRagdoll = child

                    local strikePhase = false

                    getgenv().ragdollSteppedConn = RunService.Stepped:Connect(function()
                        if not getgenv().palletRagdollActive or not child.Parent then 
                            clearAttackLoop()
                            return 
                        end

                        local tChar = selectedKickPlayer and selectedKickPlayer.Character
                        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

                        if tRoot and tHum and soundPart.Parent and tHum.Health > 0 then
                            local ragdolledVal = tHum:FindFirstChild("Ragdolled")
                            local isRagdolled = ragdolledVal and ragdolledVal.Value or false

                            if not isRagdolled then
                                strikePhase = not strikePhase
                                if strikePhase then
                                    soundPart.CFrame = tRoot.CFrame * CFrame.new(0, 2, 0)
                                    soundPart.AssemblyLinearVelocity = Vector3.new(0, -9e5, 0)
                                else
                                    soundPart.CFrame = tRoot.CFrame * CFrame.new(0, -1, 0)
                                    soundPart.AssemblyLinearVelocity = Vector3.new(0, 9e5, 0)
                                end
                            else
                                soundPart.CFrame = CFrame.new(0, 9e9, 0)
                                soundPart.AssemblyLinearVelocity = Vector3.zero
                            end
                        else
                            soundPart.CFrame = CFrame.new(0, 9e9, 0)
                            soundPart.AssemblyLinearVelocity = Vector3.zero
                        end
                    end)

                    child.AncestryChanged:Connect(function()
                        if not child.Parent then
                            clearAttackLoop()
                            getgenv().PalletForRagdoll = nil
                            if getgenv().palletRagdollActive then
                                task.wait(0.03)
                                if getgenv().spawnNewPallet then getgenv().spawnNewPallet() end
                            end
                        end
                    end)
                else
                    pcall(function() DestroyToy:FireServer(child) end)
                end
            end)

            getgenv().spawnNewPallet = function()
                if not getgenv().palletRagdollActive then return end
                if getgenv().PalletForRagdoll and getgenv().PalletForRagdoll.Parent then return end
                
                local c = plr.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if not h then return end

                task.spawn(function()
                    pcall(function()
                        RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                            "PalletLightBrown",
                            h.CFrame * CFrame.new(0, 10, 20),
                            Vector3.zero
                        )
                    end)
                end)
            end

            getgenv().spawnNewPallet()
        else
            getgenv().palletRagdollActive = false
            clearAttackLoop()

            if getgenv().palletCacheConn then
                getgenv().palletCacheConn:Disconnect()
                getgenv().palletCacheConn = nil
            end

            local pallet = getgenv().PalletForRagdoll
            if pallet and pallet.Parent then
                pcall(function() DestroyToy:FireServer(pallet) end)
            end

            getgenv().PalletForRagdoll = nil

            local toysFolder = workspace:FindFirstChild(lpName .. "SpawnedInToys")
            if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then
                pcall(function() DestroyToy:FireServer(toysFolder.PalletForRagdoll) end)
            end
        end
    end,
})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local SpawnToyRemoteFunction = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
local GrabEvent = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
local DestroyToy = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy")

local Character, HumanoidRootPart
local folder

local toys = 5
local activePencils = {}

local function GetHighestGrabbableHitbox(blob)
    local highest = nil
    local highestY = -math.huge

    for _, v in ipairs(blob:GetDescendants()) do
        if v.Name == "GrabbableHitbox" and v:IsA("BasePart") then
            local y = v.Position.Y

            if y > highestY then
                highestY = y
                highest = v
            end
        end
    end

    return highest
end

local function SetupCharacter(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    folder = workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys")
end

SetupCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
LocalPlayer.CharacterAdded:Connect(SetupCharacter)

local function SpawnPencil()
    local pos = HumanoidRootPart.CFrame * CFrame.Angles(-0.605224, -0.321753, 0)

    task.spawn(function()
        SpawnToyRemoteFunction:InvokeServer(
            "ToolPencil",
            pos,
            Vector3.new(0, 0, 0)
        )
    end)
end

local function WaitForNewPencil(timeout)
    timeout = timeout or 6

    local result = nil
    local done = false

    local connection
    connection = folder.ChildAdded:Connect(function(child)
        if child.Name == "ToolPencil" then
            result = child
            done = true
        end
    end)

    local start = tick()

    while not done and tick() - start < timeout do
        task.wait()
    end

    connection:Disconnect()

    return result
end

local function ApplyPermanentLift(pencil)
    local soundPart = pencil:FindFirstChild("SoundPart")
    if not soundPart then
        return
    end

    for _, v in ipairs(soundPart:GetChildren()) do
        if v:IsA("LinearVelocity") then
            v:Destroy()
        end
    end

    local att = Instance.new("Attachment")
    att.Parent = soundPart
end

local function CreateOnePencil()
    while true do
        SpawnPencil()

        local pencil = WaitForNewPencil()
        if not pencil then
            task.wait(0.2)
            continue
        end

        task.wait(0.19)
        pencil.StickyPart.CanTouch = false

        local soundPart = pencil:FindFirstChild("SoundPart")
        if not soundPart then
            continue
        end

        GrabEvent:FireServer(soundPart, soundPart.CFrame)

        task.wait(0.15)

        local owner = soundPart:FindFirstChild("PartOwner")

        if owner and owner.Value == LocalPlayer.Name then
            table.insert(activePencils, pencil)

            ApplyPermanentLift(pencil)

            return true
        else
            DestroyToy:FireServer(pencil)
        end

        task.wait(0.2)
    end
end

function KickPlayerOnBlob(blob)
    local target = 1
    local created = 0

    while created < target do
        if CreateOnePencil() then
            created += 1
        end

        task.wait(0.4)
    end

    for _, pencil in ipairs(activePencils) do
        if pencil and pencil.Parent then
            game:GetService("ReplicatedStorage").GrabEvents.DestroyGrabLine:FireServer(pencil:FindFirstChildOfClass("BasePart"))

            local args = {
                [1] = pencil.StickyPart,
                [2] = blob:GetChildren()[20],
                [3] = CFrame.new(1e45, math.huge, 1e98)
            }

            game:GetService("ReplicatedStorage").PlayerEvents.StickyPartEvent:FireServer(unpack(args))
        end
    end
end

function KickPlayerOnBlob12Kunai(blob)
    local target = 12
    local created = 0

    while created < target do
        if CreateOnePencil() then
            created += 1
        end

        task.wait(0.4)
    end

    for _, pencil in ipairs(activePencils) do
        if pencil and pencil.Parent then
            game:GetService("ReplicatedStorage").GrabEvents.DestroyGrabLine:FireServer(pencil:FindFirstChildOfClass("BasePart"))

            local args = {
                [1] = pencil.StickyPart,
                [2] = blob:GetChildren()[20],
                [3] = CFrame.new(1e45, math.huge, 1e98)
            }

            game:GetService("ReplicatedStorage").PlayerEvents.StickyPartEvent:FireServer(unpack(args))
        end
    end
end

function BreakMap()
    local target = 1
    local created = 0

    while created < target do
        if CreateOnePencil() then
            created += 1
        end

        task.wait(0.4)
    end

    for _, pencil in ipairs(activePencils) do
        if pencil and pencil.Parent then
            game:GetService("ReplicatedStorage").GrabEvents.DestroyGrabLine:FireServer(pencil:FindFirstChildOfClass("BasePart"))

            local args = {
                [1] = pencil.StickyPart,
                [2] = workspace.Map.BaseGround:GetChildren()[154],
                [3] = CFrame.new(1e45, math.huge, 1e98)
            }

            game:GetService("ReplicatedStorage").PlayerEvents.StickyPartEvent:FireServer(unpack(args))
        end
    end
end

function BreakPlot(...)
    local plots = { ... }
    local target = #plots

    local created = 0
    local pencils = {}

    while created < target do
        if CreateOnePencil() then
            created += 1

            local pencil = activePencils[#activePencils]
            table.insert(pencils, pencil)
        end

        task.wait(0.4)
    end

    for i, plot in ipairs(plots) do
        local pencil = pencils[i]

        if typeof(pencil) == "Instance" and pencil.Parent then
            game:GetService("ReplicatedStorage").GrabEvents.DestroyGrabLine:FireServer(
                pencil:FindFirstChildOfClass("BasePart")
            )

            game:GetService("ReplicatedStorage").PlayerEvents.StickyPartEvent:FireServer(
                pencil.StickyPart,
                plot.PlotArea,
                CFrame.new(0 / 0, math.huge, 0 / 0)
            )
        end
    end
end

-- ========================================== --
-- ||           GUI BUTTON SETUP           || --
-- ========================================== --

local CoreGui = game:GetService("CoreGui")

-- 기존에 켜져있는 UI가 있다면 삭제 (중복 실행 방지)
if CoreGui:FindFirstChild("GitHubScriptUI") then
    CoreGui.GitHubScriptUI:Destroy()
end

-- ScreenGui 생성
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GitHubScriptUI"
ScreenGui.Parent = CoreGui

-- 메인 프레임 생성
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- 둥근 모서리 적용
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- UI 제목
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "Script Menu"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = MainFrame

-- Break Map 버튼
local BreakMapBtn = Instance.new("TextButton")
BreakMapBtn.Size = UDim2.new(1, -20, 0, 40)
BreakMapBtn.Position = UDim2.new(0, 10, 0, 40)
BreakMapBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
BreakMapBtn.Text = "Break Map"
BreakMapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BreakMapBtn.Font = Enum.Font.SourceSansSemibold
BreakMapBtn.TextSize = 16
BreakMapBtn.Parent = MainFrame

local BtnCorner1 = Instance.new("UICorner")
BtnCorner1.CornerRadius = UDim.new(0, 6)
BtnCorner1.Parent = BreakMapBtn

-- Break Map 버튼 클릭 이벤트
BreakMapBtn.MouseButton1Click:Connect(function()
    BreakMap()
end)

-- Break Plot 3 버튼
local BreakPlotBtn = Instance.new("TextButton")
BreakPlotBtn.Size = UDim2.new(1, -20, 0, 40)
BreakPlotBtn.Position = UDim2.new(0, 10, 0, 90)
BreakPlotBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
BreakPlotBtn.Text = "Break Plot 3"
BreakPlotBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BreakPlotBtn.Font = Enum.Font.SourceSansSemibold
BreakPlotBtn.TextSize = 16
BreakPlotBtn.Parent = MainFrame

local BtnCorner2 = Instance.new("UICorner")
BtnCorner2.CornerRadius = UDim.new(0, 6)
BtnCorner2.Parent = BreakPlotBtn

-- Break Plot 3 버튼 클릭 이벤트
BreakPlotBtn.MouseButton1Click:Connect(function()
    if workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild("Plot3") then
        BreakPlot(workspace.Plots.Plot3)
    end
end)

--=============================================
-- [나머지 필수 탭들 유지]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "서버 딜레이 안정화 및 고정 로직 최적화 완료", Duration = 3})
