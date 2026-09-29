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
    Name = "🔥 FSOF EXTREME Kick Hub (No-Ping)",
    LoadingTitle = "최적화 중...",
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
local GrabEventsRS = ReplicatedStorage:WaitForChild("GrabEvents", 5)
local ReleaseGrab = GrabEventsRS and GrabEventsRS:FindFirstChild("ReleaseGrab")

if StruggleEvent then StruggleEvent.OnClientEvent:Connect(function(...) return end) end
if ReleaseGrab then ReleaseGrab.OnClientEvent:Connect(function(...) return end) end

--=============================================
-- [공통: 핵심 파트 3개만 (Torso/HRP/Head)]
--=============================================
local function getCoreParts(char)
    if not char then return {} end
    local parts = {}
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if torso and torso:IsA("BasePart") then table.insert(parts, torso) end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then table.insert(parts, hrp) end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then table.insert(parts, head) end
    return parts
end

local function getTorsoPart(char)
    if not char then return nil end
    return char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
end

--=============================================
-- [핵심: 스마트 소유권 취득 (핑 방지)]
-- - 이미 소유 중이면 스킵 (파트당 최대 1회/프레임)
-- - Destroy → 즉시 SetOwner (2 remote, 안전)
--=============================================
local function claimPart(part)
    if not part or not part.Parent then return end
    -- 소유권 확인 → 이미 내 것이면 스킵 (핑 절감 핵심)
    local owner = part:FindFirstChild("PartOwner")
    if owner and owner.Value == plr.Name then return end

    pcall(function()
        rs.GrabEvents.DestroyGrabLine:FireServer(part)
    end)
    pcall(function()
        rs.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame)
    end)
end

--=============================================
-- [초기 버스트: Destroy → SetOwner 2콤보 × 8회]
--=============================================
local function initialBurst(char, shouldContinue)
    if not char then return end
    local parts = getCoreParts(char)
    if #parts == 0 then return end

    for round = 1, 8 do
        if shouldContinue and not shouldContinue() then break end
        -- Destroy 스윕
        for _, part in ipairs(parts) do
            if part.Parent then
                pcall(function()
                    rs.GrabEvents.DestroyGrabLine:FireServer(part)
                end)
            end
        end
        RunService.RenderStepped:Wait()
        -- SetOwner 스윕
        for _, part in ipairs(parts) do
            if part.Parent then
                pcall(function()
                    rs.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame)
                end)
            end
        end
    end
end

--=============================================
-- [GRAB 탭]
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (핑 방지 / 스마트 소유권) ===")

getgenv().FKeyAttackActive = false
local fAttackThread = nil
local fAttackTarget = nil
local selectedGrabPlayer = nil

local function setupFKeyAlign(targetPlayer)
    local tChar = targetPlayer and targetPlayer.Character
    local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("AlignPosition") and v.Name == "FKeyAlign" then v:Destroy() end
        if v:IsA("AlignOrientation") and v.Name == "FKeyRot" then v:Destroy() end
    end

    local att0 = Instance.new("Attachment", tHRP); att0.Name = "FKeyAtt0"
    local att1 = Instance.new("Attachment", workspace.Terrain); att1.Name = "FKeyAtt1"

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
    setupFKeyAlign(targetPlayer)

    fAttackThread = task.spawn(function()
        -- 초기 버스트
        do
            local tChar = fAttackTarget and fAttackTarget.Character
            if tChar then
                initialBurst(tChar, function() return getgenv().FKeyAttackActive end)
            end
        end

        -- 매 프레임 스마트 소유권
        while getgenv().FKeyAttackActive do
            task.wait()

            local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local tChar = fAttackTarget and fAttackTarget.Character
            local tgtRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tgtHum = tChar and tChar:FindFirstChild("Humanoid")

            if not myRoot or not tgtRoot then continue end

            -- 물리 초기화
            tgtRoot.AssemblyLinearVelocity = Vector3.zero
            tgtRoot.AssemblyAngularVelocity = Vector3.zero
            if tgtHum then
                tgtHum.PlatformStand = true
                tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
            end

            -- 카메라 앞 20스터드 고정
            local camCF = camera.CFrame
            local holdPos = camCF.Position + camCF.LookVector * 20

            local align = tgtRoot:FindFirstChild("FKeyAlign")
            if align and align.Attachment1 then
                align.Attachment1.WorldPosition = holdPos
            end
            local rot = tgtRoot:FindFirstChild("FKeyRot")
            if rot then rot.CFrame = CFrame.Angles(0, 0, 0) end

            -- ✅ 스마트 소유권: 이미 소유 중인 파트는 스킵
            local parts = getCoreParts(tChar)
            for _, part in ipairs(parts) do
                claimPart(part)
            end
        end
    end)
