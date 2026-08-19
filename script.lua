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
-- [안티그랩: 탈출 리모트 차단 + 소유권 강제 유지]
--=============================================
local CharacterEvents = ReplicatedStorage:WaitForChild("CharacterEvents", 5)
local StruggleEvent = CharacterEvents and CharacterEvents:FindFirstChild("Struggle")
local GrabEvents = ReplicatedStorage:WaitForChild("GrabEvents", 5)
local ReleaseGrab = GrabEvents and GrabEvents:FindFirstChild("ReleaseGrab")

if StruggleEvent then
    StruggleEvent.OnClientEvent:Connect(function(...) return end)
end
if ReleaseGrab then
    ReleaseGrab.OnClientEvent:Connect(function(...) return end)
end

local BeingHeld = plr:WaitForChild("IsHeld", 10)
if BeingHeld then
    BeingHeld:GetPropertyChangedSignal("Value"):Connect(function()
        if BeingHeld.Value then
            task.spawn(function()
                local tChar = selectedKickPlayer and selectedKickPlayer.Character
                local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
                if tHRP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    for i = 1, 5 do
                        pcall(function()
                            rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(plr.Character.HumanoidRootPart.Position, tHRP.Position))
                        end)
                        task.wait()
                    end
                end
            end)
        end
    end)
end

--=============================================
-- [공통 변수]
--=============================================
local setOwnerRatio = 1  -- 모든 프레임 SetOwner 전송

--=============================================
-- [GRAB 탭] - 카메라 조준 킥 그랩 (고정력 강화)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (속도/고정력 최상) ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil
local fAttackTarget = nil
local fCounter = 0
local selectedGrabPlayer = nil

local function setupFKeyAlign(targetPlayer)
    local tChar = targetPlayer and targetPlayer.Character
    local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("AlignPosition") and v.Name == "FKeyAlign" then v:Destroy() end
        if v:IsA("AlignOrientation") and v.Name == "FKeyRot" then v:Destroy() end
    end

    local att0 = Instance.new("Attachment", tHRP)
    att0.Name = "FKeyAtt0"
    local att1 = Instance.new("Attachment", workspace.Terrain)
    att1.Name = "FKeyAtt1"

    local alignPos = Instance.new("AlignPosition")
    alignPos.Name = "FKeyAlign"
    alignPos.Attachment0 = att0
    alignPos.Attachment1 = att1
    alignPos.MaxForce = math.huge
    alignPos.MaxVelocity = math.huge
    alignPos.Responsiveness = math.huge
    alignPos.RigidityEnabled = true
    alignPos.Parent = tHRP

    local alignRot = Instance.new("AlignOrientation")
    alignRot.Name = "FKeyRot"
    alignRot.Attachment0 = att0
    alignRot.MaxTorque = math.huge
    alignRot.Responsiveness = math.huge
    alignRot.RigidityEnabled = true
    alignRot.Parent = tHRP
end

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer
    fCounter = 0
    setupFKeyAlign(targetPlayer)

    fAttackConnection = RunService.Heartbeat:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        
        if not myRoot or not tgtRoot then return end
        
        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        if tgtHum then tgtHum.PlatformStand = true end
        
        local camCF = camera.CFrame
        local holdPos = camCF.Position + camCF.LookVector * 20

        local align = tgtRoot:FindFirstChild("FKeyAlign")
        if align and align.Attachment1 then
            align.Attachment1.WorldPosition = holdPos
        end
        local rot = tgtRoot:FindFirstChild("FKeyRot")
        if rot then
            rot.CFrame = CFrame.Angles(0, 0, 0)
        end

        fCounter = fCounter + 1
        -- SetOwner 매 프레임 전송
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
        end)
        -- DestroyGrabLine도 매 프레임 전송
        pcall(function()
            rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
            rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
        end)
    end)
end

local function stopFKeyAttack()
    getgenv().FKeyAttackActive = false
    if fAttackConnection then
        fAttackConnection:Disconnect()
        fAttackConnection = nil
    end

    if fAttackTarget and fAttackTarget.Character then
        local tHRP = fAttackTarget.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then
            for _, v in pairs(tHRP:GetChildren()) do
                if v:IsA("AlignPosition") and v.Name == "FKeyAlign" then v:Destroy() end
                if v:IsA("AlignOrientation") and v.Name == "FKeyRot" then v:Destroy() end
            end
        end
    end
    fAttackTarget = nil
end

GrabTab:CreateInput({
    Name = "타겟 닉네임 입력",
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
        
        selectedGrabPlayer = found
        Rayfield:Notify({Title = "타겟 설정됨", Content = found.Name .. "님이 타겟으로 설정되었습니다.", Duration = 2})
    end
})

GrabTab:CreateToggle({
    Name = "카메라 조준 킥 그랩 실행 (고정력 강화)",
    Callback = function(v)
        if v and not selectedGrabPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            return
        end
        if v then
            startFKeyAttack(selectedGrabPlayer)
        else
            stopFKeyAttack()
        end
    end
})

--=============================================
-- [KICK 탭] - 원본 AlignPosition + 리스폰 완전 대비
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false
local kickCounter = 0

local steppedConn = nil
local remoteTask = nil
local respawnConn = nil
local targetAlignPos = nil
local targetAlignRot = nil
local targetAttach0 = nil
local targetAttach1 = nil

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

