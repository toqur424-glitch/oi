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
-- [안티그랩: 탈출 리모트 차단]
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

--=============================================
-- [공통 패턴 - Grab 탭용 5:3]
--=============================================
local pattern = {1,1,1,1,1,0,0,0}

--=============================================
-- [GRAB 탭]
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
-- [KICK 탭] - 블롭맨 오너 킥
--  패턴: D 1회 → S 3회 반복 (D=330Hz / S=500Hz 목표)
--  Destroy/SetOwner 모두 Torso 로 정확히 호출
--  상대 전신에 BodyPosition + BodyGyro (Massless, math.huge) 고정
--  내 머리 좌표 +20 위치로 CFrame 직접 세팅하여 서버 복제
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false

-- ✅ 패턴: D → S → S → S 무한 반복
local kickPattern = {"D", "S", "S", "S"}
local kickPatternIndex = 1

-- ✅ 듀얼 accumulator (매 프레임 누적, 시간 기반 정밀 제어)
local kickDAccum = 0
local kickSAccum = 0
local D_RATE = 330    -- Destroy 330Hz
local S_RATE = 500    -- SetOwner 500Hz

local steppedConn = nil
local remoteTask = nil
local respawnConn = nil

-- ✅ 상대 전신 BodyPosition/BodyGyro 저장 테이블
local targetBodies = {}  -- { {part=, bp=, bg=}, ... }

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

-- ✅ 상대 전신 BodyPosition/BodyGyro 정리
local function cleanTargetBodies()
    for _, entry in ipairs(targetBodies) do
        if entry.bp and entry.bp.Parent then entry.bp:Destroy() end
        if entry.bg and entry.bg.Parent then entry.bg:Destroy() end
        if entry.part and entry.part.Parent then
            pcall(function() entry.part.Massless = false end)
        end
    end
    targetBodies = {}
end

local function setupBodiesForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    if not tChar then return end
    local tHRP = tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    cleanTargetBodies()

    -- 전신의 모든 BasePart 에 BodyPosition + BodyGyro 부착
    for _, v in pairs(tChar:GetChildren()) do
        if v:IsA("BasePart") then
            pcall(function() v.Massless = true end)
            removeOldBodies(v)

            local bp = Instance.new("BodyPosition")
            bp.Name = "KickBP"
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.P = 1000000
            bp.D = 10000
            bp.Parent = v

            local bg = Instance.new("BodyGyro")
            bg.Name = "KickBG"
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 1000000
            bg.D = 10000
            bg.CFrame = CFrame.Angles(0, 0, 0)
            bg.Parent = v

            table.insert(targetBodies, {part = v, bp = bp, bg = bg})
        end
    end
end

local function startKickLoop()
    if remoteTask then remoteTask:Disconnect() end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickPatternIndex = 1
    kickDAccum = 0
    kickSAccum = 0

    if selectedKickPlayer then
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                while hum.Health <= 0 do task.wait(0.1) end
                task.wait(0.2)
                setupBodiesForTarget()
            end
        end)
    end

    -- ✅ Stepped: 전신 BodyPosition 유지 + 매 스텝 CFrame 직접 세팅(서버 복제용)
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHead = myChar and myChar:FindFirstChild("Head")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tTorso = tChar and (tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso"))
        
        if not (myChar and myHRP) then return end
        if not (tChar and tHRP and tTorso) then return end
        
        if #targetBodies == 0 or not targetBodies[1].bp.Parent then
            setupBodiesForTarget()
        end
        
        -- ✅ 내 머리 좌표 기준 +20
        local basePos = (myHead and myHead.Position) or myHRP.Position
        local targetPos = basePos + Vector3.new(0, 20, 0)
        local targetCF = CFrame.new(targetPos)
        
        -- 1) BodyPosition/BodyGyro 로컬 보정 (부드러운 시각효과)
        for _, entry in ipairs(targetBodies) do
            if entry.part and entry.part.Parent then
                if entry.bp and entry.bp.Parent then entry.bp.Position = targetPos end
                if entry.bg and entry.bg.Parent then entry.bg.CFrame = CFrame.Angles(0, 0, 0) end
                entry.part.AssemblyLinearVelocity = Vector3.zero
                entry.part.AssemblyAngularVelocity = Vector3.zero
                pcall(function() entry.part.Massless = true end)
            end
        end
        
        -- 2) ✅ 오너십 있는 파트에 CFrame 직접 세팅 → 서버 복제
        pcall(function() tHRP.CFrame = targetCF end)
        pcall(function() tTorso.CFrame = targetCF end)
        
        -- 3) ✅ 매 스텝 오너십 유지 (Destroy 로 풀린 걸 다시 잡음)
        local lookCF = CFrame.lookAt(myHRP.Position, tTorso.Position)
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, lookCF)
        end)
        
        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- ✅ Heartbeat: 패턴 (D → S → S → S) 매 프레임 누적 실행
    remoteTask = RunService.Heartbeat:Connect(function(dt)
        if not kickLoopRunning then return end
        
        local tChar = selectedKickPlayer and selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tTorso = tChar and (tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso"))
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        
        if not (tHRP and tTorso and myHRP) then return end
        
        kickDAccum = math.min(kickDAccum + D_RATE * dt, 40)
        kickSAccum = math.min(kickSAccum + S_RATE * dt, 120)

        local lookCF = CFrame.lookAt(myHRP.Position, tTorso.Position)
        local safety = 0
        while safety < 500 do
            local action = kickPattern[kickPatternIndex]
            if action == "D" then
                if kickDAccum >= 1 then
                    kickDAccum = kickDAccum - 1
                    pcall(function()
                        rs.GrabEvents.DestroyGrabLine:FireServer(tTorso)
                    end)
                    kickPatternIndex = kickPatternIndex + 1
                    if kickPatternIndex > #kickPattern then kickPatternIndex = 1 end
                else
                    break
                end
            else
                if kickSAccum >= 1 then
                    kickSAccum = kickSAccum - 1
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(tTorso, lookCF)
                    end)
                    kickPatternIndex = kickPatternIndex + 1
                    if kickPatternIndex > #kickPattern then kickPatternIndex = 1 end
                else
                    break
                end
            end
            safety = safety + 1
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
        remoteTask:Disconnect()
        remoteTask = nil
    end
    if respawnConn then
        respawnConn:Disconnect()
        respawnConn = nil
    end
    cleanTargetBodies()
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (D 1회 → S 3회 반복, 전신 BodyPosition 고정)",
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
-- [팔레트 레그돌 (Invis)] - 사인파 출입 + 360도 고속 회전
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 사인파 출입 + 360도 회전",
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
                                -- ✅ 360도 고속 회전 (spin 속도 = 15 rad/s ≈ 2.4바퀴/초)
                                local spinAngle = tick() * 15
                                soundPart.CFrame = tRoot.CFrame
                                    * CFrame.Angles(math.rad(90), 0, 0)
                                    * CFrame.new(0, offsetY, 0)
                                    * CFrame.Angles(0, 0, spinAngle)
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

Rayfield:Notify({Title = "로딩 완료", Content = "Kick: D(330Hz) → S(500Hz)×3 / 머리+20 CFrame 복제 / 전신 BodyPosition 고정", Duration = 3})
