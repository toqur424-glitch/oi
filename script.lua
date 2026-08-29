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
local SetNetworkOwner = GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner")
local DestroyGrabLine = GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine")

local function handleAntiGrabEscape(...)
    task.spawn(function()
        if not selectedKickPlayer then return end
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if tHRP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            for i = 1, 5 do
                pcall(function()
                    SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(plr.Character.HumanoidRootPart.Position, tHRP.Position))
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
            if fCounter % 2 == 1 then
                pcall(function()
                    SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                end)
            else
                pcall(function()
                    DestroyGrabLine:FireServer(tgtRoot)
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
-- [KICK 탭] - BodyPosition(math.huge) 몸통+HRP 초고속 + 800Hz 원격 호출
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false
local kickCounter = 0

-- 고정 갱신용 이벤트 연결들
local renderSteppedConn = nil
local heartbeatConn = nil
local steppedConn = nil
local highFreqThread = nil    -- 추가 고주파 BodyPosition 갱신 루프
local remoteThread = nil      -- 원격 호출 루프 (800Hz)
local respawnConn = nil

-- 현재 부착된 BodyPosition 테이블 (부품별)
local bodyPositions = {}      -- { [part] = BodyPosition }

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

-- 고정할 부품 목록 반환 (몸통 + HRP)
local function getTargetParts(character)
    local parts = {}
    if not character then return parts end
    
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if torso then table.insert(parts, torso) end
    if hrp and hrp ~= torso then table.insert(parts, hrp) end
    return parts
end

-- 목표 위치: 월드 좌표 y=20, x/z는 HRP(없으면 첫 부품)의 현재 위치 유지
local function getTargetPosition()
    if not selectedKickPlayer then return Vector3.new(0, 20, 0) end
    local char = selectedKickPlayer.Character
    local parts = getTargetParts(char)
    if #parts > 0 then
        local refPart = char:FindFirstChild("HumanoidRootPart") or parts[1]
        return Vector3.new(refPart.Position.X, 20, refPart.Position.Z)
    end
    return Vector3.new(0, 20, 0)
end

local function clearBodyPositions()
    for part, bp in pairs(bodyPositions) do
        if bp and bp.Parent then
            bp:Destroy()
        end
    end
    bodyPositions = {}
end

local function setupBodyPositions()
    clearBodyPositions()
    if not selectedKickPlayer then return end
    local char = selectedKickPlayer.Character
    local parts = getTargetParts(char)
    
    for _, part in ipairs(parts) do
        part.Anchored = false
        
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.Position = getTargetPosition()
        bp.Parent = part
        bodyPositions[part] = bp
    end
end

-- 초고속 고정 함수: 모든 부품에 대해 BodyPosition 갱신 + CFrame/속도 제어
local function updateBodyLock()
    if not kickLoopRunning or not selectedKickPlayer then return end
    local char = selectedKickPlayer.Character
    local parts = getTargetParts(char)
    local targetPos = getTargetPosition()
    
    for _, part in ipairs(parts) do
        -- 1. BodyPosition 갱신 or 재생성
        local bp = bodyPositions[part]
        if not bp or bp.Parent ~= part then
            if bp then bp:Destroy() end
            bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.Parent = part
            bodyPositions[part] = bp
        end
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.Position = targetPos
        
        -- 2. 직접 CFrame 설정 (순간 이동)
        pcall(function()
            part.CFrame = CFrame.new(targetPos)
        end)
        
        -- 3. 속도 0 (낙하/회전 방지)
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
        
        -- 4. 앵커 해제 유지
        part.Anchored = false
    end
end

local function startKickLoop()
    -- 기존 연결 해제
    if remoteThread then task.cancel(remoteThread) end
    if highFreqThread then task.cancel(highFreqThread) end
    if renderSteppedConn then renderSteppedConn:Disconnect() end
    if heartbeatConn then heartbeatConn:Disconnect() end
    if steppedConn then steppedConn:Disconnect() end
    if respawnConn then respawnConn:Disconnect() end
    
    kickLoopRunning = true
    kickCounter = 0

    -- 리스폰 감지
    if selectedKickPlayer then
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(0.1)
            setupBodyPositions()
            updateBodyLock()
        end)
    end

    -- 초기 설정
    setupBodyPositions()
    updateBodyLock()
    
    -- 1. RenderStepped: 렌더링 직전
    renderSteppedConn = RunService.RenderStepped:Connect(function()
        updateBodyLock()
    end)
    
    -- 2. Heartbeat: 물리 이전
    heartbeatConn = RunService.Heartbeat:Connect(function()
        updateBodyLock()
    end)
    
    -- 3. Stepped: 물리 이후
    steppedConn = RunService.Stepped:Connect(function()
        updateBodyLock()
    end)
    
    -- 4. 추가 고주파 BodyPosition 갱신 루프 (800Hz)
    highFreqThread = task.spawn(function()
        local interval = 0.00125  -- 800Hz
        local nextTime = tick() + interval
        while kickLoopRunning do
            while tick() < nextTime do
                task.wait()
            end
            nextTime = nextTime + interval
            updateBodyLock()
        end
    end)
    
    -- 5. 원격 호출 루프 (800Hz): SetOwner 1회, Destroy 2회 패턴
    remoteThread = task.spawn(function()
        local interval = 0.00125  -- 800Hz
        local nextTime = tick() + interval
        
        while kickLoopRunning do
            while tick() < nextTime do
                task.wait()
            end
            nextTime = nextTime + interval
            
            if not selectedKickPlayer then continue end
            
            local char = selectedKickPlayer.Character
            local parts = getTargetParts(char)
            local myChar = plr.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            
            if not (myChar and myHRP) then continue end
            
            for _, part in ipairs(parts) do
                kickCounter = kickCounter + 1
                if kickCounter % 3 == 1 then
                    pcall(function()
                        SetNetworkOwner:FireServer(part, CFrame.lookAt(myHRP.Position, part.Position))
                    end)
                else
                    pcall(function()
                        DestroyGrabLine:FireServer(part)
                    end)
                end
            end
        end
    end)
end

local function stopKickLoop()
    kickLoopRunning = false
    if remoteThread then task.cancel(remoteThread) remoteThread = nil end
    if highFreqThread then task.cancel(highFreqThread) highFreqThread = nil end
    if renderSteppedConn then renderSteppedConn:Disconnect() renderSteppedConn = nil end
    if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
    if steppedConn then steppedConn:Disconnect() steppedConn = nil end
    if respawnConn then respawnConn:Disconnect() respawnConn = nil end
    clearBodyPositions()
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 (BodyPosition math.huge 몸통+HRP 800Hz)",
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

Rayfield:Notify({Title = "로딩 완료", Content = "BodyPosition(math.huge) 몸통+HRP 800Hz 고정", Duration = 3})
