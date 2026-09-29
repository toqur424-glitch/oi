--=============================================
-- [FSOF EXTREME Kick Hub - Server Fling (45° Up)]
-- - 소유권 강탈 → AssemblyLinearVelocity 로 진짜 서버 플링
-- - AlignPosition / CreateLine 완전 제거
-- - 다른 스크립트와 병행 / 소유권 경쟁에서 승리
--=============================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if game.PlaceId ~= 6961824067 then 
    Rayfield:Notify({Title="Error", Content="이 게임을 지원하지 않습니다.", Duration=3})
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

-- ✅ 서버 플링 설정
STATE.FlingVelocity = 9999999      -- AssemblyLinearVelocity 크기 (studs/s)
STATE.FlingElevationDeg = 45       -- 위로 45도
STATE.StealPerFrame = 12           -- 매 프레임 소유권 강탈 리모트 발사 횟수

--=============================================
-- [UI]
--=============================================
local Window = Rayfield:CreateWindow({
    Name = "🔥 FSOF EXTREME Kick Hub (Server Fling)",
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
-- [핵심: 소유권 강탈 + 서버 전파 플링]
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
    -- ✅ 팔다리도 포함 → 서버가 "전신이 날아간다" 로 인식
    for _, name in ipairs({"Left Arm","Right Arm","Left Leg","Right Leg"}) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then table.insert(parts, p) end
    end
    return parts
end

local function isOwnedByMe(part)
    if not part or not part.Parent then return false end
    local ok, owner = pcall(function() return part:FindFirstChild("PartOwner") end)
    if not ok or not owner then return false end
    local ok2, val = pcall(function() return owner.Value end)
    return ok2 and val == plr.Name
end

-- ✅ 강력한 소유권 강탈 (매 프레임 여러 번)
-- DestroyGrabLine → SetNetworkOwner 콤보를 연속 발사
local function stealOwnership(part, times)
    if not part or not part.Parent then return end
    times = times or STATE.StealPerFrame
    for i = 1, times do
        pcall(function()
            rs.GrabEvents.DestroyGrabLine:FireServer(part)
        end)
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame)
        end)
    end
end

-- ✅ 서버 플링용 velocity 벡터 (45도 위, forward 기준)
local function getFlingVelocity()
    local camCF = camera.CFrame
    local fwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    if fwd.Magnitude > 0 then fwd = fwd.Unit else fwd = Vector3.new(0,0,-1) end

    local rad = math.rad(STATE.FlingElevationDeg)
    local h = math.cos(rad)
    local v = math.sin(rad)

    return Vector3.new(
        fwd.X * h,
        v,
        fwd.Z * h
    ) * STATE.FlingVelocity
end

-- ✅ 메인 플링 함수: 소유권 뺏고, velocity 설정
local function flingTarget(targetChar)
    if not targetChar then return end
    local parts = getCoreParts(targetChar)
    if #parts == 0 then return end

    local vel = getFlingVelocity()
    local spinVel = Vector3.new(9e9, 9e9, 9e9)

    local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")

    for _, part in ipairs(parts) do
        if not part.Parent then continue end

        -- 거리 체크 (SetOwner 서버 검증 30 스터드)
        if myHRP then
            local dist = (part.Position - myHRP.Position).Magnitude
            -- 가까우면 소유권 강탈 시도
            if dist <= 30 then
                stealOwnership(part, STATE.StealPerFrame)
            end
        end

        -- ✅ 소유권 확인 후에만 velocity 적용 (서버에 전파되는지 확인)
        if isOwnedByMe(part) then
            pcall(function()
                part.Massless = false
                part.AssemblyLinearVelocity = vel
                part.AssemblyAngularVelocity = spinVel
            end)
        end
    end

    -- Humanoid 상태도 물리로
    local hum = targetChar:FindFirstChild("Humanoid")
    if hum then
        pcall(function()
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end
end

--=============================================
-- [초기 버스트 - 강화판]
--=============================================
local function initialBurst(char, shouldContinue)
    if not char then return end
    local parts = getCoreParts(char)
    if #parts == 0 then return end

    for round = 1, 12 do
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
-- [GRAB 탭]
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (서버 플링 / 45° 위 / 소유권 강탈) ===")

local function startFKeyAttack(targetPlayer)
    STATE.FKeyAttackActive = true
    STATE.FAttackTarget = targetPlayer

    task.spawn(function()
        -- 초기 버스트
        pcall(function()
            local tChar = targetPlayer and targetPlayer.Character
            if tChar then
                initialBurst(tChar, function() return STATE.FKeyAttackActive end)
            end
        end)

        -- 매 프레임: 소유권 강탈 + velocity 적용
        while STATE.FKeyAttackActive do
            task.wait()
            pcall(function()
                local tChar = STATE.FAttackTarget and STATE.FAttackTarget.Character
                if tChar then
                    flingTarget(tChar)
                end
            end)
        end
    end)
end

local function stopFKeyAttack()
    STATE.FKeyAttackActive = false
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

GrabTab:CreateSlider({
    Name = "플링 속도 (studs/s)",
    Range = { 1000, 99999999 },
    Increment = 1,
    Suffix = " studs/s",
    Default = 9999999,
    Callback = function(v)
        STATE.FlingVelocity = v
    end
})

GrabTab:CreateSlider({
    Name = "각도 (도)",
    Range = { 0, 90 },
    Increment = 1,
    Suffix = " °",
    Default = 45,
    Callback = function(v)
        STATE.FlingElevationDeg = v
    end
})

GrabTab:CreateSlider({
    Name = "소유권 강탈 강도 (매 프레임)",
    Range = { 1, 30 },
    Increment = 1,
    Default = 12,
    Callback = function(v)
        STATE.StealPerFrame = v
    end
})

GrabTab:CreateToggle({
    Name = "카메라 조준 킥 그랩 [서버 플링]",
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
local kickThread, respawnConn = nil, nil

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

local function startKickLoop()
    if respawnConn then pcall(function() respawnConn:Disconnect() end); respawnConn = nil end
    STATE.KickLoopRunning = true

    -- 리스폰 대응
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
                        initialBurst(newChar, function() return STATE.KickLoopRunning end)
                        flingTarget(newChar)
                    end
                end)
            end)
        end
    end)

    -- 매 프레임 강탈 + velocity
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
                if tChar then
                    flingTarget(tChar)
                end
            end)
        end
    end)