end

local function stopFKeyAttack()
    getgenv().FKeyAttackActive = false
    if fAttackThread then
        pcall(function() task.cancel(fAttackThread) end)
        fAttackThread = nil
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
        local found
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(v:lower()) or (p.DisplayName and p.DisplayName:lower():find(v:lower())) then
                found = p; break
            end
        end
        if not found then
            Rayfield:Notify({Title="오류", Content="해당 유저를 찾을 수 없습니다.", Duration=2}); return
        end
        selectedGrabPlayer = found
        Rayfield:Notify({Title="타겟 설정됨", Content=found.Name.."님이 타겟으로 설정되었습니다.", Duration=2})
    end
})

GrabTab:CreateToggle({
    Name = "카메라 조준 킥 그랩 [스마트 소유권]",
    Callback = function(v)
        if v and not selectedGrabPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3}); return
        end
        if v then startFKeyAttack(selectedGrabPlayer) else stopFKeyAttack() end
    end
})

--=============================================
-- [KICK 탭] - 블롭맨 오너 킥
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false

local steppedConn, kickThread = nil, nil
local respawnConn = nil
local targetBP_HRP, targetBG_HRP = nil, nil
local targetBodies = {}

KickTab:CreateInput({
    Name = "Add Target (타겟 닉네임 입력)",
    PlaceholderText = "예: Player1",
    RemoveTextAfterFocusLost = true,
    Callback = function(v)
        if v == "" then return end
        local found
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(v:lower()) or (p.DisplayName and p.DisplayName:lower():find(v:lower())) then
                found = p; break
            end
        end
        if not found then
            Rayfield:Notify({Title="오류", Content="해당 유저를 찾을 수 없습니다.", Duration=2}); return
        end
        selectedKickPlayer = found
        Rayfield:Notify({Title="타겟 설정됨", Content=found.Name.."님이 타겟으로 설정되었습니다.", Duration=2})
    end
})

local function clearAllBodies()
    for part, bodies in pairs(targetBodies) do
        for _, b in ipairs(bodies) do
            if b and b.Parent then b:Destroy() end
        end
    end
    targetBodies = {}
    targetBP_HRP, targetBG_HRP = nil, nil
end

local function setupBodiesForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    clearAllBodies()
    for _, v in pairs(tChar:GetDescendants()) do
        if (v:IsA("BodyPosition") or v:IsA("BodyGyro")) and
           (v.Name:sub(1,7) == "KickBP_" or v.Name:sub(1,7) == "KickBG_") then
            v:Destroy()
        end
    end

    for _, part in ipairs(tChar:GetDescendants()) do
        if part:IsA("BasePart") then
            local bp = Instance.new("BodyPosition")
            bp.Name = "KickBP_" .. part.Name
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.P = 1000000; bp.D = 10000
            bp.Parent = part

            local bg = Instance.new("BodyGyro")
            bg.Name = "KickBG_" .. part.Name
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 1000000; bg.D = 10000
            bg.CFrame = CFrame.Angles(0, 0, 0)
            bg.Parent = part

            targetBodies[part] = {bp, bg}
            if part == tHRP then targetBP_HRP, targetBG_HRP = bp, bg end
        end
    end
