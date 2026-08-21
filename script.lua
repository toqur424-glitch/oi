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
-- [GRAB 탭] - 극대화된 킥 그랩 (F키)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (속도/고정력 최상) ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil
local fAttackTarget = nil

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
        
        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        if tgtHum then tgtHum.PlatformStand = true end
        
        local camCF = camera.CFrame
        pcall(function() tgtRoot.CFrame = CFrame.new(camCF.Position + camCF.LookVector * 20) end)
        
        for i = 1, 4 do
            pcall(function()
                rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
            end)
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
-- [KICK 탭] - 단일 타겟 셋오너 & 디트로이트 교차 고정 및 범위 이탈 감지 룹티피
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local blobLoopT4 = false
local recoveringTargets = {} 

local selectedKickPlayer = nil

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
        
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            initialized = false
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        if myHRP and charHRP and charHUM then
            -- Y좌표 20 (내 머리 위 20)을 고정 목표 위치로 설정
            local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
            
            -- 내 몸이 아닌 '고정 목표 위치'와의 거리를 계산
            local currentDist = (charHRP.Position - targetCF.Position).Magnitude
            
            -- 고정 위치에서 15스터드 이상 벗어났을 때만 추적/룹티피 발동
            if (currentDist > 15 or not initialized) and not recoveringTargets[name] then
                recoveringTargets[name] = true
                initialized = true
                
                task.spawn(function()
                    local originalCF = myHRP.CFrame
                    pcall(function()
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                    end)
                    task.wait(0.15)
                    
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        for i = 1, 15 do
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        end
                    end)
                    task.wait(0.05)
                    
                    pcall(function()
                        charHRP.CFrame = originalCF * CFrame.new(0, 20, 0)
                        myHRP.CFrame = originalCF
                    end)
                    task.wait(0.1)
                    
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        for i = 1, 15 do
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        end
                    end)
                    
                    task.wait(0.3)
                    recoveringTargets[name] = nil
                end)
            end
            
            pcall(function()
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                frameToggle = not frameToggle
                if frameToggle then
                    rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                else
                    rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                    rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                end
            end)
        end
        RunService.RenderStepped:Wait()
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (범위 이탈 자동 추적)",
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

--=============================================
-- [VHSV6 + XOCU 통합 셋오너 킥 시스템 - 기존 탭에 통합]
--=============================================
KickTab:CreateSection("=== 셋오너 킥 (VHSV6 + XOCU 통합) ===")

getgenv().SmartKickActive = false
local smartKickConn = nil
local smartKickTarget = nil
local lastKickTime = 0
local kickCooldown = 0.3

-- 셋오너 킥 실행 함수 (VHSV6 + XOCU 메커니즘 완전 통합)
local function executeSmartKick(targetPlayer)
    local myChar = plr.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    if not myHRP then return end
    
    local tgtChar = targetPlayer.Character
    local tgtHRP = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
    local tgtHead = tgtChar and tgtChar:FindFirstChild("Head")
    local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
    
    if not tgtHRP or not tgtHead or not tgtHum then return end
    
    -- [1] 내 원래 위치 저장 (복귀용 - VHSV6 방식)
    local originalCF = myHRP.CFrame
    
    -- [2] 타겟에게 텔레포트 (접근 - XOCU 방식)
    myHRP.CFrame = tgtHRP.CFrame * CFrame.new(0, 2, 0)
    task.wait(0.1)
    
    -- [3] 셋오너 원격 이벤트 반복 발사 (VHSV6 방식 - 15회)
    for i = 1, 15 do
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(tgtHRP, CFrame.lookAt(myHRP.Position, tgtHRP.Position))
            rs.GrabEvents.CreateGrabLine:FireServer(tgtHRP, CFrame.new())
            rs.GrabEvents.DestroyGrabLine:FireServer(tgtHRP)
        end)
        task.wait()
    end
    
    -- [4] 내 원래 위치로 즉시 복귀 (VHSV6 핵심)
    myHRP.CFrame = originalCF
    myHRP.AssemblyLinearVelocity = Vector3.zero
    myHRP.AssemblyAngularVelocity = Vector3.zero
    
    -- [5] 타겟을 내 원래 위치 위로 고정 이동 (XOCU 방식 - 20스터드 위)
    local lockPos = originalCF * CFrame.new(0, 20, 0)
    
    task.spawn(function()
        -- BodyPosition 생성 (고정력 최대)
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.D = 100
        bp.P = 50000
        bp.Position = lockPos.Position
        bp.Parent = tgtHRP
        
        -- BodyGyro 생성
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.D = 100
        bg.CFrame = lockPos
        bg.Parent = tgtHRP
        
        -- 타겟을 강제로 내 원래 위치 위로 이동
        pcall(function()
            tgtHRP.CFrame = lockPos
            tgtHRP.AssemblyLinearVelocity = Vector3.zero
            tgtHRP.AssemblyAngularVelocity = Vector3.zero
            tgtHum.PlatformStand = true
            tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
        
        -- 3초 동안 유지 (셋오너 지속 확인 및 갱신)
        local startTime = tick()
        while tick() - startTime < 3 do
            -- 타겟이 다시 이동하려고 하면 재고정
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtHRP, CFrame.lookAt(myHRP.Position, tgtHRP.Position))
                tgtHRP.CFrame = lockPos
                tgtHRP.AssemblyLinearVelocity = Vector3.zero
                tgtHRP.AssemblyAngularVelocity = Vector3.zero
                
                -- BodyPosition 갱신
                local bp2 = tgtHRP:FindFirstChild("BodyPosition")
                if bp2 then bp2.Position = lockPos.Position end
            end)
            task.wait(0.1)
        end
        
        -- 정리
        if bp and bp.Parent then bp:Destroy() end
        if bg and bg.Parent then bg:Destroy() end
    end)
