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
-- [공통 패턴 - 5:2 (셋오너 5회, 디트로이트 2회)]
--=============================================
local pattern = {1,1,1,1,1,0,0}  -- 1 = SetNetworkOwner, 0 = DestroyGrabLine

--=============================================
-- [GRAB 탭] - 카메라 조준 킥 그랩
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
        if pattern[(fCounter - 1) % #pattern + 1] == 1 then
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
-- [KICK 탭] - 블롭맨 오너 킥 (770Hz, 5:2 패턴)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false
local kickCounter = 0

local steppedConn = nil
local remoteTask = nil
local respawnConn = nil
local targetBP_HRP = nil
local targetBG_HRP = nil
local targetBP_Torso = nil
local targetBG_Torso = nil

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

local function removeOldBodies(part)
    if not part then return end
    for _, v in pairs(part:GetChildren()) do
        if v:IsA("BodyPosition") or v:IsA("BodyGyro") then
            v:Destroy()
        end
    end
end

local function setupBodiesForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    if not tChar then return end
    local tHRP = tChar:FindFirstChild("HumanoidRootPart")
    local tTorso = tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso")
    if not tHRP then return end

    removeOldBodies(tHRP)

    targetBP_HRP = Instance.new("BodyPosition")
    targetBP_HRP.Name = "KickBP_HRP"
    targetBP_HRP.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    targetBP_HRP.P = 1000000
    targetBP_HRP.D = 10000
    targetBP_HRP.Parent = tHRP

    targetBG_HRP = Instance.new("BodyGyro")
    targetBG_HRP.Name = "KickBG_HRP"
    targetBG_HRP.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    targetBG_HRP.P = 1000000
    targetBG_HRP.D = 10000
    targetBG_HRP.CFrame = CFrame.Angles(0, 0, 0)
    targetBG_HRP.Parent = tHRP

    if tTorso then
        removeOldBodies(tTorso)
        targetBP_Torso = Instance.new("BodyPosition")
        targetBP_Torso.Name = "KickBP_Torso"
        targetBP_Torso.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        targetBP_Torso.P = 1000000
        targetBP_Torso.D = 10000
        targetBP_Torso.Parent = tTorso

        targetBG_Torso = Instance.new("BodyGyro")
        targetBG_Torso.Name = "KickBG_Torso"
        targetBG_Torso.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        targetBG_Torso.P = 1000000
        targetBG_Torso.D = 10000
        targetBG_Torso.CFrame = CFrame.Angles(0, 0, 0)
        targetBG_Torso.Parent = tTorso
    else
        targetBP_Torso = nil
        targetBG_Torso = nil
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
                setupBodiesForTarget()
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

    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tTorso = tChar and (tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso"))
        
        if not (myChar and myHRP) then return end
        if not (tChar and tHRP) then return end
        
        local targetPos = myHRP.Position + Vector3.new(7, 20, 0)
        
        if not targetBP_HRP or targetBP_HRP.Parent ~= tHRP then
            setupBodiesForTarget()
        end
        
        if targetBP_HRP then
            targetBP_HRP.Position = targetPos
        end
        if targetBG_HRP then
            targetBG_HRP.CFrame = CFrame.Angles(0, 0, 0)
        end
        
        if tTorso and targetBP_Torso and targetBP_Torso.Parent == tTorso then
            targetBP_Torso.Position = targetPos
            if targetBG_Torso then
                targetBG_Torso.CFrame = CFrame.Angles(0, 0, 0)
            end
        end
        
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        if tTorso then
            tTorso.AssemblyLinearVelocity = Vector3.zero
            tTorso.AssemblyAngularVelocity = Vector3.zero
        end
        
        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- 770Hz 루프 (셋오너 5회, 디트로이트 2회, 충돌 방지 로직 없음)
    remoteTask = task.spawn(function()
        local interval = 0.001298701299  -- 770Hz (1/770)
        local nextTime = tick() + interval
        
        while kickLoopRunning do
            while tick() < nextTime do
                task.wait(0.0001)
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
            if not tHum or tHum.Health <= 0 then continue end
            
            local dist = (tHRP.Position - myHRP.Position).Magnitude
            if dist > 30 then
                pcall(function()
                    myChar:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
                end)
            end
            
            kickCounter = kickCounter + 1
            if pattern[(kickCounter - 1) % #pattern + 1] == 1 then
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
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar:FindFirstChild("HumanoidRootPart")
        local tTorso = tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso")
        if tHRP then
            removeOldBodies(tHRP)
        end
        if tTorso then
            removeOldBodies(tTorso)
        end
    end
    targetBP_HRP = nil
    targetBG_HRP = nil
    targetBP_Torso = nil
    targetBG_Torso = nil
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (770Hz, 셋오너 550Hz/디트로이트 220Hz)",
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
                                local t = tick() * 20
                                local offsetY = 15 * math.sin(t)
                                soundPart.CFrame = tRoot.CFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, offsetY, 0)
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

Rayfield:Notify({Title = "로딩 완료", Content = "770Hz, 셋오너 550Hz/디트로이트 220Hz, 충돌 방지 로직 제거, pcall 적용", Duration = 3})
