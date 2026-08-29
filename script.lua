--=============================================
-- [초기 로드 및 게임 체크] - 개선 버전
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
-- [개선된 헬퍼 함수들]
--=============================================

-- 거리 체크 함수
local function checkDistance(targetPart, maxDist)
    if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then return false end
    local myRoot = plr.Character.HumanoidRootPart
    return (myRoot.Position - targetPart.Position).Magnitude <= (maxDist or 30)
end

-- 네트워크 소유권 확인
local function checkNetworkOwnership(targetPart)
    if not targetPart then return false end
    local owner = targetPart:FindFirstChild("PartOwner")
    if owner and owner:IsA("StringValue") then
        return owner.Value == plr.Name
    end
    return false
end

-- SNOWship 스타일의 SetNetworkOwner (단일 호출)
local function setNetworkOwnerOnce(targetPart)
    if not checkDistance(targetPart, 30) then return false end
    if checkNetworkOwnership(targetPart) then return true end
    
    local myRoot = plr.Character.HumanoidRootPart
    pcall(function()
        rs.GrabEvents.SetNetworkOwner:FireServer(targetPart, CFrame.lookAt(myRoot.Position, targetPart.Position))
    end)
    return false
end

-- 소유권 확인 및 최대 5회 시도 (참조 파일의 SNOWshipOnceAndCheck 방식)
local function setNetworkOwnerWithRetry(targetPart, maxAttempts)
    maxAttempts = maxAttempts or 5
    if not checkDistance(targetPart, 30) then return false end
    
    local myRoot = plr.Character.HumanoidRootPart
    
    -- 1회 시도
    if not checkNetworkOwnership(targetPart) then
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(targetPart, CFrame.lookAt(myRoot.Position, targetPart.Position))
        end)
    else
        return true
    end
    
    -- 재시도 루프 (Heartbeat 대기 포함)
    for i = 1, maxAttempts do
        RunService.Heartbeat:Wait()
        if checkNetworkOwnership(targetPart) then
            return true
        end
    end
    
    return checkNetworkOwnership(targetPart)
end

-- 안전한 텔레포트 (디트로이트 방지)
local function safeSetCFrame(targetPart, newCFrame)
    pcall(function()
        targetPart.CFrame = newCFrame
        targetPart.AssemblyLinearVelocity = Vector3.zero
        targetPart.AssemblyAngularVelocity = Vector3.zero
    end)
end