end

local function startKickLoop()
    if steppedConn then steppedConn:Disconnect() end
    if kickThread then pcall(function() task.cancel(kickThread) end) end
    if respawnConn then respawnConn:Disconnect() end

    kickLoopRunning = true

    if selectedKickPlayer then
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                while hum.Health <= 0 do task.wait(0.1) end
                task.wait(0.2)
                setupBodiesForTarget()
                initialBurst(newChar, function() return kickLoopRunning end)

                local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    pcall(function()
                        hrp.CFrame = CFrame.new(myHRP.Position + Vector3.new(0, 20, 0))
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        end)
    end

    -- 전신 박제 (Stepped)
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not (myChar and myHRP) or not (tChar and tHRP) then return end

        if not targetBP_HRP or targetBP_HRP.Parent ~= tHRP then setupBodiesForTarget() end

        local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
        local zeroCF = CFrame.Angles(0, 0, 0)
        for part, bodies in pairs(targetBodies) do
            if part and part.Parent then
                local bp, bg = bodies[1], bodies[2]
                if bp and bp.Parent then bp.Position = targetPos end
                if bg and bg.Parent then bg.CFrame = zeroCF end
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end

        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- 스마트 소유권 루프
    kickThread = task.spawn(function()
        do
            local tChar = selectedKickPlayer and selectedKickPlayer.Character
            if tChar then
                initialBurst(tChar, function() return kickLoopRunning end)
            end
        end

        while kickLoopRunning do
            task.wait()

            local tChar = selectedKickPlayer and selectedKickPlayer.Character
            local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not (tHRP and myHRP) then continue end

            -- 원거리 텔레포트
            if (tHRP.Position - myHRP.Position).Magnitude > 30 then
                pcall(function()
                    plr.Character:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
                end)
            end

            -- ✅ 스마트 소유권 (이미 소유 중이면 스킵 → 핑 절감)
            local parts = getCoreParts(tChar)
            for _, part in ipairs(parts) do
                claimPart(part)
            end
        end
    end)
end

local function stopKickLoop()
    kickLoopRunning = false
    if steppedConn then steppedConn:Disconnect(); steppedConn = nil end
    if kickThread then pcall(function() task.cancel(kickThread) end); kickThread = nil end
    if respawnConn then respawnConn:Disconnect(); respawnConn = nil end

    clearAllBodies()
    if selectedKickPlayer and selectedKickPlayer.Character then
        for _, v in pairs(selectedKickPlayer.Character:GetDescendants()) do
            if (v:IsA("BodyPosition") or v:IsA("BodyGyro")) and
               (v.Name:sub(1,7) == "KickBP_" or v.Name:sub(1,7) == "KickBG_") then
                v:Destroy()
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 [스마트 소유권]",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3}); return
        end
        if v then startKickLoop() else stopKickLoop() end
    end
})

--=============================================
-- [팔레트 레그돌 (Invis)]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 사인파 출입",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = ReplicatedStorage
        local RunService2 = game:GetService("RunService")
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
            
            if getgenv().palletCacheConn then getgenv().palletCacheConn:Disconnect() end
            clearAttackLoop()

            if not toysFolder then
                Rayfield:Notify({Title = "오류", Content = "토이 폴더 없음", Duration = 3}); return
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

                    getgenv().ragdollSteppedConn = RunService2.Stepped:Connect(function()
                        if not getgenv().palletRagdollActive or not child.Parent then 
                            clearAttackLoop(); return 
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
                                soundPart.CFrame = tRoot.CFrame * CFrame.Angles(0, 0, math.rad(95)) * CFrame.new(0, offsetY, 0)
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
-- [Settings]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로드 완료", Content = "CreateLine 제거 / 스마트 소유권 (이미 소유 중이면 스킵) / 핑 부담 최소화", Duration = 4})