end

local function stopKickLoop()
    STATE.KickLoopRunning = false
    if respawnConn then pcall(function() respawnConn:Disconnect() end); respawnConn = nil end
    if kickThread then pcall(function() task.cancel(kickThread) end); kickThread = nil end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 [서버 플링]",
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
                    Rayfield:Notify({Title="알림", Content="타겟을 먼저 입력해주세요!", Duration=3}); return
                end

                STATE.PalletRagdollActive = true
                STATE.PalletForRagdoll = nil
                if STATE.PalletCacheConn then pcall(function() STATE.PalletCacheConn:Disconnect() end) end
                clearRagdollLoop()

                if not toysFolder then return end

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
                                    if not STATE.PalletRagdollActive or not child.Parent then clearRagdollLoop(); return end
                                    local sp = STATE.SelectedKickPlayer
                                    local tChar = sp and sp.Character
                                    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                                    local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
                                    if tRoot and tHum and soundPart.Parent and tHum.Health > 0 then
                                        local rag = tHum:FindFirstChild("Ragdolled")
                                        local isR = rag and rag.Value or false
                                        if not isR then
                                            local t = tick() * 20
                                            local offY = 15 * math.sin(t)
                                            soundPart.CFrame = tRoot.CFrame * CFrame.Angles(0,0,math.rad(95)) * CFrame.new(0, offY, 0)
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
                                rs.MenuToys.SpawnToyRemoteFunction:InvokeServer("PalletLightBrown", h.CFrame * CFrame.new(0,10,20), Vector3.zero)
                            end)
                        end)
                    end)
                end
                STATE.SpawnNewPallet()
            else
                STATE.PalletRagdollActive = false
                clearRagdollLoop()
                if STATE.PalletCacheConn then pcall(function() STATE.PalletCacheConn:Disconnect() end); STATE.PalletCacheConn = nil end
                local pallet = STATE.PalletForRagdoll
                if pallet and pallet.Parent then DestroyToy:FireServer(pallet) end
                STATE.PalletForRagdoll = nil
                if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then DestroyToy:FireServer(toysFolder.PalletForRagdoll) end
            end
        end)
    end,
})

--=============================================
-- [Settings]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({
    Name = "완전 언로드",
    Callback = function()
        pcall(function()
            STATE.FKeyAttackActive = false
            STATE.KickLoopRunning = false
            STATE.PalletRagdollActive = false
            if respawnConn then respawnConn:Disconnect() end
            if kickThread then pcall(function() task.cancel(kickThread) end) end
            if STATE.RagdollSteppedConn then STATE.RagdollSteppedConn:Disconnect() end
            if STATE.PalletCacheConn then STATE.PalletCacheConn:Disconnect() end
        end)
        Rayfield:Notify({Title="언로드", Content="모든 루프 종료됨"})
    end
})

Rayfield:Notify({
    Title = "Server Fling 로드 완료",
    Content = "소유권 강탈 → AssemblyLinearVelocity 45° 위 9,999,999 / 진짜 서버 플링",
    Duration = 4
})
