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
-- [안티그랩 탈출 리모트 대응 (즉시 재소유권)]
--=============================================
local CharacterEvents = ReplicatedStorage:WaitForChild("CharacterEvents", 5)
local StruggleEvent = CharacterEvents and CharacterEvents:FindFirstChild("Struggle")
local GrabEvents = ReplicatedStorage:WaitForChild("GrabEvents", 5)
local ReleaseGrab = GrabEvents and GrabEvents:FindFirstChild("ReleaseGrab")

local function handleAntiGrabEscape(...)
    task.spawn(function()
        if not selectedKickPlayer then return end
        local tChar = selectedKickPlayer.Character
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

if StruggleEvent then
    StruggleEvent.OnClientEvent:Connect(handleAntiGrabEscape)
end
if ReleaseGrab then
    ReleaseGrab.OnClientEvent:Connect(handleAntiGrabEscape)
end

--=============================================
-- [GRAB 탭] - F키 킥 그랩 (셋오너 1번 → 디트로이트 2번)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (셋오너 1번 → 디트로이트 2번) ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil
local fAttackTarget = nil
local fCounter = 0

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer
    fCounter = 0
    
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
        pcall(function() tgtRoot.CFrame = CFrame.new(camCF.Position + camCF.LookVector * 20) end)
        
        if (myRoot.Position - tgtRoot.Position).Magnitude <= 30 then
            fCounter = fCounter + 1
            -- [수정] 셋오너 1번 → 디트로이트 2번 (3사이클: 셋오너 1번, 디트로이트 2번)
            if fCounter % 3 == 1 then
                pcall(function()
                    rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                end)
            else
                pcall(function()
                    rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
                    rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
                end)
            end
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
-- [KICK 탭] - 셋오너 킥 (상대를 내 위치로 가져오기 + 완전 고정)
--=============================================
local KickTab = Window:CreateTab("Kick (셋오너)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false
local kickCounter = 0

-- 상대를 고정할 AlignPosition/AlignOrientation
local kickAlignPos = nil
local kickAlignRot = nil
local kickAtt0 = nil
local kickAtt1 = nil

-- 리모트 타이머
local remoteTask = nil
-- 물리 갱신 (Stepped)
local steppedConn = nil
-- 리스폰 감지
local respawnConn = nil

KickTab:CreateInput({
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
        
        selectedKickPlayer = found
        Rayfield:Notify({Title = "타겟 설정됨", Content = found.Name .. "님이 타겟으로 설정되었습니다.", Duration = 2})
    end
})

-- [XOCU 스타일] 상대 HRP를 완전 고정하는 Align 설정
local function setupAlignForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    if not tChar then return end
    local tHRP = tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end
    
    -- 기존 Align 제거
    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
            v:Destroy()
        end
    end
    
    -- AlignPosition (위치 완전 고정)
    local att0 = Instance.new("Attachment", tHRP)
    att0.Name = "KickAtt0"
    local att1 = Instance.new("Attachment", workspace.Terrain)
    att1.Name = "KickAtt1"
    
    kickAlignPos = Instance.new("AlignPosition")
    kickAlignPos.Name = "KickAlign"
    kickAlignPos.Attachment0 = att0
    kickAlignPos.Attachment1 = att1
    kickAlignPos.MaxForce = math.huge
    kickAlignPos.MaxVelocity = math.huge
    kickAlignPos.Responsiveness = math.huge
    kickAlignPos.RigidityEnabled = true
    kickAlignPos.Parent = tHRP
    
    -- AlignOrientation (회전 완전 고정)
    kickAlignRot = Instance.new("AlignOrientation")
    kickAlignRot.Name = "KickRot"
    kickAlignRot.Attachment0 = att0
    kickAlignRot.Attachment1 = att1
    kickAlignRot.MaxTorque = math.huge
    kickAlignRot.Responsiveness = math.huge
    kickAlignRot.RigidityEnabled = true
    kickAlignRot.Parent = tHRP
    
    kickAtt0 = att0
    kickAtt1 = att1
end

-- [셋오너킥 시작]
local function startKickLoop()
    if remoteTask then task.cancel(remoteTask) end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickCounter = 0

    if not selectedKickPlayer then
        Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
        return
    end

    -- 리스폰 감지: 새 캐릭터 생성 시 Align 재설정
    respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        if kickLoopRunning then
            setupAlignForTarget()
        end
    end)

    -- 1. Stepped: 물리 갱신 (상대를 내 위치로 가져오기)
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        
        if not (myChar and myHRP) then return end
        if not (tChar and tHRP) then return end
        
        -- 상대를 내 위치 위 20칸으로 강제 이동
        local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
        
        -- Align이 없으면 재설정
        if not tHRP:FindFirstChild("KickAlign") then
            setupAlignForTarget()
        end
        
        -- AlignPosition 갱신
        if kickAlignPos and kickAlignPos.Attachment1 then
            kickAlignPos.Attachment1.WorldPosition = targetPos
        end
        
        -- AlignOrientation 갱신 (회전 0도)
        if kickAlignRot then
            kickAlignRot.CFrame = CFrame.Angles(0, 0, 0)
        end
        
        -- 물리 강제 초기화
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        
        -- Humanoid 상태 강제
        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- 2. 리모트 호출 (셋오너 1번 → 디트로이트 2번)
    remoteTask = task.spawn(function()
        while kickLoopRunning do
            if not selectedKickPlayer then continue end
            
            local tChar = selectedKickPlayer.Character
            local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChild("Humanoid")
            local myChar = plr.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            
            if not (myChar and myHRP) then continue end
            if not (tChar and tHRP) then continue end
            
            -- 상대가 살아있을 때만 리모트 호출
            if tHum and tHum.Health > 0 then
                -- 상대를 내 위치 위 20칸으로 텔레포트
                local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
                pcall(function()
                    tHRP.CFrame = CFrame.new(targetPos)
                    tHRP.AssemblyLinearVelocity = Vector3.zero
                    tHRP.AssemblyAngularVelocity = Vector3.zero
                end)
                
                -- 셋오너 1번 → 디트로이트 2번
                kickCounter = kickCounter + 1
                if kickCounter % 3 == 1 then
                    -- 1. 셋오너 (SetNetworkOwner)
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
                    end)
                else
                    -- 2. 디트로이트 (DestroyGrabLine 2번)
                    pcall(function()
                        rs.GrabEvents.DestroyGrabLine:FireServer(tHRP)
                        rs.GrabEvents.DestroyGrabLine:FireServer(tHRP)
                    end)
                end
            end
            
            -- 350Hz 타이머 (약 0.003초 대기)
            task.wait(0.003)
        end
    end)
end

-- [셋오너킥 종료]
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
    
    -- Align 정리
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
    
    kickAlignPos = nil
    kickAlignRot = nil
    kickAtt0 = nil
    kickAtt1 = nil
end

-- 셋오너 킥 토글
KickTab:CreateToggle({
    Name = "셋오너 킥 (상대를 내 위치로 + 완전 고정)",
    Callback = function(v)
        if v then
            startKickLoop()
        else
            stopKickLoop()
        end
    end
})

--=============================================
-- [팔레트 레그돌 (Invis) - XOCU 완전 이식, Stepped 유지]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 위아래 강타",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = ReplicatedStorage
        local RunService = game:GetService("RunService")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
        local lpName = plr.Name
        local toysFolder = workspace:WaitForChild(lpName .. "SpawnedInToys", 5)

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

            if not toysFolder then
                Rayfield:Notify({Title = "오류", Content = "토이 폴더 없음 (캐릭터 재생성 후 시도)", Duration = 3})
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

            if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then
                pcall(function() DestroyToy:FireServer(toysFolder.PalletForRagdoll) end)
            end
        end
    end,
})

--=============================================
-- [나머지 필수 탭들 유지]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "셋오너 1번 → 디트로이트 2번, 완전 고정", Duration = 3})