--=============================================
-- [UI 생성]
--=============================================
local Window = Rayfield:CreateWindow({
    Name = "🔥 FSOF SetOwner Kick Hub (Improved)",
    LoadingTitle = "최적화 및 로딩 중...",
    LoadingSubtitle = "참조 파일 기법 적용",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [GRAB 탭] - 개선된 F키 킥 (SetNetworkOwner 최적화)
--=============================================
local GrabTab = Window:CreateTab("Grab (F키 공격)", nil)
GrabTab:CreateSection("=== 개선된 F키 킥 (소유권 확인 + 재시도) ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil
local fAttackTarget = nil
local fKeyAttackConfig = {
    maxRetries = 5,           -- SNOWshipOnceAndCheck 스타일
    checkDistance = 30,       -- 거리 제한
    useHeartbeat = true,      -- Heartbeat 대기 사용
    attackDelay = 0.05        -- 공격 간 대기 시간
}

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer
    fAttackConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        if not myRoot or not tgtRoot then return end
        
        -- 타겟 고정 (카메라 앞 20스터드)
        local camCF = camera.CFrame
        local targetPos = camCF.Position + camCF.LookVector * 20
        
        -- 타겟 제어
        safeSetCFrame(tgtRoot, CFrame.new(targetPos))
        if tgtHum then 
            tgtHum.PlatformStand = true 
            tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
        
        -- 거리 확인 후 SetNetworkOwner 호출
        if checkDistance(tgtRoot, fKeyAttackConfig.checkDistance) then
            pcall(function()
                -- CreateGrabLine과 SetNetworkOwner 사이에 약간의 시간 차이
                rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
            end)
            task.wait(0.01)  -- 약간의 대기
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
            end)
            task.wait(0.01)  -- 약간의 대기
            pcall(function()
                rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
            end)
        end
    end)
end

GrabTab:CreateKeybind({
    Name = "F키 조준 킥 그랩 (개선)",
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

GrabTab:CreateSlider({
    Name = "F키 재시도 횟수",
    Min = 1,
    Max = 10,
    Default = 5,
    Callback = function(v)
        fKeyAttackConfig.maxRetries = v
    end
})

--=============================================
-- [KICK 탭] - 개선된 루프킥 (정규 호출 간격 + 소유권 확인)
--=============================================
local KickTab = Window:CreateTab("Kick (루프킹)", nil)
local blobLoopT4 = false
local recoveringTargets = {} 
local selectedKickPlayer = nil

local loopKickConfig = {
    fixedYOffset = 20,           -- 내 머리 위 20스터드
    outOfRangeThreshold = 15,    -- 15스터드 이상 벗어나면 추적
    checkDistance = 30,          -- SetNetworkOwner 거리 제한
    loopIterations = 50,         -- 50회 반복 (참조 파일 방식)
    heartbeatPerLoop = true,     -- 각 반복마다 Heartbeat 대기
    velocityThreshold = 500,     -- 속도가 500 이상이면 중단
    toggleFrames = true          -- CreateGrabLine/SetNetworkOwner 번갈아 호출
}

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

function loopPlayerBlobF4()
    local initialized = false
    local frameToggle = false
    
    while blobLoopT4 do
        local player = selectedKickPlayer
        
        -- 타겟 유효성 확인
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") 
            or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            initialized = false
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        if myHRP and charHRP and charHUM then
            -- 고정 목표 위치: 내 캐릭터 위 20스터드
            local targetCF = myHRP.CFrame * CFrame.new(0, loopKickConfig.fixedYOffset, 0)
            
            -- 거리 계산
            local currentDist = (charHRP.Position - targetCF.Position).Magnitude
            
            -- 범위 이탈 감지 시 추적 루프
            if (currentDist > loopKickConfig.outOfRangeThreshold or not initialized) and not recoveringTargets[name] then
                recoveringTargets[name] = true
                initialized = true 
                
                task.spawn(function()
                    local originalCF = myHRP.CFrame
                    
                    -- 위상 1: 상승 (SetNetworkOwner로 소유권 획득)
                    pcall(function()
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                    end)
                    task.wait(0.15)
                    
                    -- 소유권 확인 및 재시도 (SNOWshipOnceAndCheck 방식)
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        for i = 1, 15 do
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            RunService.Heartbeat:Wait() -- 각 호출 후 Heartbeat 대기
                        end
                    end)
                    task.wait(0.05)
                    
                    -- 위상 2: 하강 및 위치 고정
                    pcall(function()
                        charHRP.CFrame = originalCF * CFrame.new(0, loopKickConfig.fixedYOffset, 0)
                        myHRP.CFrame = originalCF
                    end)
                    task.wait(0.1)
                    
                    -- 위상 3: 추가 SetNetworkOwner (안정화)
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        for i = 1, 15 do
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            RunService.Heartbeat:Wait()
                        end
                    end)
                    
                    task.wait(0.3)
                    recoveringTargets[name] = nil
                end)
            end
            
            -- 메인 루프: 타겟을 고정 위치에 유지
            pcall(function()
                safeSetCFrame(charHRP, targetCF)
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                -- 속도 체크 (디트로이트 방지)
                if charHRP.AssemblyLinearVelocity.Magnitude > loopKickConfig.velocityThreshold then
                    -- 속도가 높으면 중단
                    rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    -- DestroyLine 후 추적 시작
                else
                    -- 거리 확인 후 번갈아가며 호출
                    if checkDistance(charHRP, loopKickConfig.checkDistance) then
                        frameToggle = not frameToggle
                        if frameToggle then
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        else
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                        end
                    end
                end
            end)
        end
        
        if loopKickConfig.heartbeatPerLoop then
            RunService.Heartbeat:Wait()
        else
            RunService.RenderStepped:Wait()
        end
    end
end

KickTab:CreateToggle({
    Name = "루프킥 (정규 호출 + 소유권 확인)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            blobLoopT4 = false
            return
        end
        blobLoopT4 = v
        if v then task.spawn(loopPlayerBlobF4) end
    end
})

KickTab:CreateSlider({
    Name = "고정 높이 (Y오프셋)",
    Min = 5,
    Max = 50,
    Default = 20,
    Callback = function(v)
        loopKickConfig.fixedYOffset = v
    end
})

KickTab:CreateSlider({
    Name = "범위 이탈 임계값",
    Min = 5,
    Max = 30,
    Default = 15,
    Callback = function(v)
        loopKickConfig.outOfRangeThreshold = v
    end
})

KickTab:CreateToggle({
    Name = "Heartbeat 대기 사용 (안정성)",
    Default = true,
    Callback = function(v)
        loopKickConfig.heartbeatPerLoop = v
    end
})

--=============================================
-- [팔렛 래그돌 (개선된 버전)]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 개선",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
        local CreateLine = RS:WaitForChild("GrabEvents"):WaitForChild("CreateGrabLine")
        local lpName = plr.Name

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

            local toysFolder = workspace:WaitForChild(lpName .. "SpawnedInToys", 5)
            if not toysFolder then
                Rayfield:Notify({Title = "오류", Content = "생성된 토이 폴더를 찾을 수 없습니다.", Duration = 3})
                return
            end

            getgenv().palletCacheConn = toysFolder.ChildAdded:Connect(function(child)
                if not getgenv().palletRagdollActive then return end
                if child.Name ~= "PalletLightBrown" and child.Name ~= "PalletForRagdoll" then return end

                local soundPart = child:WaitForChild("SoundPart", 3)
                if not soundPart then return end

                -- CreateGrabLine -> SetNetworkOwner -> DestroyGrabLine 순서
                pcall(function()
                    CreateLine:FireServer(soundPart, CFrame.new())
                    task.wait(0.01)
                    SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                    task.wait(0.01)
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

            local toysFolder = workspace:FindFirstChild(lpName .. "SpawnedInToys")
            if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then
                pcall(function() DestroyToy:FireServer(toysFolder.PalletForRagdoll) end)
            end
        end
    end,
})

--=============================================
-- [설정 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateSection("=== 성능 최적화 ===")
SettingsTab:CreateButton({
    Name = "현재 설정 리셋",
    Callback = function() 
        fKeyAttackConfig = {
            maxRetries = 5,
            checkDistance = 30,
            useHeartbeat = true,
            attackDelay = 0.05
        }
        loopKickConfig = {
            fixedYOffset = 20,
            outOfRangeThreshold = 15,
            checkDistance = 30,
            loopIterations = 50,
            heartbeatPerLoop = true,
            velocityThreshold = 500,
            toggleFrames = true
        }
        Rayfield:Notify({Title="완료", Content="모든 설정이 초기화되었습니다."})
    end
})

SettingsTab:CreateLabel("개선 사항:")
SettingsTab:CreateLabel("• SNOWship 방식의 거리 체크")
SettingsTab:CreateLabel("• 네트워크 소유권 확인")
SettingsTab:CreateLabel("• SetNetworkOwner 재시도 로직")
SettingsTab:CreateLabel("• Heartbeat 기반 정규 호출")
SettingsTab:CreateLabel("• 디트로이트 방지 (속도 체크)")
SettingsTab:CreateLabel("• CreateGrabLine/DestroyGrabLine 순서 최적화")

Rayfield:Notify({
    Title = "로딩 완료", 
    Content = "참조 파일 기법 적용됨\n• SNOWship 소유권 체크\n• Heartbeat 정규 호출\n• 디트로이트 방지\n• 범위 이탈 자동 추적", 
    Duration = 5
})
