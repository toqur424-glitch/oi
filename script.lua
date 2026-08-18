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
-- [안티그랩: 탈출 리모트 차단 + 소유권 강제 유지 (자기 레그돌 방지 제외)]
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
local setOwnerRatio = 3  -- 1:2 비율 (SetOwner 1번, Destroy 2번)

--=============================================
-- [GRAB 탭] - 카메라 조준 킥 그랩 (버튼식)
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

        pcall(function() tgtRoot.CFrame = CFrame.new(holdPos) end)

        local align = tgtRoot:FindFirstChild("FKeyAlign")
        if align and align.Attachment1 then
            align.Attachment1.WorldPosition = holdPos
        end
        local rot = tgtRoot:FindFirstChild("FKeyRot")
        if rot then
            rot.CFrame = CFrame.Angles(0, 0, 0)
        end

        if (myRoot.Position - tgtRoot.Position).Magnitude <= 30 then
            fCounter = fCounter + 1
            if fCounter % setOwnerRatio == 1 then  -- SetOwner 1번 → Destroy 2번
                pcall(function()
                    rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                end)
            else
                pcall(function()
                    rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                    rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
                end)
            end
        end
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
    Name = "카메라 조준 킥 그랩 실행",
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
-- [KICK 탭] - 블롭맨 오너 킥 (룹텔 → 셋오너킥 전환)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false
local kickCounter = 0

local steppedConn = nil
local remoteTask = nil
local respawnConn = nil

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
    
    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
            v:Destroy()
        end
    end
    
    local att0 = Instance.new("Attachment", tHRP)
    att0.Name = "KickAtt0"
    local att1 = Instance.new("Attachment", workspace.Terrain)
    att1.Name = "KickAtt1"
    
    local alignPos = Instance.new("AlignPosition")
    alignPos.Name = "KickAlign"
    alignPos.Attachment0 = att0
    alignPos.Attachment1 = att1
    alignPos.MaxForce = math.huge
    alignPos.MaxVelocity = math.huge
    alignPos.Responsiveness = math.huge
    alignPos.RigidityEnabled = true
    alignPos.Parent = tHRP
    
    local alignRot = Instance.new("AlignOrientation")
    alignRot.Name = "KickRot"
    alignRot.Attachment0 = att0
    alignRot.MaxTorque = math.huge
    alignRot.Responsiveness = math.huge
    alignRot.RigidityEnabled = true
    alignRot.Parent = tHRP
end

local function startKickLoop()
    if remoteTask then task.cancel(remoteTask) end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickCounter = 0

    -- [1] 내 현재 위치를 기억 (고정할 지점)
    local myChar = plr.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then
        Rayfield:Notify({Title = "오류", Content = "캐릭터가 없습니다.", Duration = 2})
        kickLoopRunning = false
        return
    end
    local anchorPos = myHRP.CFrame  -- 이 위치가 기준점이 됨

    if selectedKickPlayer then
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                while hum.Health <= 0 do task.wait(0.1) end
                task.wait(0.2)
                -- 리스폰 시에는 다시 룹텔부터 시작
                setupAlignForTarget()
                local targetPos = anchorPos.Position + Vector3.new(7, 20, 0)
                pcall(function()
                    hrp.CFrame = CFrame.new(targetPos)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end)
    end

    -- [2] 룹텔(반복 텔레포트)을 먼저 실행하여 타겟을 내 위치로 데려옴
    local isGrabbed = false
    local grabStartTime = tick()

    -- 룹텔 루프 (0.05초마다 실행)
    local loopTeleportConn = RunService.Heartbeat:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChild("Humanoid")
        
        if not (myChar and myHRP) or not (tChar and tHRP) or not tHum then return end
        
        -- 이미 잡혔으면 룹텔 종료
        if isGrabbed then
            loopTeleportConn:Disconnect()
            return
        end

        -- [3] 타겟을 내 위치로 강제 텔레포트
        local targetPos = anchorPos.Position + Vector3.new(0, 0, 0) -- 바로 내 위치로
        tHRP.CFrame = CFrame.new(targetPos)
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        
        -- 소유권 강제 (룹텔 중에도 소유권 유지)
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
        end)

        -- [4] 거리 확인: 내 위치에 도착하면 (5스터드 이내)
        local dist = (tHRP.Position - anchorPos.Position).Magnitude
        if dist < 5 then
            isGrabbed = true
            Rayfield:Notify({Title = "성공", Content = "상대를 내 위치로 데려왔습니다! 셋오너 킥 시작", Duration = 2})
            
            -- [5] 이제 본격적인 셋오너 킥 실행 (기존 로직)
            steppedConn = RunService.Stepped:Connect(function()
                if not kickLoopRunning or not selectedKickPlayer then return end
                
                local myChar = plr.Character
                local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local tChar = selectedKickPlayer.Character
                local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
                
                if not (myChar and myHRP) then return end
                if not (tChar and tHRP) then return end
                
                local targetPos = anchorPos.Position + Vector3.new(7, 20, 0)
                
                if not tHRP:FindFirstChild("KickAlign") then
                    setupAlignForTarget()
                end
                
                local align = tHRP:FindFirstChild("KickAlign")
                if align and align.Attachment1 then
                    align.Attachment1.WorldPosition = targetPos
                end
                
                local rot = tHRP:FindFirstChild("KickRot")
                if rot then
                    rot.CFrame = CFrame.Angles(0, 0, 0)
                end
                
                tHRP.AssemblyLinearVelocity = Vector3.zero
                tHRP.AssemblyAngularVelocity = Vector3.zero
                
                local tHum = tChar:FindFirstChild("Humanoid")
                if tHum then
                    tHum.PlatformStand = true
                    tHum:ChangeState(Enum.HumanoidStateType.Physics)
                end
            end)

            -- [6] 550Hz 타이머로 SetNetworkOwner 갱신 (기존 유지)
            remoteTask = task.spawn(function()
                local interval = 0.00181818
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
                    
                    kickCounter = kickCounter + 1
                    if kickCounter % 2 == 1 then
                        pcall(function()
                            rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
                        end)
                    end
                    
                    if tHum and tHum.Health > 0 then
                        local dist = (tHRP.Position - anchorPos.Position).Magnitude
                        if dist > 30 then
                            pcall(function()
                                tHRP.CFrame = anchorPos * CFrame.new(7, 20, 0)
                                tHRP.AssemblyLinearVelocity = Vector3.zero
                                tHRP.AssemblyAngularVelocity = Vector3.zero
                            end)
                        end
                    end
                end
            end)
        end
    end)

    -- [7] 안전장치: 5초 안에 안 잡히면 자동 종료
    task.delay(5, function()
        if not isGrabbed and kickLoopRunning then
            Rayfield:Notify({Title = "실패", Content = "5초 내에 상대를 데려오지 못했습니다. 종료합니다.", Duration = 3})
            stopKickLoop()
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
                if v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
                    v:Destroy()
                end
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 (룹텔 → 셋오너킥)",
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
-- [팔레트 레그돌 (Invis) - 고정력 강화 버전]
--=============================================
do
    local RS = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
    local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
    local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
    local SpawnToy = RS:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
    local toysFolder = workspace:WaitForChild(plr.Name .. "SpawnedInToys")
    local lpName = plr.Name

    -- 공유 변수
    getgenv().palletRagdollActive = false
    getgenv().PalletForRagdoll = nil
    getgenv().palletCacheConn = nil
    getgenv().ragdollSteppedConn = nil
    getgenv().spawnNewPallet = nil

    local function clearAttackLoop()
        if getgenv().ragdollSteppedConn then
            getgenv().ragdollSteppedConn:Disconnect()
            getgenv().ragdollSteppedConn = nil
        end
    end

    KickTab:CreateToggle({
        Name = "Pallet Ragdoll (Invis) - 고정력 강화",
        Flag = "Ragdoll Target",
        Default = false,
        Callback = function(Value)
            if Value then
                if not selectedKickPlayer then
                    Rayfield:Notify({Title = "알림", Content = "타겟을 먼저 입력해주세요!", Duration = 3})
                    return
                end

                getgenv().palletRagdollActive = true
                getgenv().PalletForRagdoll = nil
                
                if getgenv().palletCacheConn then
                    getgenv().palletCacheConn:Disconnect()
                end
                clearAttackLoop()

                if not toysFolder then
                    Rayfield:Notify({Title = "오류", Content = "토이 폴더 없음 (캐릭터 재생성 후 시도)", Duration = 3})
                    return
                end

                -- 팔레트가 생성될 때마다 실행
                getgenv().palletCacheConn = toysFolder.ChildAdded:Connect(function(child)
                    if not getgenv().palletRagdollActive then return end
                    if child.Name ~= "PalletLightBrown" and child.Name ~= "PalletForRagdoll" then return end

                    local soundPart = child:WaitForChild("SoundPart", 3)
                    if not soundPart then return end

                    -- 소유권 강제 획득 (3번 반복)
                    for i = 1, 3 do
                        pcall(function()
                            SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                            DestroyLine:FireServer(soundPart)
                        end)
                        task.wait(0.05)
                    end

                    local partOwner = soundPart:WaitForChild("PartOwner", 2)
                    if partOwner and partOwner.Value == lpName then
                        -- 팔레트 투명화 및 충돌 해제
                        for _, v in pairs(child:GetChildren()) do
                            if v:IsA("BasePart") then
                                v.CanCollide = false
                                v.CanQuery = false
                                v.Transparency = 1 
                            end
                        end

                        child.Name = "PalletForRagdoll"
                        getgenv().PalletForRagdoll = child

                        -- 타겟 고정을 위한 AlignPosition 추가
                        local att0 = Instance.new("Attachment", soundPart)
                        att0.Name = "PalletAttach"
                        local align = Instance.new("AlignPosition")
                        align.Name = "PalletAlign"
                        align.Attachment0 = att0
                        align.MaxForce = math.huge
                        align.Responsiveness = math.huge
                        align.RigidityEnabled = true
                        align.Parent = soundPart

                        local strikePhase = false

                        -- 메인 루프 (Stepped에서 실행)
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

                                -- 소유권 유지 (지속적으로 갱신)
                                pcall(function()
                                    SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                                end)

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

                        -- 팔레트가 사라지면 자동 재스폰
                        child.AncestryChanged:Connect(function()
                            if not child.Parent then
                                clearAttackLoop()
                                getgenv().PalletForRagdoll = nil
                                if getgenv().palletRagdollActive then
                                    task.wait(0.1)
                                    if getgenv().spawnNewPallet then getgenv().spawnNewPallet() end
                                end
                            end
                        end)
                    else
                        pcall(function() DestroyToy:FireServer(child) end)
                    end
                end)

                -- 팔레트 스폰 함수
                getgenv().spawnNewPallet = function()
                    if not getgenv().palletRagdollActive then return end
                    if getgenv().PalletForRagdoll and getgenv().PalletForRagdoll.Parent then return end
                    
                    local c = plr.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    if not h then return end

                    task.spawn(function()
                        pcall(function()
                            SpawnToy:InvokeServer(
                                "PalletLightBrown",
                                h.CFrame * CFrame.new(0, 10, 20),
                                Vector3.zero
                            )
                        end)
                    end)
                end

                -- 최초 스폰
                getgenv().spawnNewPallet()
            else
                -- 종료 시 정리
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

                if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then
                    pcall(function() DestroyToy:FireServer(toysFolder.PalletForRagdoll) end)
                end
            end
        end,
    })
end

--=============================================
-- [나머지 필수 탭들 유지]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "안티그랩 유지, 룹텔 → 셋오너킥 전환, 550Hz 정밀 타이머, SetOwner 1:Destroy 2 (순서: SetOwner → Destroy → Destroy)", Duration = 3})