local function setupAlignForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    if not tChar then return end
    local tHRP = tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    -- 기존 Align/Attachment 제거 (중복 방지)
    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("AlignPosition") or v:IsA("AlignOrientation") or v:IsA("Attachment") then
            v:Destroy()
        end
    end

    -- Attachment0 (타겟 HRP에 부착)
    local att0 = Instance.new("Attachment")
    att0.Name = "KickAtt0"
    att0.Parent = tHRP

    -- Attachment1 (Terrain에 부착 - 영구적)
    local att1 = Instance.new("Attachment")
    att1.Name = "KickAtt1"
    att1.Parent = workspace.Terrain

    -- AlignPosition
    targetAlignPos = Instance.new("AlignPosition")
    targetAlignPos.Name = "KickAlignPos"
    targetAlignPos.Attachment0 = att0
    targetAlignPos.Attachment1 = att1
    targetAlignPos.MaxForce = math.huge
    targetAlignPos.MaxVelocity = math.huge
    targetAlignPos.Responsiveness = math.huge
    targetAlignPos.RigidityEnabled = true
    targetAlignPos.Parent = tHRP

    -- AlignOrientation (회전 고정)
    targetAlignRot = Instance.new("AlignOrientation")
    targetAlignRot.Name = "KickAlignRot"
    targetAlignRot.Attachment0 = att0
    targetAlignRot.MaxTorque = math.huge
    targetAlignRot.Responsiveness = math.huge
    targetAlignRot.RigidityEnabled = true
    targetAlignRot.CFrame = CFrame.Angles(0, 0, 0)
    targetAlignRot.Parent = tHRP

    targetAttach0 = att0
    targetAttach1 = att1

    return targetAlignPos, targetAlignRot
end

local function startKickLoop()
    if remoteTask then task.cancel(remoteTask) end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickCounter = 0

    if selectedKickPlayer then
        -- 리스폰 감지: 안정화 후 재부착 (0.3초 대기)
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                while hum.Health <= 0 do task.wait(0.1) end
                task.wait(0.3) -- 캐릭터 완전 로드 대기
                
                -- 강제 재설정
                pcall(function()
                    setupAlignForTarget()
                    local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if myHRP then
                        local targetPos = myHRP.Position + Vector3.new(7, 20, 0)
                        hrp.CFrame = CFrame.new(targetPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end
                end)
            end
        end)
    end

    -- 매 프레임 실행: 위치 업데이트 + Align 재생성 + 권한 전송
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        
        if not (myChar and myHRP) then return end
        if not (tChar and tHRP) then return end
        
        -- Align/Attachment가 없으면 즉시 재생성
        if not targetAlignPos or targetAlignPos.Parent ~= tHRP or not targetAttach1 then
            pcall(setupAlignForTarget)
        end
        
        -- 위치 고정 (Terrain의 Attachment1 위치 업데이트)
        local targetPos = myHRP.Position + Vector3.new(7, 20, 0)
        if targetAttach1 then
            targetAttach1.WorldPosition = targetPos
        end
        
        -- 회전 고정
        if targetAlignRot then
            targetAlignRot.CFrame = CFrame.Angles(0, 0, 0)
        end
        
        -- 물리 완전 정지
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end

        -- 거리 유지 (멀어지면 순간이동)
        local dist = (tHRP.Position - myHRP.Position).Magnitude
        if dist > 30 then
            pcall(function()
                myChar:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
            end)
        end
    end)

    -- 별도 루프: 매 프레임 SetNetworkOwner + DestroyGrabLine 전송 (350Hz)
    remoteTask = task.spawn(function()
        local interval = 0.002857142857  -- 350Hz
        local nextTime = tick() + interval
        
        while kickLoopRunning do
            while tick() < nextTime do
                task.wait()
            end
            nextTime = nextTime + interval
            
            if not selectedKickPlayer then continue end
            
            local tChar = selectedKickPlayer.Character
            local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChild("Humanoid")
            local myChar = plr.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            
            if not (myChar and myHRP) then continue end
            if not (tChar and tHRP) then continue end
            
            if tHum and tHum.Health > 0 then
                -- SetOwner 매 프레임
                pcall(function()
                    rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
                end)
                -- DestroyGrabLine 매 프레임
                pcall(function()
                    rs.GrabEvents.CreateGrabLine:FireServer(tHRP, CFrame.new())
                    rs.GrabEvents.DestroyGrabLine:FireServer(tHRP)
                end)
            end
        end
    end)
end

local function stopKickLoop()
    kickLoopRunning = false
    if steppedConn then
        steppedConn:Disconnect()
        steppedConn = nil
    end
    if remoteTask then
        task.cancel(remoteTask)
        remoteTask = nil
    end
    if respawnConn then
        respawnConn:Disconnect()
        respawnConn = nil
    end
    if selectedKickPlayer and selectedKickPlayer.Character then
        local tHRP = selectedKickPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then
            for _, v in pairs(tHRP:GetChildren()) do
                if v:IsA("AlignPosition") or v:IsA("AlignOrientation") or v:IsA("Attachment") then
                    v:Destroy()
                end
            end
        end
    end
    targetAlignPos = nil
    targetAlignRot = nil
    targetAttach0 = nil
    targetAttach1 = nil
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (원본 Align, 리스폰 완전 고정)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            return
        end
        if v then
            startKickLoop()
        else
            stopKickLoop()
        end
    end
})

--=============================================
-- [팔레트 레그돌 (Invis) - 사인파로 부드럽게 출입]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 사인파 출입 (몸통 관통)",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = ReplicatedStorage
        local RunService = game:GetService("RunService")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS
