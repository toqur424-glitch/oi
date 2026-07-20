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

-- =====================================================================
-- [ 판자 레그돌 코어 로직 ] (UI 로드 전 미리 함수 정의)
-- =====================================================================
local MenuToys = rs:WaitForChild("MenuToys", 5)
local GrabEvents = rs:WaitForChild("GrabEvents", 5)

local isActive = false
local ragdollConnection
local palletToy
local ragdollTargetName = "" -- 레그돌 타겟 저장용 변수

local function StopPalletRagdoll()
    isActive = false
    if ragdollConnection then
        ragdollConnection:Disconnect()
        ragdollConnection = nil
    end
    if palletToy and palletToy.Parent then
        local DestroyToy = MenuToys:FindFirstChild("DestroyToy")
        if DestroyToy then DestroyToy:FireServer(palletToy) end
    end
end

local function StartPalletRagdoll(targetName)
    StopPalletRagdoll() 
    isActive = true

    local targetPlayer = nil
    -- 입력한 이름과 일치하는 유저 찾기 (대소문자 무관, 부분 일치 지원)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(targetName:lower()) or (p.DisplayName and p.DisplayName:lower():find(targetName:lower())) then
            targetPlayer = p
            break
        end
    end

    if not targetPlayer then 
        Rayfield:Notify({Title = "오류", Content = "해당 유저를 찾을 수 없습니다.", Duration = 2})
        isActive = false
        return 
    end

    local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local SpawnToy = MenuToys:FindFirstChild("SpawnToyRemoteFunction")
    local SetNetOwner = GrabEvents:FindFirstChild("SetNetworkOwner")
    local DestroyLine = GrabEvents:FindFirstChild("DestroyGrabLine")

    if not (SpawnToy and SetNetOwner and DestroyLine) then return end

    -- 판자 소환
    SpawnToy:InvokeServer("PalletLightBrown", myHRP.CFrame * CFrame.new(0, 10, 20), Vector3.zero)

    local toysFolder = workspace:WaitForChild(plr.Name .. "SpawnedInToys", 5)
    if not toysFolder then return end

    palletToy = toysFolder:WaitForChild("PalletLightBrown", 5)
    if not palletToy then return end

    local soundPart = palletToy:WaitForChild("SoundPart", 3)
    if not soundPart then return end

    -- 네트워크 소유권 및 투명화 처리
    SetNetOwner:FireServer(soundPart, soundPart.CFrame)
    DestroyLine:FireServer(soundPart)

    for _, part in pairs(palletToy:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
            part.Transparency = 1 
        end
    end

    local strikePhase = false

    -- 물리 타격 루프 (RunService.Stepped 사용)
    ragdollConnection = RunService.Stepped:Connect(function()
        if not isActive or not palletToy.Parent then 
            StopPalletRagdoll()
            return 
        end

        local tChar = targetPlayer.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

        if tRoot and tHum and tHum.Health > 0 then
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
end

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
-- [KICK 탭] - 극대화된 블롭맨 셋오너 킥
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨)", nil)
local blobLoopT4 = false
local kickTargetList = {}
local recoveringTargets = {} 

local function updateTargetList()
    kickTargetList = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= plr then table.insert(kickTargetList, p.Name) end
    end
end

function loopPlayerBlobF4()
    local initializedTargets = {}
    local frameToggle = false
    
    while blobLoopT4 do
        updateTargetList()
        for _, name in pairs(kickTargetList) do
            local player = Players:FindFirstChild(name)
            local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            
            if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
                initializedTargets[name] = nil
                continue
            end

            local charHRP = player.Character.HumanoidRootPart
            local charHUM = player.Character:FindFirstChild("Humanoid")
            
            if myHRP and charHRP and charHUM then
                if ((charHRP.Position - myHRP.Position).Magnitude > 200 or not initializedTargets[player.Name]) and not recoveringTargets[player.Name] then
                    recoveringTargets[player.Name] = true
                    initializedTargets[player.Name] = true 
                    
                    task.spawn(function()
                        local originalCF = myHRP.CFrame
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                        task.wait(0.15) 
                        
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 30 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            end
                        end)
                        task.wait(0.05)
                        
                        charHRP.CFrame = originalCF * CFrame.new(0, 25, 0)
                        myHRP.CFrame = originalCF
                        task.wait(0.1)
                        
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 30 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            end
                        end)
                        
                        task.wait(0.3)
                        recoveringTargets[player.Name] = nil
                    end)
                end
                
                local targetCF = myHRP.CFrame * CFrame.new(0, 25, 0)
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                frameToggle = not frameToggle
                if frameToggle then
                    for i = 1, 20 do rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position)) end
                else
                    charHRP.CFrame = targetCF 
                    for i = 1, 5 do rs.GrabEvents.DestroyGrabLine:FireServer(charHRP) end
                end
            end
        end
        RunService.RenderStepped:Wait()
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (자동 복귀)",
    Callback = function(v)
        blobLoopT4 = v
        if v then task.spawn(loopPlayerBlobF4) end
    end
})

KickTab:CreateInput({
    Name = "Add Target (여기에 닉네임 입력)",
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
        
        for _, n in ipairs(kickTargetList) do
            if n == found.Name then return end
        end
        
        table.insert(kickTargetList, found.Name)
        Rayfield:Notify({Title = "추가됨", Content = found.Name .. "님이 타겟으로 설정되었습니다.", Duration = 2})
    end
})

--=============================================
-- [PALLET RAGDOLL 탭] - 판자 레그돌 (UI 수정 완료)
--=============================================
local PalletTab = Window:CreateTab("Pallet Ragdoll (판자)", nil)
PalletTab:CreateSection("판자 레그돌 (투명 초고속 타격)")

PalletTab:CreateInput({
    Name = "타겟 플레이어 이름",
    PlaceholderText = "닉네임의 일부만 적어도 작동",
    RemoveTextAfterFocusLost = false,
    Callback = function(Value)
        ragdollTargetName = Value
    end
})

PalletTab:CreateToggle({
    Name = "판자 레그돌 (On/Off)",
    CurrentValue = false,
    Flag = "PalletToggle",
    Callback = function(Value)
        if Value then
            if ragdollTargetName ~= "" then
                StartPalletRagdoll(ragdollTargetName)
                Rayfield:Notify({Title = "실행", Content = ragdollTargetName.."에게 레그돌 실행 중!", Duration = 2})
            else
                Rayfield:Notify({Title = "경고", Content = "타겟 플레이어 이름을 먼저 입력하세요.", Duration = 2})
            end
        else
            StopPalletRagdoll()
            Rayfield:Notify({Title = "중지", Content = "판자 레그돌이 중지되었습니다.", Duration = 2})
        end
    end
})

--=============================================
-- [SETTINGS 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "모든 스크립트가 성공적으로 로드되었습니다.", Duration = 3})