end

-- G키 조준 셋오너 킥 (기존 F키와 별개로 동작)
KickTab:CreateKeybind({
    Name = "G키 셋오너 킥 (조준한 유저)",
    CurrentKeybind = "G",
    Callback = function()
        -- 쿨다운 체크 (핑 터짐 방지)
        if tick() - lastKickTime < kickCooldown then return end
        lastKickTime = tick()
        
        local target = nil
        
        -- 카메라 정면에서 가장 가까운 플레이어 찾기
        local camPos = camera.CFrame.Position
        local camLook = camera.CFrame.LookVector
        local closestDist = math.huge
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = p.Character.HumanoidRootPart
                local dist = (hrp.Position - camPos).Magnitude
                local direction = (hrp.Position - camPos).Unit
                
                -- 카메라 방향과 일치하는지 확인 (도트 프로덕트)
                local dot = camLook:Dot(direction)
                if dot > 0.95 and dist < closestDist then  -- 정면 5도 이내
                    closestDist = dist
                    target = p
                end
            end
        end
        
        if target then
            executeSmartKick(target)
            Rayfield:Notify({Title = "셋오너 킥", Content = target.Name .. "님에게 셋오너 킥 실행!", Duration = 2})
        else
            Rayfield:Notify({Title = "알림", Content = "조준한 유저를 찾을 수 없습니다.", Duration = 2})
        end
    end
})

-- 선택한 유저 지속 셋오너 킥
KickTab:CreateToggle({
    Name = "선택한 유저 지속 셋오너 킥 (자동 복귀 포함)",
    Callback = function(v)
        getgenv().SmartKickActive = v
        
        if v then
            if not selectedKickPlayer then
                Rayfield:Notify({Title = "알림", Content = "먼저 타겟을 선택해주세요!", Duration = 3})
                return
            end
            
            smartKickTarget = selectedKickPlayer
            
            if smartKickConn then smartKickConn:Disconnect() end
            smartKickConn = RunService.Heartbeat:Connect(function()
                if not getgenv().SmartKickActive or not smartKickTarget then return end
                
                -- 쿨다운 체크 (핑 터짐 방지)
                if tick() - lastKickTime < kickCooldown then return end
                lastKickTime = tick()
                
                executeSmartKick(smartKickTarget)
                task.wait(0.5)  -- 0.5초 간격으로 반복
            end)
            
            Rayfield:Notify({Title = "지속 킥 시작", Content = smartKickTarget.Name .. "님에게 지속 셋오너 킥 시작!", Duration = 2})
        else
            if smartKickConn then
                smartKickConn:Disconnect()
                smartKickConn = nil
            end
            Rayfield:Notify({Title = "지속 킥 종료", Content = "셋오너 킥이 중지되었습니다.", Duration = 2})
        end
    end
})

--=============================================
-- [새로운 Pallet Ragdoll (Invis) 통합]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis)",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
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

            local toysFolder = workspace:FindFirstChild(lpName .. "SpawnedInToys")
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

Rayfield:Notify({Title = "로딩 완료", Content = "셋오너 킥 통합 완료 (핑 최적화 적용)", Duration = 3})
