--=============================================
-- [FSOF EXTREME Kick Hub - Instant Snap Fling]
-- - CreateLine 로직 완전 제거
-- - 다른 스크립트와 병행 사용 가능
-- - 스마트 소유권 (이미 소유 중이면 스킵)
-- - 기본 위치: Y=-8, 앞 3스터드
-- - 셋오너 킥 ON 시: 즉시 9,999,999스터드 순간이동 (Instant Snap)
--=============================================

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
-- [고유 네임스페이스]
--=============================================
local HUB_ID = "_FSOFExtreme_" .. tostring(math.random(100000, 999999))
getgenv()[HUB_ID] = getgenv()[HUB_ID] or {}
local STATE = getgenv()[HUB_ID]

STATE.FKeyAttackActive = false
STATE.KickLoopRunning = false
STATE.PalletRagdollActive = false
STATE.PalletForRagdoll = nil
STATE.FAttackTarget = nil
STATE.SelectedGrabPlayer = nil
STATE.SelectedKickPlayer = nil
STATE.RagdollSteppedConn = nil
STATE.PalletCacheConn = nil
STATE.SpawnNewPallet = nil

STATE.FlingDistance = 9999999
STATE.FlingDirection = "forward"

--=============================================
-- [UI 생성]
--=============================================
local Window = Rayfield:CreateWindow({
    Name = "🔥 FSOF EXTREME Kick Hub (Instant Snap)",
    LoadingTitle = "최적화 중...",
    LoadingSubtitle = "by Extreme Script",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [안티그랩]
--=============================================
do
    local CharacterEvents = ReplicatedStorage:WaitForChild("CharacterEvents", 5)
    local StruggleEvent = CharacterEvents and CharacterEvents:FindFirstChild("Struggle")
    local GrabEventsRS = ReplicatedStorage:WaitForChild("GrabEvents", 5)
    local ReleaseGrab = GrabEventsRS and GrabEventsRS:FindFirstChild("ReleaseGrab")

    if StruggleEvent then StruggleEvent.OnClientEvent:Connect(function(...) return end) end
    if ReleaseGrab then ReleaseGrab.OnClientEvent:Connect(function(...) return end) end
end

--=============================================
-- [공통 함수]
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

local function isOwnedByMe(part)
    if not part or not part.Parent then return false end
    local ok, owner = pcall(function() return part:FindFirstChild("PartOwner") end)
    if not ok or not owner then return false end
    local ok2, val = pcall(function() return owner.Value end)
    return ok2 and val == plr.Name
end

-- ✅ 스마트 소유권: DestroyGrabLine → SetOwner
local function claimPart(part)
    if not part or not part.Parent then return end
    if isOwnedByMe(part) then return end

    pcall(function()
        rs.GrabEvents.DestroyGrabLine:FireServer(part)
    end)
    pcall(function()
        rs.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame)
    end)
end

local function initialBurst(char, shouldContinue)
    if not char then return end
    local parts = getCoreParts(char)
    if #parts == 0 then return end

    for round = 1, 8 do
        if shouldContinue and not shouldContinue() then break end
        for _, part in ipairs(parts) do
            if part.Parent then
                pcall(function()
                    rs.GrabEvents.DestroyGrabLine:FireServer(part)
                end)
            end
        end
        RunService.RenderStepped:Wait()
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
-- [위치 계산 - Y=-8 / 앞 3스터드 / 킥 시 9999999스터드]
--=============================================
local function getHorizontalBasis()
    local camCF = camera.CFrame
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    if forward.Magnitude > 0 then
        forward = forward.Unit
    else
        forward = Vector3.new(0, 0, -1)
    end
    local right = forward:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude > 0 then right = right.Unit end
    return forward, right
end

local function getFlingOffsetVector()
    local forward, right = getHorizontalBasis()
    local dir = STATE.FlingDirection
    if dir == "backward" then return -forward
    elseif dir == "left" then return -right
    elseif dir == "right" then return right
    elseif dir == "up" then return Vector3.new(0, 1, 0)
    elseif dir == "random" then
        local ang = math.random() * math.pi * 2
        return Vector3.new(math.cos(ang), 0, math.sin(ang))
    else return forward end
end

local function getHoldPosition(kickActive)
    local myChar = plr.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local myPos = myHRP.Position
    local forward = getHorizontalBasis()

    local base = Vector3.new(
        myPos.X + forward.X * 3,
        -8,
        myPos.Z + forward.Z * 3
    )

    if kickActive then
        local offVec = getFlingOffsetVector()
        local d = STATE.FlingDistance
        base = Vector3.new(
            base.X + offVec.X * d,
            base.Y + offVec.Y * d,
            base.Z + offVec.Z * d
        )
    end

    return base
end

--=============================================
-- [GRAB 탭]
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (Instant Snap / 순간이동) ===")

local function setupFKeyAlign(targetPlayer)
    pcall(function()
        local tChar = targetPlayer and targetPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end

        for _, v in pairs(tHRP:GetChildren()) do
            if v:IsA("AlignPosition") and v.Name == "FKeyAlign" then v:Destroy() end
            if v:IsA("AlignOrientation") and v.Name == "FKeyRot" then v:Destroy() end
        end

        local att0 = Instance.new("Attachment", tHRP); att0.Name = "FKeyAtt0"
        local att1 = Instance.new("Attachment", workspace.Terrain); att1.Name = "FKeyAtt1"

        -- ✅ RigidityEnabled = true → 즉시 스냅 (물리 저항 무시)
        local alignPos = Instance.new("AlignPosition")
        alignPos.Name = "FKeyAlign"
        alignPos.Attachment0 = att0
        alignPos.Attachment1 = att1
        alignPos.MaxForce = math.huge
        alignPos.MaxVelocity = math.huge
        alignPos.Responsiveness = 200
        alignPos.RigidityEnabled = true
        alignPos.Parent = tHRP

        local alignRot = Instance.new("AlignOrientation")
        alignRot.Name = "FKeyRot"
        alignRot.Attachment0 = att0
        alignRot.MaxTorque = math.huge
        alignRot.Responsiveness = 200
        alignRot.RigidityEnabled = true
        alignRot.Parent = tHRP
    end)
end

local function startFKeyAttack(targetPlayer)
    STATE.FKeyAttackActive = true
    STATE.FAttackTarget = targetPlayer
    setupFKeyAlign(targetPlayer)

    task.spawn(function()
        pcall(function()
            local tChar = targetPlayer and targetPlayer.Character
            if tChar then
                initialBurst(tChar, function() return STATE.FKeyAttackActive end)
            end
        end)

        while STATE.FKeyAttackActive do
            task.wait()
            pcall(function()
                local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local tChar = STATE.FAttackTarget and STATE.FAttackTarget.Character
                local tgtRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local tgtHum = tChar and tChar:FindFirstChild("Humanoid")

                if not myRoot or not tgtRoot then return end

                tgtRoot.AssemblyLinearVelocity = Vector3.zero
                tgtRoot.AssemblyAngularVelocity = Vector3.zero
                if tgtHum then
                    tgtHum.PlatformStand = true
                    tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
                end

                local holdPos = getHoldPosition(true)
                if not holdPos then return end

                -- ✅ 즉시 순간이동 (AlignPosition + Rigidity → 속도 무시하고 스냅)
                local align = tgtRoot:FindFirstChild("FKeyAlign")
                if align and align.Attachment1 then
                    align.Attachment1.WorldPosition = holdPos
                end
                local rot = tgtRoot:FindFirstChild("FKeyRot")
                if rot then rot.CFrame = CFrame.Angles(0, 0, 0) end

                local parts = getCoreParts(tChar)
                for _, part in ipairs(parts) do
                    claimPart(part)
                end
            end)
        end
    end)
end

local function stopFKeyAttack()
    STATE.FKeyAttackActive = false
    pcall(function()
        if STATE.FAttackTarget and STATE.FAttackTarget.Character then
            local tHRP = STATE.FAttackTarget.Character:FindFirstChild("HumanoidRootPart")
            if tHRP then
                for _, v in pairs(tHRP:GetChildren()) do
                    if v:IsA("AlignPosition") and v.Name == "FKeyAlign" then v:Destroy() end
                    if v:IsA("AlignOrientation") and v.Name == "FKeyRot" then v:Destroy() end
                end
            end
        end
    end)
    STATE.FAttackTarget = nil
end

GrabTab:CreateInput({
    Name = "타겟 닉네임 입력",
    PlaceholderText = "예: Player1",
    RemoveTextAfterFocusLost = true,
    Callback = function(v)
        if v == "" then return end
        local found
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower():find(v:lower()) or (p.DisplayName and p.DisplayName:lower():find(v:lower())) then
                    found = p; break
                end
            end
        end)
        if not found then
            Rayfield:Notify({Title="오류", Content="해당 유저를 찾을 수 없습니다.", Duration=2}); return
        end
        STATE.SelectedGrabPlayer = found
        Rayfield:Notify({Title="타겟 설정됨", Content=found.Name.."님이 타겟으로 설정되었습니다.", Duration=2})
    end
})

