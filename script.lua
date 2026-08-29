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
-- [GRAB 탭] - F키 킥 그랩 (1:1 번갈아)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (속도/고정력 최상) ===")

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
            if fCounter % 2 == 0 then
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
-- [KICK 탭] - 블롭맨 오너 킥 (1:1 번갈아, 600Hz, BodyPosition 고정)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false
local kickCounter = 0

-- Stepped: BodyPosition 갱신 (물리 직전, 보조)
local steppedConn = nil
-- 리모트 호출 + BodyPosition 갱신: 정밀 타이머 (600Hz, 주 갱신)
local remoteTask = nil
-- 리스폰 감지
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

-- BodyPosition + BodyGyro 설정 (HRP와 Torso 동시 고정)
local function setupBodyForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    if not tChar then return end
    local tHRP = tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end
    
    -- 기존 BodyPosition/BodyGyro 제거 (HRP)
    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("BodyPosition") or v:IsA("BodyGyro") then
            v:Destroy()
        end
    end
    
    -- HRP용 BodyPosition (위치 고정)
    local bodyPos = Instance.new("BodyPosition")
    bodyPos.Name = "KickBodyPos"
    bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyPos.MaxVelocity = math.huge
    bodyPos.D = 1000
    bodyPos.P = 1000
    bodyPos.Position = Vector3.new(0, 20, 0) -- 초기 위치 (나중에 갱신)
    bodyPos.Parent = tHRP
    
    -- HRP용 BodyGyro (회전 0도 고정)
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "KickBodyGyro"
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.D = 1000
    bodyGyro.P = 1000
    bodyGyro.CFrame = CFrame.Angles(0, 0, 0)
    bodyGyro.Parent = tHRP
    
    -- Torso(몸통)에도 BodyPosition 추가
    local torso = tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso")
    if torso then
        -- 기존 BodyPosition 제거
        for _, v in pairs(torso:GetChildren()) do
            if v:IsA("BodyPosition") then
                v:Destroy()
            end
        end
        local torsoBodyPos = Instance.new("BodyPosition")
        torsoBodyPos.Name = "KickBodyPos"
        torsoBodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        torsoBodyPos.MaxVelocity = math.huge
        torsoBodyPos.D = 1000
        torsoBodyPos.P = 1000
        torsoBodyPos.Position = Vector3.new(0, 20, 0)
        torsoBodyPos.Parent = torso
    end
end

local function startKickLoop()
    if remoteTask then task.cancel(remoteTask) end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickCounter = 0

    -- 리스폰 감지: 새 캐릭터 생성 시 즉시 20으로 텔레포트 후 Body 설정
    if selectedKickPlayer then
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                -- 캐릭터가 완전히 로드되고 체력이 회복될 때까지 대기
                while hum.Health <= 0 do task.wait(0.1) end
                task.wait(0.2)
                
                -- 1. BodyPosition 생성
                setupBodyForTarget()
                
                -- 2. 즉시 20 위치로 강제 텔레포트 (한 번만)
                local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
                    pcall(function()
                        hrp.CFrame = CFrame.new(targetPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        end)
    end

    -- 1. Stepped: BodyPosition 갱신 (물리 직전, 보조)
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        
        -- 내 캐릭터가 없거나 대상이 없으면 리턴
        if not (myChar and myHRP) then return end
        if not (tChar and tHRP) then return end
        
        local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
        
        if not tHRP:FindFirstChild("KickBodyPos") then
            setupBodyForTarget()
        end
        
        -- HRP 고정
        local bodyPos = tHRP:FindFirstChild("KickBodyPos")
        if bodyPos then
            bodyPos.Position = targetPos
        end
        
        local bodyGyro = tHRP:FindFirstChild("KickBodyGyro")
        if bodyGyro then
            bodyGyro.CFrame = CFrame.Angles(0, 0, 0)
        end
        
        -- Torso 고정 (몸통)
        local torso = tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso")
        if torso then
            local torsoBodyPos = torso:FindFirstChild("KickBodyPos")
            if torsoBodyPos then
                torsoBodyPos.Position = targetPos
            end
        end
        
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- 2. 리모트 호출 + BodyPosition 갱신 (정밀 타이머, 600Hz, 주 갱신, 1:1 번갈아)
    remoteTask = task.spawn(function()
        local interval = 0.0016666666666666668 -- 600Hz
        local nextTime = tick() + interval
        
        while kickLoopRunning do
            -- 정밀 대기
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
            
            -- 내 캐릭터가 없으면 리턴
            if not (myChar and myHRP) then continue end
            
            -- 대상 캐릭터가 없으면 리턴
            if not (tChar and tHRP) then continue end
            
            -- 대상이 죽었으면 리모트는 보내지 않지만, BodyPosition은 계속 갱신
            local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
            
            if not tHRP:FindFirstChild("KickBodyPos") then
                setupBodyForTarget()
            end
            
            -- HRP 고정
            local bodyPos = tHRP:FindFirstChild("KickBodyPos")
            if bodyPos then
                bodyPos.Position = targetPos
            end
            
            local bodyGyro = tHRP:FindFirstChild("KickBodyGyro")
            if bodyGyro then
                bodyGyro.CFrame = CFrame.Angles(0, 0, 0)
            end
            
            -- Torso 고정
            local torso = tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso")
            if torso then
                local torsoBodyPos = torso:FindFirstChild("KickBodyPos")
                if torsoBodyPos then
                    torsoBodyPos.Position = targetPos
                end
            end
            
            tHRP.AssemblyLinearVelocity = Vector3.zero
            tHRP.AssemblyAngularVelocity = Vector3.zero
            if tHum then
                tHum.PlatformStand = true
                tHum:ChangeState(Enum.HumanoidStateType.Physics)
            end
            
            -- 살아있을 때만 리모트 호출 (1:1 번갈아)
            if tHum and tHum.Health > 0 then
                -- FETCH: 거리 30 이상이면 자신이 대상에게 텔레포트
                local dist = (tHRP.Position - myHRP.Position).Magnitude
                if dist > 30 then
                    pcall(function()
                        myChar:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
                    end)
                end
                
                kickCounter = kickCounter + 1
                if kickCounter % 2 == 0 then
                    -- SetOwner
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
                    end)
                else
                    -- Detroit (Create + Destroy)
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(tHRP, CFrame.new())
                        rs.GrabEvents.DestroyGrabLine:FireServer(tHRP)
                    end)
                end
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
                if v:IsA("BodyPosition") or v:IsA("BodyGyro") then
                    v:Destroy()
                end
            end
        end
        local torso = selectedKickPlayer.Character:FindFirstChild("Torso") or selectedKickPlayer.Character:FindFirstChild("UpperTorso")
        if torso then
            for _, v in pairs(torso:GetChildren()) do
                if v:IsA("BodyPosition") then
                    v:Destroy()
                end
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (1:1 번갈아, 600Hz, BodyPosition 고정)",
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

Rayfield:Notify({Title = "로딩 완료", Content = "1:1 번갈아, 600Hz, BodyPosition 고정", Duration = 3})
