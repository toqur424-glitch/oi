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
local setOwnerRatio = 4  -- 1:3 비율 (SetOwner 1번, Destroy 3번)

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

        -- AlignPosition으로 고정 (매 프레임 위치 업데이트)
        local align = tgtRoot:FindFirstChild("FKeyAlign")
        if align and align.Attachment1 then
            align.Attachment1.WorldPosition = holdPos
        end
        local rot = tgtRoot:FindFirstChild("FKeyRot")
        if rot then
            rot.CFrame = CFrame.Angles(0, 0, 0)
        end

        -- SetOwner와 DestroyGrabLine 번갈아 전송 (1:3 비율)
        fCounter = fCounter + 1
        if fCounter % setOwnerRatio == 1 then
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
            end)
        else
            pcall(function()
                rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
            end)
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
-- [KICK 탭] - 블롭맨 오너 킥 (리스폰 강화, 350Hz)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false
local kickCounter = 0

local steppedConn = nil
local remoteTask = nil
local respawnConn = nil
local targetBP = nil
local targetBG = nil

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

local function setupBodiesForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    if not tChar then return end
    local tHRP = tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    -- 기존 BodyPosition/BodyGyro 제거
    if targetBP then targetBP:Destroy(); targetBP = nil end
    if targetBG then targetBG:Destroy(); targetBG = nil end

    targetBP = Instance.new("BodyPosition")
    targetBP.Name = "KickBP"
    targetBP.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    targetBP.P = 500000  -- 고정력 증가
    targetBP.D = 5000
    targetBP.Parent = tHRP

    targetBG = Instance.new("BodyGyro")
    targetBG.Name = "KickBG"
    targetBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    targetBG.P = 500000
    targetBG.D = 5000
    targetBG.CFrame = CFrame.Angles(0, 0, 0)
    targetBG.Parent = tHRP

    return targetBP, targetBG
end

local function startKickLoop()
    if remoteTask then task.cancel(remoteTask) end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickCounter = 0

    if selectedKickPlayer then
        -- 리셋 감지 및 자동 재부착 (강화)
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                -- 완전히 살아날 때까지 대기
                while hum.Health <= 0 do task.wait(0.1) end
                -- 캐릭터가 물리적으로 완전히 스폰될 때까지 추가 대기
                task.wait(0.3) 
                
                -- 기존 BodyPosition/BodyGyro 강제 제거 및 초기화
                if targetBP then targetBP:Destroy(); targetBP = nil end
                if targetBG then targetBG:Destroy(); targetBG = nil end
                
                -- 새로 생성
                setupBodiesForTarget()
                
                -- 즉시 위치 고정 및 속도 제거
                local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local targetPos = myHRP.Position + Vector3.new(7, 20, 0)
                    pcall(function()
                        hrp.CFrame = CFrame.new(targetPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                        if targetBP then targetBP.Position = targetPos end
                    end)
                end
            end
        end)
    end

    -- 매 프레임 위치 업데이트 (BodyPosition 사용)
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        
        if not (myChar and myHRP) then return end
        if not (tChar and tHRP) then return end
        
        local targetPos = myHRP.Position + Vector3.new(7, 20, 0)
        
        -- BodyPosition이 없거나 잘못된 참조면 재생성
        if not targetBP or targetBP.Parent ~= tHRP then
            setupBodiesForTarget()
        end
        
        if targetBP then
            targetBP.Position = targetPos
        end
        if targetBG then
            targetBG.CFrame = CFrame.Angles(0, 0, 0)
        end
        
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- 350Hz로 SetOwner/DestroyGrabLine 전송
    remoteTask = task.spawn(function()
        local interval = 0.002857142857  -- 350Hz (1/350)
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
                if kickCounter % setOwnerRatio == 1 then
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
    if targetBP then targetBP:Destroy(); targetBP = nil end
    if targetBG then targetBG:Destroy(); targetBG = nil end
    
    if selectedKickPlayer and selectedKickPlayer.Character then
        local tHRP = selectedKickPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then
            for _, v in pairs(tHRP:GetChildren()) do
                if v:IsA("BodyPosition") or v:IsA("BodyGyro") then
                    v:Destroy()
                end
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (리스폰 강화, 350Hz)",
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
-- [팔레트 레그돌 (Invis) - 초고속 출입 (40Hz, 20스터드)]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 초고속 출입 (40Hz, 20스터드)",
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
                            v.Transparency = 0.5   -- 50% 투명도
                            v.Massless = true       -- 몸통 통과
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
                                -- 사인파 진동: 위아래 20스터드, 40Hz, 속도 2,000,000
                                local t = tick() * 40
                                local offsetY = 20 * math.sin(t)
                                soundPart.CFrame = tRoot.CFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, offsetY, 0)
                                soundPart.AssemblyLinearVelocity = Vector3.new(0, -2e6 * math.cos(t), 0)
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

Rayfield:Notify({Title = "로딩 완료", Content = "안티그랩 유지, X=7, Y=20, 350Hz, BodyPosition, 리스폰 강화, SetOwner 1:Destroy 3", Duration = 3})