GrabTab:CreateToggle({
    Name = "카메라 조준 킥 그랩 [Instant Snap]",
    Callback = function(v)
        if v and not STATE.SelectedGrabPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3}); return
        end
        if v then startFKeyAttack(STATE.SelectedGrabPlayer) else stopFKeyAttack() end
    end
})

--=============================================
-- [KICK 탭]
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)

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
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower():find(v:lower()) or (p.DisplayName and p.DisplayName:lower():find(v:lower())) then
                    found = p; break
                end
            end
        end)
        if not found then
            Rayfield:Notify({Title="오류", Content="해당 유저를 찾을 수 없습니다.", Duration=2}); return
        end
        STATE.SelectedKickPlayer = found
        Rayfield:Notify({Title="타겟 설정됨", Content=found.Name.."님이 타겟으로 설정되었습니다.", Duration=2})
    end
})

KickTab:CreateSection("Fling 설정")
KickTab:CreateSlider({
    Name = "Fling 거리 (studs)",
    Range = { 10, 9999999 },
    Increment = 1,
    Suffix = " studs",
    Default = 9999999,
    Callback = function(v)
        STATE.FlingDistance = v
    end
})

KickTab:CreateDropdown({
    Name = "Fling 방향",
    Options = { "forward", "backward", "left", "right", "up", "random" },
    CurrentOption = "forward",
    Callback = function(opt)
        STATE.FlingDirection = opt
    end
})

