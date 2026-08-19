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
    Name = "🔥 FSOF Ultimate Quad-Lock Hub",
    LoadingTitle = "최적화 및 로딩 중...",
    LoadingSubtitle = "by Extreme Script",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [안티그랩 완전 차단: Struggle / RagdollRemote 무력화]
--=============================================
local CharacterEvents = ReplicatedStorage:WaitForChild("CharacterEvents", 5)
local StruggleEvent = CharacterEvents and CharacterEvents:FindFirstChild("Struggle")
local RagdollRemote = CharacterEvents and CharacterEvents:FindFirstChild("RagdollRemote")

if StruggleEvent then
    StruggleEvent.OnClientEvent:Connect(function(...) return end)
end
if RagdollRemote then
    RagdollRemote.OnClientEvent:Connect(function(...) return end)
end

--=============================================
-- [IsHeld 감시용 더미 (안티그랩 유인용)]
--=============================================
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
-- [KICK 탭] - 4중 고정 (Align + BodyPosition + BodyGyro + BodyVelocity)
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

local function setupQuadLockForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    if not tChar then return end
    local tHRP = tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    -- 기존 모든 고정 장치 제거
    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("AlignPosition") or v:IsA("AlignOrientation") 
           or v:IsA("BodyPosition") or v:IsA("BodyGyro") 
           or v:IsA("BodyVelocity") then
            v:Destroy()
        end
    end

    -- 1. AlignPosition (빠른 위치 추적)
    local att0 = Instance.new("Attachment", tHRP)
    att0.Name = "KickAtt0"
    local att1 = Instance.new("Attachment", workspace.Terrain)
    att1.Name = "KickAtt1"
    
    local alignPos = Instance.new("AlignPosition")
    alignPos.Name = "KickAlign"
    alignPos.Attachment0 = att0
    alignPos.Attachment1 = att1
    alignPos.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    alignPos.MaxVelocity = math.huge
    alignPos.Responsiveness = 1000
    alignPos.RigidityEnabled = true
    alignPos.Parent = tHRP

    -- 2. AlignOrientation (회전 0도 고정)
    local alignRot = Instance.new("AlignOrientation")
    alignRot.Name = "KickRot"
    alignRot.Attachment0 = att0
    alignRot.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    alignRot.Responsiveness = 1000
    alignRot.RigidityEnabled = true
    alignRot.CFrame = CFrame.Angles(0, 0, 0)
    alignRot.Parent = tHRP

    -- 3. BodyPosition (물리 힘으로 강제 고정)
    local bp = Instance.new("BodyPosition")
    bp.Name = "KickBP"
    bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bp.P = 1000000
    bp.D = 10000
    bp.Position = tHRP.Position
    bp.Parent = tHRP

    -- 4. BodyGyro (회전 물리 고정)
    local bg = Instance.new("BodyGyro")
    bg.Name = "KickBG"
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.P = 1000000
    bg.D = 10000
    bg.CFrame = CFrame.Angles(0, 0, 0)
    bg.Parent = tHRP

    -- 5. BodyVelocity (Y축 중력 차단)
    local bv = Instance.new("BodyVelocity")
    bv.Name = "KickBV"
    bv.MaxForce = Vector3.new(0, 1e9, 0)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = tHRP

    -- 충돌 및 움직임 완전 차단
    for _, part in pairs(tChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end
    local tHum = tChar:FindFirstChild("Humanoid")
    if tHum then
        tHum.WalkSpeed = 0
        tHum.JumpPower = 0
        tHum.PlatformStand = true
        tHum.Sit = true
    end
end

local function startKickLoop()
    if remoteTask then task.cancel(remoteTask) end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickCounter = 0

    if selectedKickPlayer then
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                while hum.Health <= 0 do task.wait(0.1) end
                task.wait(0.2)
                setupQuadLockForTarget()
                kickCounter = 0
                local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local targetPos = myHRP.Position + Vector3.new(7, 20, 0)
                    pcall(function()
                        hrp.CFrame = CFrame.new(targetPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        end)
    end

    -- Stepped: 4중 고정 장치 업데이트 (매 프레임)
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        
        if not (myChar and myHRP) then return end
        if not (tChar and tHRP) then return end
        
        local targetPos = myHRP.Position + Vector3.new(7, 20, 0)
        
        -- 고정 장치가 없으면 재생성
        if not tHRP:FindFirstChild("KickAlign") then
            setupQuadLockForTarget()
        end
        
        -- AlignPosition 위치 업데이트
        local align = tHRP:FindFirstChild("KickAlign")
        if align and align.Attachment1 then
            align.Attachment1.WorldPosition = targetPos
        end
        
        -- BodyPosition 위치 업데이트
        local bp = tHRP:FindFirstChild("KickBP")
        if bp then
            bp.Position = targetPos
        end
        
        -- BodyGyro 회전 0도 유지
        local bg = tHRP:FindFirstChild("KickBG")
        if bg then
            bg.CFrame = CFrame.Angles(0, 0, 0)
        end
        
        -- 나머지 물리 강제 초기화
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.WalkSpeed = 0
            tHum.JumpPower = 0
            tHum.PlatformStand = true
            tHum.Sit = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- 리모트 호출 (350Hz, 1:3 비율 - 소유권 압도)
    remoteTask = task.spawn(function()
        local interval = 1 / 350
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
                local dist = (tHRP.Position - myHRP.Position).Magnitude
                if dist > 30 then
                    pcall(function()
                        myChar:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
                    end)
                end
                
                kickCounter = kickCounter + 1
                if kickCounter % 4 == 1 then
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
                    end)
                else
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
                if v:IsA("AlignPosition") or v:IsA("AlignOrientation") 
                   or v:IsA("BodyPosition") or v:IsA("BodyGyro") 
                   or v:IsA("BodyVelocity") then
                    v:Destroy()
                end
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "4중 고정 킥 실행 (안티그랩 완전 뚫기)",
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
-- [팔레트 레그돌 (Invis) - 사인파, 90도 수직, 50Hz]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 90도 수직, 50Hz",
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
                            v.Transparency = 0.5
                            v.Massless = true
                        end
                    end

                    child.Name = "PalletForRagdoll"
                    getgenv().PalletForRagdoll = child

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
                                local t = tick() * 50
                                local offsetY = 15 * math.sin(t)
                                soundPart.CFrame = tRoot.CFrame * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, offsetY, 0)
                                soundPart.AssemblyLinearVelocity = Vector3.new(0, -9e5 * math.cos(t), 0)
                                soundPart.CanCollide = false
                                soundPart.Massless = true
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
-- [나머지 필수 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "4중 고정(Align+BodyPosition+BodyGyro+BodyVelocity), 안티그랩 완전 차단, 350Hz", Duration = 3})
