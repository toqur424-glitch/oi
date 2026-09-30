--=============================================
-- [FSOF EXTREME Kick Hub - No Align / 45° Up Fling]
-- - AlignPosition 완전 제거
-- - CreateLine 로직 완전 제거
-- - 다른 스크립트와 병행 사용 가능
-- - 스마트 소유권
-- - 기본 위치: Y=-8, 앞 3스터드
-- - 셋오너 킥 ON 시: 그 위치에서 9,999,999스터드, 45도 위로 순간이동
-- - ✅ 켤 때 28 스터드 이내여야만 ON 됨 (멀면 거부)
-- - ✅ 켜진 후에도 28 밖으로 나가면 자동 OFF
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
STATE.FlingElevationDeg = 45

-- ✅ 발동 거리 (28 스터드)
STATE.ActivationRange = 28

--=============================================
-- [UI 생성]
--=============================================
local Window = Rayfield:CreateWindow({
    Name = "🔥 FSOF EXTREME Kick Hub (45° Up Fling)",
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

-- ✅ 발동 거리 체크 (28 스터드 이내)
local function isInRange(targetChar)
    if not targetChar then return false end
    local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    local tHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return false end

    local dist = (tHRP.Position - myHRP.Position).Magnitude
    return dist <= STATE.ActivationRange
end

-- ✅ 거리 반환 (거부 메시지용)
local function getDistanceTo(targetChar)
    if not targetChar then return math.huge end
    local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return math.huge end
    local tHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return math.huge end
    return (tHRP.Position - myHRP.Position).Magnitude
end

--=============================================
-- [위치 계산 - Y=-8, 앞 3스터드 / 셋오너 시 45도 위로 fling]
--=============================================
local function getHorizontalForward()
    local camCF = camera.CFrame
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    if forward.Magnitude > 0 then
        forward = forward.Unit
    else
        forward = Vector3.new(0, 0, -1)
    end
    return forward
end

local function getFlingOffsetVector()
    local forward = getHorizontalForward()
    local rad = math.rad(STATE.FlingElevationDeg)
    local h = math.cos(rad)
    local v = math.sin(rad)

    return Vector3.new(forward.X * h, v, forward.Z * h)
end

local function getHoldPosition(kickActive)
    local myChar = plr.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local myPos = myHRP.Position
    local forward = getHorizontalForward()

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
-- [GRAB 탭] - AlignPosition 없이 BodyPosition만 사용
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (No Align / 45° Up Fling) ===")

local function setupGrabBodies(targetPlayer)
    pcall(function()
        local tChar = targetPlayer and targetPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end

        for _, v in pairs(tHRP:GetChildren()) do
            if v:IsA("BodyPosition") and v.Name == "FKeyBP" then v:Destroy() end
            if v:IsA("BodyGyro") and v.Name == "FKeyBG" then v:Destroy() end
        end

        local bp = Instance.new("BodyPosition")
        bp.Name = "FKeyBP"
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 1e18
        bp.D = 0
        bp.Parent = tHRP

        local bg = Instance.new("BodyGyro")
        bg.Name = "FKeyBG"
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 1e18
        bg.D = 0
        bg.CFrame = CFrame.Angles(0, 0, 0)
        bg.Parent = tHRP
    end)
end

-- ✅ GrabToggle 참조 저장 (자동 OFF 용)
local GrabToggleRef = nil

local function startFKeyAttack(targetPlayer)
    -- ✅ 시작 시점에 28 스터드 이내인지 체크
    local tChar = targetPlayer and targetPlayer.Character
    if not tChar or not isInRange(tChar) then
        local d = math.floor(getDistanceTo(tChar))
        Rayfield:Notify({
            Title = "❌ 발동 거부",
            Content = "타겟이 " .. d .. " 스터드에 있음. " .. STATE.ActivationRange .. " 스터드 이내일 때만 가능!",
            Duration = 4
        })
        -- 토글 강제 OFF
        if GrabToggleRef and GrabToggleRef.Set then
            pcall(function() GrabToggleRef:Set(false) end)
        end
        return false
    end

    STATE.FKeyAttackActive = true
    STATE.FAttackTarget = targetPlayer
    setupGrabBodies(targetPlayer)

    task.spawn(function()
        pcall(function()
            local tChar2 = targetPlayer and targetPlayer.Character
            if tChar2 and isInRange(tChar2) then
                initialBurst(tChar2, function() return STATE.FKeyAttackActive end)
            end
        end)

        while STATE.FKeyAttackActive do
            task.wait()
            pcall(function()
                local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local tChar2 = STATE.FAttackTarget and STATE.FAttackTarget.Character
                local tgtRoot = tChar2 and tChar2:FindFirstChild("HumanoidRootPart")
                local tgtHum = tChar2 and tChar2:FindFirstChild("Humanoid")

                if not myRoot or not tgtRoot then return end

                -- ✅ 28 스터드 밖이면 자동 OFF
                if not isInRange(tChar2) then
                    STATE.FKeyAttackActive = false
                    -- 토글 강제 OFF
                    if GrabToggleRef and GrabToggleRef.Set then
                        pcall(function() GrabToggleRef:Set(false) end)
                    end
                    Rayfield:Notify({
                        Title = "⛔ 자동 종료",
                        Content = "타겟이 " .. STATE.ActivationRange .. " 스터드 밖으로 이동",
                        Duration = 3
                    })
                    return
                end

                tgtRoot.AssemblyLinearVelocity = Vector3.zero
                tgtRoot.AssemblyAngularVelocity = Vector3.zero
                if tgtHum then
                    tgtHum.PlatformStand = true
                    tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
                end

                local holdPos = getHoldPosition(true)
                if not holdPos then return end

                local bp = tgtRoot:FindFirstChild("FKeyBP")
                if not bp then
                    setupGrabBodies(STATE.FAttackTarget)
                else
                    bp.Position = holdPos
                end

                local bg = tgtRoot:FindFirstChild("FKeyBG")
                if bg then bg.CFrame = CFrame.Angles(0, 0, 0) end

                pcall(function()
                    tgtRoot.CFrame = CFrame.new(holdPos)
                end)

                local parts = getCoreParts(tChar2)
                for _, part in ipairs(parts) do
                    claimPart(part)
                end
            end)
        end
    end)
    return true
end

local function stopFKeyAttack()
    STATE.FKeyAttackActive = false
    pcall(function()
        if STATE.FAttackTarget and STATE.FAttackTarget.Character then
            local tHRP = STATE.FAttackTarget.Character:FindFirstChild("HumanoidRootPart")
            if tHRP then
                for _, v in pairs(tHRP:GetChildren()) do
                    if v:IsA("BodyPosition") and v.Name == "FKeyBP" then v:Destroy() end
                    if v:IsA("BodyGyro") and v.Name == "FKeyBG" then v:Destroy() end
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

GrabToggleRef = GrabTab:CreateToggle({
    Name = "카메라 조준 킥 그랩 [No Align / 45° Up]",
    Callback = function(v)
        if v and not STATE.SelectedGrabPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3})
            if GrabToggleRef and GrabToggleRef.Set then
                pcall(function() GrabToggleRef:Set(false) end)
            end
            return
        end
        if v then
            local ok = startFKeyAttack(STATE.SelectedGrabPlayer)
            if not ok and GrabToggleRef and GrabToggleRef.Set then
                pcall(function() GrabToggleRef:Set(false) end)
            end
        else
            stopFKeyAttack()
        end
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

KickTab:CreateSection("Fling 설정 (45도 위로 고정)")
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

KickTab:CreateSlider({
    Name = "Fling 각도 (도)",
    Range = { 0, 90 },
    Increment = 1,
    Suffix = " °",
    Default = 45,
    Callback = function(v)
        STATE.FlingElevationDeg = v
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

-- ✅ KickToggle 참조 저장 (자동 OFF 용)
local KickToggleRef = nil

local function startKickLoop()
    -- ✅ 시작 시점에 28 스터드 이내인지 체크
    local sp = STATE.SelectedKickPlayer
    local tChar = sp and sp.Character
    if not tChar or not isInRange(tChar) then
        local d = math.floor(getDistanceTo(tChar))
        Rayfield:Notify({
            Title = "❌ 발동 거부",
            Content = "타겟이 " .. d .. " 스터드에 있음. " .. STATE.ActivationRange .. " 스터드 이내일 때만 가능!",
            Duration = 4
        })
        if KickToggleRef and KickToggleRef.Set then
            pcall(function() KickToggleRef:Set(false) end)
        end
        return false
    end

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

                        if isInRange(newChar) then
                            setupBodiesForTarget()
                            initialBurst(newChar, function() return STATE.KickLoopRunning end)

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
                    end
                end)
            end)
        end
    end)

    -- ✅ Stepped: 28 이내면 박제 / 밖이면 자동 OFF
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

            -- ✅ 28 스터드 밖이면 자동 OFF
            if not isInRange(tChar) then
                STATE.KickLoopRunning = false
                clearAllBodies()
                if KickToggleRef and KickToggleRef.Set then
                    pcall(function() KickToggleRef:Set(false) end)
                end
                Rayfield:Notify({
                    Title = "⛔ 자동 종료",
                    Content = "타겟이 " .. STATE.ActivationRange .. " 스터드 밖으로 이동",
                    Duration = 3
                })
                return
            end

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
            local sp2 = STATE.SelectedKickPlayer
            if sp2 and sp2.Character and isInRange(sp2.Character) then
                initialBurst(sp2.Character, function() return STATE.KickLoopRunning end)
            end
        end)

        while STATE.KickLoopRunning do
            task.wait()
            pcall(function()
                local sp2 = STATE.SelectedKickPlayer
                if not sp2 then return end
                local tChar = sp2.Character
                if not tChar then return end

                -- ✅ 28 스터드 밖이면 자동 OFF
                if not isInRange(tChar) then
                    STATE.KickLoopRunning = false
                    if KickToggleRef and KickToggleRef.Set then
                        pcall(function() KickToggleRef:Set(false) end)
                    end
                    return
                end

                local parts = getCoreParts(tChar)
                for _, part in ipairs(parts) do
                    claimPart(part)
                end
            end)
        end
    end)
    return true
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

KickToggleRef = KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 [No Align / 45° Up]",
    Callback = function(v)
        if v and not STATE.SelectedKickPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3})
            if KickToggleRef and KickToggleRef.Set then
                pcall(function() KickToggleRef:Set(false) end)
            end
            return
        end
        if v then
            local ok = startKickLoop()
            if not ok and KickToggleRef and KickToggleRef.Set then
                pcall(function() KickToggleRef:Set(false) end)
            end
        else
            stopKickLoop()
        end
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
    Title = "45° Up Fling 원리",
    Content = "AlignPosition 완전 제거.\n" ..
              "- BodyPosition P=1e18, D=0 (최대 가속)\n" ..
              "- 매 프레임 part.CFrame 직접 지정 (즉시 순간이동)\n" ..
              "- Fling 방향: 수평 앞 * cos(45°), 수직 위 * sin(45°)\n" ..
              "- 45도 각도 슬라이더로 조정 가능 (0~90)\n" ..
              "- 발동 조건: 타겟이 28 스터드 이내일 때만 (멀면 자동 거부)"
})

Rayfield:Notify({
    Title = "45° Up Fling 로드 완료",
    Content = "Align 제거 / 45도 위로 9,999,999스터드 / 28 이내만 발동",
    Duration = 4
})