local BP_PREFIX = "_FSOFKickBP_"
local BG_PREFIX = "_FSOFKickBG_"

local function clearAllBodies()
    pcall(function()
        for part, bodies in pairs(targetBodies) do
            for _, b in ipairs(bodies) do
                if b and b.Parent then b:Destroy() end
            end
        end
    end)
    targetBodies = {}
    targetBP_HRP, targetBG_HRP = nil, nil
end

-- ✅ BodyPosition을 극한 P값 + D=0으로 설정 → 즉시 스냅
local function setupBodiesForTarget()
    pcall(function()
        local sp = STATE.SelectedKickPlayer
        if not sp then return end
        local tChar = sp.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end

        clearAllBodies()

        for _, v in pairs(tChar:GetDescendants()) do
            if (v:IsA("BodyPosition") or v:IsA("BodyGyro")) and
               (v.Name:sub(1, #BP_PREFIX) == BP_PREFIX or v.Name:sub(1, #BG_PREFIX) == BG_PREFIX) then
                v:Destroy()
            end
        end

        for _, part in ipairs(tChar:GetDescendants()) do
            if part:IsA("BasePart") then
                local bp = Instance.new("BodyPosition")
                bp.Name = BP_PREFIX .. part.Name
                bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                -- ✅ P 극대화 + D=0 → 최대 가속도로 즉시 이동 (감쇠 없음)
                bp.P = 1e18
                bp.D = 0
                bp.Parent = part

                local bg = Instance.new("BodyGyro")
                bg.Name = BG_PREFIX .. part.Name
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.P = 1e18
                bg.D = 0
                bg.CFrame = CFrame.Angles(0, 0, 0)
                bg.Parent = part

                targetBodies[part] = {bp, bg}
                if part == tHRP then targetBP_HRP, targetBG_HRP = bp, bg end
            end
        end
    end)
end

local function startKickLoop()
    if steppedConn then pcall(function() steppedConn:Disconnect() end); steppedConn = nil end
    if respawnConn then pcall(function() respawnConn:Disconnect() end); respawnConn = nil end

    STATE.KickLoopRunning = true

    pcall(function()
        if STATE.SelectedKickPlayer then
            respawnConn = STATE.SelectedKickPlayer.CharacterAdded:Connect(function(newChar)
                pcall(function()
                    local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
                    local hum = newChar:WaitForChild("Humanoid", 5)
                    if hrp and hum then
                        local waitStart = tick()
                        while hum.Health <= 0 and tick() - waitStart < 10 do task.wait(0.1) end
                        task.wait(0.2)
                        setupBodiesForTarget()
                        initialBurst(newChar, function() return STATE.KickLoopRunning end)

                        -- ✅ 즉시 순간이동 (CFrame 직접 지정)
                        local holdPos = getHoldPosition(true)
                        if holdPos then
                            for _, part in ipairs(newChar:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    pcall(function()
                                        part.CFrame = CFrame.new(holdPos)
                                        part.AssemblyLinearVelocity = Vector3.zero
                                        part.AssemblyAngularVelocity = Vector3.zero
                                    end)
                                end
                            end
                        end
                    end
                end)
            end)
        end
    end)

    -- ✅ 전신 박제 + 즉시 순간이동
    steppedConn = RunService.Stepped:Connect(function()
        pcall(function()
            if not STATE.KickLoopRunning then return end
            local sp = STATE.SelectedKickPlayer
            if not sp then return end

            local myChar = plr.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local tChar = sp.Character
            local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
            if not (myChar and myHRP) or not (tChar and tHRP) then return end

            if not targetBP_HRP or not targetBP_HRP.Parent or targetBP_HRP.Parent ~= tHRP then
                setupBodiesForTarget()
            end

            local holdPos = getHoldPosition(true)
            if not holdPos then return end

            local zeroCF = CFrame.Angles(0, 0, 0)
            for part, bodies in pairs(targetBodies) do
                if part and part.Parent then
                    local bp, bg = bodies[1], bodies[2]
                    if bp and bp.Parent then bp.Position = holdPos end
                    if bg and bg.Parent then bg.CFrame = zeroCF end
                    -- ✅ 직접 CFrame 지정 → BodyPosition이 못 따라가도 즉시 이동
                    pcall(function()
                        part.CFrame = CFrame.new(holdPos)
                    end)
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
    end)

    kickThread = task.spawn(function()
        pcall(function()
            local sp = STATE.SelectedKickPlayer
            if sp and sp.Character then
                initialBurst(sp.Character, function() return STATE.KickLoopRunning end)
            end
        end)

        while STATE.KickLoopRunning do
            task.wait()
            pcall(function()
                local sp = STATE.SelectedKickPlayer
                if not sp then return end
                local tChar = sp.Character
                local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not (tHRP and myHRP) then return end

                local parts = getCoreParts(tChar)
                for _, part in ipairs(parts) do
                    claimPart(part)
                end
            end)
        end
    end)
end

local function stopKickLoop()
    STATE.KickLoopRunning = false
    if steppedConn then pcall(function() steppedConn:Disconnect() end); steppedConn = nil end
    if respawnConn then pcall(function() respawnConn:Disconnect() end); respawnConn = nil end

    clearAllBodies()

    pcall(function()
        local sp = STATE.SelectedKickPlayer
        if sp and sp.Character then
            for _, v in pairs(sp.Character:GetDescendants()) do
                if (v:IsA("BodyPosition") or v:IsA("BodyGyro")) and
                   (v.Name:sub(1, #BP_PREFIX) == BP_PREFIX or v.Name:sub(1, #BG_PREFIX) == BG_PREFIX) then
                    v:Destroy()
                end
            end
        end
    end)
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 [Instant Snap]",
    Callback = function(v)
        if v and not STATE.SelectedKickPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3}); return
        end
        if v then startKickLoop() else stopKickLoop() end
    end
})

--=============================================
-- [팔레트 레그돌]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis)",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        pcall(function()
            local DestroyToy = rs:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
            local SetNetOwner = rs:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
            local DestroyLine = rs:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
            local lpName = plr.Name
            local toysFolder = workspace:WaitForChild(lpName .. "SpawnedInToys", 5)

            local function clearRagdollLoop()
                if STATE.RagdollSteppedConn then
                    pcall(function() STATE.RagdollSteppedConn:Disconnect() end)
                    STATE.RagdollSteppedConn = nil
                end
            end

            if Value then
                if not STATE.SelectedKickPlayer then
                    Rayfield:Notify({Title = "알림", Content = "타겟을 먼저 입력해주세요!", Duration = 3})
                    return
                end

                STATE.PalletRagdollActive = true
                STATE.PalletForRagdoll = nil

                if STATE.PalletCacheConn then pcall(function() STATE.PalletCacheConn:Disconnect() end) end
                clearRagdollLoop()

                if not toysFolder then
                    Rayfield:Notify({Title = "오류", Content = "토이 폴더 없음", Duration = 3}); return
                end

                STATE.PalletCacheConn = toysFolder.ChildAdded:Connect(function(child)
                    pcall(function()
                        if not STATE.PalletRagdollActive then return end
                        if child.Name ~= "PalletLightBrown" and child.Name ~= "PalletForRagdoll" then return end

                        local soundPart = child:WaitForChild("SoundPart", 3)
                        if not soundPart then return end

                        SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                        DestroyLine:FireServer(soundPart)

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
                            STATE.PalletForRagdoll = child

                            STATE.RagdollSteppedConn = RunService.Stepped:Connect(function()
                                pcall(function()
                                    if not STATE.PalletRagdollActive or not child.Parent then 
                                        clearRagdollLoop(); return 
                                    end

                                    local sp = STATE.SelectedKickPlayer
                                    local tChar = sp and sp.Character
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
                            end)

                            child.AncestryChanged:Connect(function()
                                pcall(function()
                                    if not child.Parent then
                                        clearRagdollLoop()
                                        STATE.PalletForRagdoll = nil
                                        if STATE.PalletRagdollActive then
                                            task.wait(0.03)
                                            if STATE.SpawnNewPallet then STATE.SpawnNewPallet() end
                                        end
                                    end
                                end)
                            end)
                        else
                            DestroyToy:FireServer(child)
                        end
                    end)
                end)

                STATE.SpawnNewPallet = function()
                    pcall(function()
                        if not STATE.PalletRagdollActive then return end
                        if STATE.PalletForRagdoll and STATE.PalletForRagdoll.Parent then return end
                        
                        local c = plr.Character
                        local h = c and c:FindFirstChild("HumanoidRootPart")
                        if not h then return end

                        task.spawn(function()
                            pcall(function()
                                rs.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                                    "PalletLightBrown",
                                    h.CFrame * CFrame.new(0, 10, 20),
                                    Vector3.zero
                                )
                            end)
                        end)
                    end)
                end

                STATE.SpawnNewPallet()
            else
                STATE.PalletRagdollActive = false
                clearRagdollLoop()

                if STATE.PalletCacheConn then
                    pcall(function() STATE.PalletCacheConn:Disconnect() end)
                    STATE.PalletCacheConn = nil
                end

                local pallet = STATE.PalletForRagdoll
                if pallet and pallet.Parent then
                    DestroyToy:FireServer(pallet)
                end

                STATE.PalletForRagdoll = nil

                if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then
                    DestroyToy:FireServer(toysFolder.PalletForRagdoll)
                end
            end
        end)
    end,
})

