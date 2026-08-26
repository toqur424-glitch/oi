--=============================================
-- [초기 로드 및 게임 체크]
--=============================================
local Rayfield = nil

local success, result = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if success then
    Rayfield = result
else
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    player:WaitForChild("PlayerGui")
    local notify = Instance.new("ScreenGui")
    notify.Name = "ErrorNotify"
    notify.Parent = player.PlayerGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 100)
    frame.Position = UDim2.new(0.5, 0, 0.3, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.Parent = notify
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = "Rayfield 로드 실패\n인터넷 연결 및 URL 확인 후 다시 시도하세요."
    label.TextColor3 = Color3.fromRGB(255, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = frame
    return
end

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

-- Destroy 이벤트 자동 감지 (없으면 DestroyGrabLine 사용)
local DestroyEvent = rs:FindFirstChild("Destroy") or (rs:FindFirstChild("GrabEvents") and rs.GrabEvents:FindFirstChild("DestroyGrabLine"))

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
                if DestroyEvent then DestroyEvent:FireServer(tgtRoot) end
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
-- [KICK 탭] - 통합 셋오너 킥 (BodyPosition 고정)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local blobLoopT4 = false
local recoveringTargets = {} 
local selectedKickPlayer = nil

-- 타겟 입력
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
end)

-- 통합 셋오너 킥 루프 (350Hz, BodyPosition 고정 + PCld 이동)
function loopPlayerBlobF4()
    local initialized = false
    local nextTime = 0
    local interval = 1/350
    local bp = nil  -- BodyPosition (고정용)

    while blobLoopT4 do
        local player = selectedKickPlayer
        
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            initialized = false
            if bp then bp:Destroy() bp = nil end
            task.wait(interval)
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        if myHRP and charHRP and charHUM then
            local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
            local currentDist = (charHRP.Position - targetCF.Position).Magnitude
            
            -- 최초 실행 또는 거리 벗어남 시 상대 PCld 위치로 이동 후 복귀
            if (not initialized or currentDist > 15) and not recoveringTargets[name] then
                recoveringTargets[name] = true
                initialized = true
                
                task.spawn(function()
                    -- 1. 내 원래 위치 저장
                    local originalCF = myHRP.CFrame
                    
                    -- 2. 상대방 PCld 파트 찾기 (없으면 캐릭터 위치로 폴백)
                    local pcldPart = nil
                    if player:FindFirstChild("PCld") then
                        pcldPart = player.PCld
                    elseif player.Character:FindFirstChild("PCld") then
                        pcldPart = player.Character.PCld
                    end
                    
                    if pcldPart then
                        pcall(function()
                            myHRP.CFrame = pcldPart.CFrame * CFrame.new(0, 2, 0)
                        end)
                    else
                        pcall(function()
                            myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                        end)
                    end
                    task.wait(0.15)
                    
                    -- 3. 소유권 뺏기: 셋오너 1회 + Destroy 3회
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        if DestroyEvent then
                            for i = 1, 3 do
                                DestroyEvent:FireServer(charHRP)
                            end
                        end
                    end)
                    task.wait(0.05)
                    
                    -- 4. BodyPosition 생성 (math.huge) 및 목표 좌표 설정
                    if bp then bp:Destroy() end
                    bp = Instance.new("BodyPosition")
                    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bp.D = 200
                    bp.P = 50000
                    bp.Parent = charHRP
                    bp.Position = targetCF.Position  -- 내 머리 위 Y+20
                    
                    -- 5. 내 원래 위치 복귀
                    pcall(function()
                        myHRP.CFrame = originalCF
                    end)
                    
                    task.wait(0.3)
                    recoveringTargets[name] = nil
                end)
            end
            
            -- 매 프레임 BodyPosition 유지 및 목표 좌표 업데이트
            if not bp or not bp.Parent then
                bp = Instance.new("BodyPosition")
                bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bp.D = 200
                bp.P = 50000
                bp.Parent = charHRP
            end
            bp.Position = targetCF.Position
            
            -- 셋오너 및 고정 (원격 이벤트 + CFrame 직접 설정)
            pcall(function()
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                -- 셋오너 1회
                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                
                -- Destroy 3회
                if DestroyEvent then
                    for i = 1, 3 do
                        pcall(function()
                            DestroyEvent:FireServer(charHRP)
                        end)
                    end
                end
            end)
        end
        
        -- 정확한 350Hz 유지를 위한 시간 보정
        nextTime = nextTime + interval
        local sleepTime = nextTime - tick()
        if sleepTime > 0 then
            task.wait(sleepTime)
        else
            nextTime = tick()
        end
    end
end

-- 통합 셋오너 킥 토글
KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (PCld 이동)",
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
-- [Pallet Ragdoll (Invis) 통합]
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
        local DestroyEvent = RS:FindFirstChild("Destroy") or (RS:FindFirstChild("GrabEvents") and RS.GrabEvents:FindFirstChild("DestroyGrabLine"))
        if not DestroyEvent then
            Rayfield:Notify({Title = "오류", Content = "Destroy 이벤트를 찾을 수 없습니다.", Duration = 3})
            return
        end
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
                    DestroyEvent:FireServer(soundPart)
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

Rayfield:Notify({Title = "로딩 완료", Content = "BodyPosition 고정 + PCld 이동 방식 완료", Duration = 3})
