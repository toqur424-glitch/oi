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
    Name = "🔥 FSOF Extreme Kick Hub (Ultimate)",
    LoadingTitle = "최적화 및 로딩 중...",
    LoadingSubtitle = "by Extreme Script",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [GRAB 탭] - F키 조준 킥 그랩
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (매 프레임 스팸) ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil
local fAttackTarget = nil
local fAttackBodyPos = nil
local fAttackBodyGyro = nil

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer

    -- 타겟에 BodyPosition / BodyGyro 부착 (물리적 고정)
    local tRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if tRoot then
        fAttackBodyPos = Instance.new("BodyPosition", tRoot)
        fAttackBodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        fAttackBodyPos.D = 500
        fAttackBodyPos.P = 20000

        fAttackBodyGyro = Instance.new("BodyGyro", tRoot)
        fAttackBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        fAttackBodyGyro.D = 500
        fAttackBodyGyro.P = 20000
    end

    fAttackConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        if not myRoot or not tgtRoot then return end

        -- 속도 초기화 및 타겟을 카메라 앞 20스터드로 고정
        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        tgtRoot.AssemblyAngularVelocity = Vector3.zero
        if tgtHum then
            tgtHum.PlatformStand = true
            tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
            tgtHum.WalkSpeed = 0
            tgtHum.JumpPower = 0
        end

        local camCF = camera.CFrame
        local targetPos = camCF.Position + camCF.LookVector * 20
        tgtRoot.CFrame = CFrame.new(targetPos)

        -- BodyPosition/gyro 업데이트
        if fAttackBodyPos and fAttackBodyPos.Parent then
            fAttackBodyPos.Position = targetPos
        end
        if fAttackBodyGyro and fAttackBodyGyro.Parent then
            fAttackBodyGyro.CFrame = CFrame.lookAt(targetPos, myRoot.Position)
        end

        -- 거리 내에서만 소유권 스팸 (서버 과부하 방지)
        if (myRoot.Position - tgtRoot.Position).Magnitude <= 30 then
            for i = 1, 10 do
                pcall(function()
                    rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                    rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                    rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
                end)
            end
        else
            -- 멀어지면 내가 타겟 쪽으로 순간이동
            pcall(function()
                myRoot.CFrame = tgtRoot.CFrame * CFrame.new(0, 0, -3)
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
            if fAttackBodyPos then fAttackBodyPos:Destroy() end
            if fAttackBodyGyro then fAttackBodyGyro:Destroy() end
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
-- [KICK 탭] - 블롭맨 오너 킥 (낙하 방지)
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

local function loopPlayerBlobF4()
    local initialized = false
    local frameToggle = false
    local bodyPos = nil
    local bodyGyro = nil
    
    while blobLoopT4 do
        local player = selectedKickPlayer
        
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            initialized = false
            if bodyPos then bodyPos:Destroy() bodyPos = nil end
            if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        if myHRP and charHRP and charHUM then
            -- 타겟에 BodyPosition/gyro 부착
            if not bodyPos or bodyPos.Parent ~= charHRP then
                if bodyPos then bodyPos:Destroy() end
                if bodyGyro then bodyGyro:Destroy() end
                bodyPos = Instance.new("BodyPosition", charHRP)
                bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyPos.D = 500
                bodyPos.P = 20000

                bodyGyro = Instance.new("BodyGyro", charHRP)
                bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bodyGyro.D = 500
                bodyGyro.P = 20000
            end

            -- 고정 위치 (내 머리 위 20스터드)
            local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
            local currentDist = (charHRP.Position - targetCF.Position).Magnitude
            
            -- 15스터드 이상 벗어나면 재소유 + 텔레포트
            if (currentDist > 15 or not initialized) and not recoveringTargets[name] then
                recoveringTargets[name] = true
                initialized = true 
                
                task.spawn(function()
                    local originalCF = myHRP.CFrame
                    pcall(function()
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                    end)
                    RunService.RenderStepped:Wait()

                    -- 소유권 스팸
                    for i = 1, 30 do
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                        end)
                        RunService.RenderStepped:Wait()
                    end
                    
                    pcall(function()
                        charHRP.CFrame = originalCF * CFrame.new(0, 20, 0)
                        myHRP.CFrame = originalCF
                    end)
                    RunService.RenderStepped:Wait()
                    
                    for i = 1, 30 do
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                        end)
                        RunService.RenderStepped:Wait()
                    end
                    
                    task.wait(0.1)
                    recoveringTargets[name] = nil
                end)
            end
            
            -- 매 프레임 강제 위치 고정 + 속도 초기화
            pcall(function()
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                charHUM.WalkSpeed = 0
                charHUM.JumpPower = 0

                if bodyPos then bodyPos.Position = targetCF.Position end
                if bodyGyro then bodyGyro.CFrame = targetCF end

                -- 거리 30 이하에서만 소유권 교차 발사
                if (myHRP.Position - charHRP.Position).Magnitude <= 30 then
                    frameToggle = not frameToggle
                    if frameToggle then
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                    else
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    end
                end
            end)
        end
        RunService.RenderStepped:Wait()
    end

    if bodyPos then bodyPos:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
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
-- [판자 레그돌 (Invis) - 충돌 방지 + 속도 조절]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 강제 레그돌",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = ReplicatedStorage
        local RunService = game:GetService("RunService")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
        local RagdollRemote = RS:WaitForChild("CharacterEvents"):WaitForChild("RagdollRemote")
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

                -- 소유권 강제 획득
                for i = 1, 5 do
                    pcall(function()
                        SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                        DestroyLine:FireServer(soundPart)
                    end)
                    RunService.RenderStepped:Wait()
                end

                local partOwner = soundPart:WaitForChild("PartOwner", 1)
                if partOwner and partOwner.Value == lpName then
                    -- 판자 투명화 및 충돌 해제 (CanCollide = false!)
                    for _, v in pairs(child:GetChildren()) do
                        if v:IsA("BasePart") then
                            v.Transparency = 1 
                            v.CanQuery = false
                            v.CanCollide = false  -- 충돌 방지 → 양쪽 날아감 문제 해결
                        end
                    end

                    child.Name = "PalletForRagdoll"
                    getgenv().PalletForRagdoll = child

                    local strikePhase = false
                    local lastRagdollFire = 0

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
                                -- 판자를 타겟 위치에 배치하고 속도로 충격 (충돌 없음)
                                strikePhase = not strikePhase
                                if strikePhase then
                                    soundPart.CFrame = tRoot.CFrame
                                    soundPart.AssemblyLinearVelocity = Vector3.new(0, -50000, 0)  -- 속도 감소
                                else
                                    soundPart.CFrame = tRoot.CFrame
                                    soundPart.AssemblyLinearVelocity = Vector3.new(0, 50000, 0)
                                end

                                -- 0.05초마다 RagdollRemote 추가 발사 (레그돌 강제)
                                if tick() - lastRagdollFire > 0.05 then
                                    pcall(function()
                                        RagdollRemote:FireServer(tRoot, 1)
                                    end)
                                    lastRagdollFire = tick()
                                end
                            else
                                -- 이미 레그돌이면 판자를 하늘로 치워서 렉 감소
                                soundPart.CFrame = CFrame.new(0, 9e9, 0)
                                soundPart.AssemblyLinearVelocity = Vector3.zero
                            end
                        else
                            soundPart.CFrame = CFrame.new(0, 9e9, 0)
                            soundPart.AssemblyLinearVelocity = Vector3.zero
                        end
                    end)

                    -- 판자 파괴 시 재생성
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

            -- 판자 생성 함수
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
-- [기타 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "셋오너 킥/판자 레그돌 최적화 완료 (충돌 및 낙하 수정)", Duration = 3})