--=============================================
-- [Settings]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)

SettingsTab:CreateButton({
    Name = "재설정 (Reset)",
    Callback = function()
        pcall(function()
            STATE.FKeyAttackActive = false
            STATE.KickLoopRunning = false
            STATE.PalletRagdollActive = false
            STATE.FAttackTarget = nil
        end)
        Rayfield:Notify({Title="알림", Content="초기화 완료"})
    end
})

SettingsTab:CreateButton({
    Name = "완전 언로드 (Full Unload)",
    Callback = function()
        pcall(function()
            STATE.FKeyAttackActive = false
            STATE.KickLoopRunning = false
            STATE.PalletRagdollActive = false

            if steppedConn then steppedConn:Disconnect() end
            if respawnConn then respawnConn:Disconnect() end
            if kickThread then pcall(function() task.cancel(kickThread) end) end
            if STATE.RagdollSteppedConn then STATE.RagdollSteppedConn:Disconnect() end
            if STATE.PalletCacheConn then STATE.PalletCacheConn:Disconnect() end

            clearAllBodies()

            local sp = STATE.SelectedKickPlayer
            if sp and sp.Character then
                for _, v in pairs(sp.Character:GetDescendants()) do
                    if (v:IsA("BodyPosition") or v:IsA("BodyGyro")) and
                       (v.Name:sub(1, #BP_PREFIX) == BP_PREFIX or v.Name:sub(1, #BG_PREFIX) == BG_PREFIX) then
                        v:Destroy()
                    end
                end
            end
        end)
        Rayfield:Notify({Title="언로드", Content="모든 루프 종료됨"})
    end
})

SettingsTab:CreateSection("정보")
SettingsTab:CreateParagraph({
    Title = "Instant Snap 원리",
    Content = "속도를 높이는 방법 3중 적용:\n" ..
              "1. BodyPosition P = 1e18, D = 0 (감쇠 없음, 최대 가속)\n" ..
              "2. AlignPosition RigidityEnabled = true (물리 무시 즉시 스냅)\n" ..
              "3. 매 프레임 직접 part.CFrame = CFrame.new(holdPos) 강제 지정\n" ..
              "→ 빈도 증가가 아니라 이동 자체를 순간이동으로 처리"
})

Rayfield:Notify({
    Title = "Instant Snap Variant 로드 완료",
    Content = "속도 극대화: P=1e18/D=0 + Rigidity + 직접 CFrame",
    Duration = 4
})
