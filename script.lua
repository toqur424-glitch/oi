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
    LoadingTitle = "디트로이트 및 고정력 최적화 완료",
    LoadingSubtitle = "by Extreme Script",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [전역 변수 및 상태]
--=============================================
local selectedKickPlayer = nil
local blobLoopT4 = false
local recoveringTargets = {} -- 블롭맨 루프 중복 실행 방지

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConn = nil
local fAttackTarget = nil

--=============================================
-- [GRAB 탭] - F키 극대화 조준 킥 그랩
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== F키 극대화 킥 그랩 (고정력/스팸 최상) ===")

-- F키 실행 함수 (AlignPosition + AlignOrientation으로 완전 고정)
local function startFKeyAttack_Enhanced(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer

    local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if tRoot then
        -- 기존 Align 제거
        local oldAlign = tRoot:FindFirstChild("KickAlignPos")
        if oldAlign then oldAlign:Destroy() end
        local oldAttach = tRoot:FindFirstChild("KickAtt0")
        if oldAttach then oldAttach:Destroy() end

        -- 물리적 강제 고정 장치 부착
        local att0 = Instance.new("Attachment", tRoot)
        att0.Name = "KickAtt0"
        local att1 = Instance.new("Attachment", workspace.Terrain)
        att1.Name = "KickAtt1"

        local alignPos = Instance.new("AlignPosition", tRoot)
        alignPos.Name = "KickAlignPos"
        alignPos.Attachment0 = att0
        alignPos.Attachment1 = att1
        alignPos.MaxForce = math.huge
        alignPos.Responsiveness = 500 -- 고정력 극대화
        alignPos.RigidityEnabled = true

        local alignRot = Instance.new("AlignOrientation", tRoot)
        alignRot.Name = "KickAlignRot"
        alignRot.Attachment0 = att0
        alignRot.MaxTorque = math.huge
        alignRot.Responsiveness = 500
    end

    -- 메인 루프: 매 프레임 셋오너 스팸 및 위치 강제 고정
    fAttackConn = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tChar = fAttackTarget.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChild("Humanoid")
        if not myRoot or not tRoot then return end

        -- 타겟 위치를 카메라 앞 20스터드로 설정 (AlignPosition이 강제로 당김)
        local camCF = camera.CFrame
        local targetPos = camCF.Position + camCF.LookVector * 20
        if alignPos and alignPos.Attachment1 then
            alignPos.Attachment1.WorldPosition = targetPos
        end

        -- 셋오너 + 그랩라인 스팸 (매 프레임 2회씩 번갈아 호출 -> 디트로이트 유발)
        pcall(function()
            rs.GrabEvents.CreateGrabLine:FireServer(tRoot, CFrame.new())
            rs.GrabEvents.SetNetworkOwner:FireServer(tRoot, CFrame.lookAt(myRoot.Position, tRoot.Position))
            rs.GrabEvents.DestroyGrabLine:FireServer(tRoot)

            -- 추가로 한 번 더 쏴서 소유권 완전 장악
            rs.GrabEvents.SetNetworkOwner:FireServer(tRoot, CFrame.lookAt(myRoot.Position, tRoot.Position))
            rs.GrabEvents.DestroyGrabLine:FireServer(tRoot)
        end)

        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)
end

GrabTab:CreateKeybind({
    Name = "F키 조준 킥 그랩 (고속 스팸/고정)",
    CurrentKeybind = "F",
    Callback = function()
        if not getgenv().KickGrabActive then getgenv().KickGrabActive = true end
        
        -- 종료 로직
        if getgenv().FKeyAttackActive then
            getgenv().FKeyAttackActive = false
            if fAttackConn then fAttackConn:Disconnect(); fAttackConn = nil end
            return
        end

        -- 가장 가까운 적 탐색
        local nearest = nil
        local minDist = math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = p.Character.HumanoidRootPart
                local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local d = (myRoot.Position - hrp.Position).Magnitude
                    if d < minDist then
                        minDist = d
                        nearest = p
                    end
                end
            end
        end

        if nearest then
            startFKeyAttack_Enhanced(nearest)
            Rayfield:Notify({Title = "공격 시작", Content = nearest.Name .. " (F키 스팸 활성화)", Duration = 2})
        else
            Rayfield:Notify({Title = "알림", Content = "근처에 공격 가능한 타겟이 없습니다.", Duration = 2})
        end
    end
})

--=============================================
-- [KICK 탭] - 블롭맨 오너 킥 & 팔렛 래그돌
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨/팔렛)", nil)

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
})

-- [핵심] 블롭맨 오너 킥 루프 (디트로이트 & 고정력 극대화 버전)
local function loopPlayerBlobF4_Enhanced()
    while blobLoopT4 do
        local player = selectedKickPlayer
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        if not (myHRP and charHRP and charHUM) then
            RunService.RenderStepped:Wait()
            continue
        end

        -- 고정 목표 위치 (내 머리 위 20스터드)
        local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
        local dist = (charHRP.Position - targetCF.Position).Magnitude

        -- [스팸 트리거] 타겟이 고정 위치에서 15스터드 이상 벗어나면 강제로 셋오너 스팸 실행
        if (dist > 15 or not recoveringTargets[name]) and not recoveringTargets[name] then
            recoveringTargets[name] = true
            task.spawn(function()
                local origCF = myHRP.CFrame
                -- 1) 타겟 근처로 순간이동하여 그랩 시작
                pcall(function() myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0) end)
                RunService.Heartbeat:Wait()

                -- 2) 디트로이트 유발용 셋오너 15회 연속 스팸
                for i = 1, 15 do
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    end)
                    RunService.Heartbeat:Wait()
                end

                -- 3) 타겟을 고정 위치로 이동, 나는 원래 자리로 복귀
                pcall(function()
                    charHRP.CFrame = origCF * CFrame.new(0, 20, 0)
                    myHRP.CFrame = origCF
                end)
                RunService.Heartbeat:Wait()

                -- 4) 다시 한 번 셋오너 스팸 (소유권 재확보)
                for i = 1, 15 do
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    end)
                    RunService.Heartbeat:Wait()
                end

                recoveringTargets[name] = nil
            end)
        end

        -- [메인 루프] 매 프레임 타겟을 강제 고정하고 셋오너를 번갈아 호출
        pcall(function()
            charHRP.CFrame = targetCF
            charHRP.AssemblyLinearVelocity = Vector3.zero
            charHRP.AssemblyAngularVelocity = Vector3.zero
            charHUM.PlatformStand = true
            charHUM:ChangeState(Enum.HumanoidStateType.Physics)

            -- 거리 내에 있을 때만 번갈아 스팸 (Detroit 유지)
            if (myHRP.Position - charHRP.Position).Magnitude <= 30 then
                if (tick() % 0.1 < 0.05) then
                    rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                else
                    rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                    rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                end
            end
        end)

        RunService.RenderStepped:Wait() -- 60FPS로 루프
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (디트로이트/고정력 극대화)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            return
        end
        blobLoopT4 = v
        if v then task.spawn(loopPlayerBlobF4_Enhanced) end
    end
})

-- [통합] 팔렛 래그돌 (Invis)
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis)",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = ReplicatedStorage
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
-- [Settings 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "셋오너 디트로이트 및 고정력 최적화 반영됨", Duration = 3})
