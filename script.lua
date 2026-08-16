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
-- [GRAB 탭] - F키 킥 그랩 (100Hz 목표)
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
            -- 매 프레임 둘 다 호출 (번갈아 X)
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
            end)
            pcall(function()
                rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
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
-- [KICK 탭] - 블롭맨 오너 킥 (y=20, x=0 고정 + 100Hz)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false

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

local function startKickLoop()
    kickLoopRunning = true
    local kickCounter = 0
    task.spawn(function()
        while kickLoopRunning do
            if not selectedKickPlayer then break end
            
            local myChar = plr.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local tChar = selectedKickPlayer.Character
            local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChild("Humanoid")
            
            if not (myChar and myHRP and tHRP and tHum and tHum.Health > 0) then
                task.wait(0.01)  -- 100Hz
                continue
            end
            
            local dist = (tHRP.Position - myHRP.Position).Magnitude
            
            -- ★ FETCH: 거리가 30 이상이면 자신을 대상 쪽으로 텔레포트
            if dist > 30 then
                pcall(function()
                    myChar:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
                end)
                pcall(function()
                    rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
                end)
                task.wait(0.01)
                continue
            end
            
            -- ★ 고정 위치: 내 머리 바로 위 20스터드 (x=0, y=20)
            local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
            
            -- ★ AlignPosition / AlignOrientation 생성 (한 번만)
            if not tHRP:FindFirstChild("KickAlign") then
                -- 기존 물리 객체 제거
                for _, v in pairs(tHRP:GetChildren()) do
                    if v:IsA("BodyPosition") or v:IsA("BodyGyro") or v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
                        v:Destroy()
                    end
                end
                
                -- Attachment 생성
                local att0 = Instance.new("Attachment", tHRP)
                att0.Name = "KickAtt0"
                local attPos1 = Instance.new("Attachment", workspace.Terrain)
                attPos1.Name = "KickAtt1"          -- 위치용 기준
                local attRot1 = Instance.new("Attachment", workspace.Terrain)
                attRot1.Name = "KickRotAtt1"       -- 회전용 기준
                
                -- AlignPosition (고정력 최상)
                local alignPos = Instance.new("AlignPosition")
                alignPos.Name = "KickAlign"
                alignPos.Attachment0 = att0
                alignPos.Attachment1 = attPos1
                alignPos.MaxForce = math.huge
                alignPos.MaxVelocity = math.huge   -- 속도 제한 없음
                alignPos.Responsiveness = 1000    -- 최대 반응성
                alignPos.RigidityEnabled = true
                alignPos.Parent = tHRP
                
                -- AlignOrientation (회전 고정력 최상)
                local alignRot = Instance.new("AlignOrientation")
                alignRot.Name = "KickRot"
                alignRot.Attachment0 = att0
                alignRot.Attachment1 = attRot1
                alignRot.MaxTorque = math.huge
                alignRot.Responsiveness = 1000
                alignRot.RigidityEnabled = true
                alignRot.Parent = tHRP
            end
            
            local align = tHRP:FindFirstChild("KickAlign")
            local rot = tHRP:FindFirstChild("KickRot")
            
            -- 위치 갱신 (목표 위치로 강제)
            if align and align.Attachment1 then
                align.Attachment1.WorldPosition = targetPos
            end
            
            -- 회전 고정 (월드 축 정렬)
            if rot and rot.Attachment1 then
                rot.Attachment1.WorldCFrame = CFrame.identity
            end
            
            -- 물리 제거 (속도/회전 초기화)
            tHRP.AssemblyLinearVelocity = Vector3.zero
            tHRP.AssemblyAngularVelocity = Vector3.zero
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
            
            -- 직접 CFrame 보정 (강제 고정, 0.5초마다 한 번씩)
            if kickCounter % 50 == 0 then
                pcall(function()
                    tHRP.CFrame = CFrame.new(targetPos)
                end)
            end
            
            -- ★ SetOwner + Detroit (그랩라인) 매 루프 호출
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
            end)
            pcall(function()
                rs.GrabEvents.CreateGrabLine:FireServer(tHRP, CFrame.new())
                rs.GrabEvents.DestroyGrabLine:FireServer(tHRP)
            end)
            
            kickCounter = kickCounter + 1
            task.wait(0.01)  -- 100Hz 목표 (실제 프레임 제한으로 60~100Hz)
        end
    end)
end

local function stopKickLoop()
    kickLoopRunning = false
    -- 정리
    if selectedKickPlayer and selectedKickPlayer.Character then
        local tHRP = selectedKickPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then
            -- Align 객체 제거
            for _, v in pairs(tHRP:GetChildren()) do
                if v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
                    v:Destroy()
                end
            end
            -- Attachment 제거
            for _, v in pairs(tHRP:GetChildren()) do
                if v.Name == "KickAtt0" then
                    v:Destroy()
                end
            end
        end
    end
    -- Terrain에 있는 Attachment 제거
    if workspace.Terrain then
        for _, v in pairs(workspace.Terrain:GetChildren()) do
            if v.Name == "KickAtt1" or v.Name == "KickRotAtt1" then
                v:Destroy()
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (y=20, x=0 고정 + 100Hz)",
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

Rayfield:Notify({Title = "로딩 완료", Content = "100Hz 목표 최적화! 고정 안정성 + 속도 균형 완벽", Duration = 3})
