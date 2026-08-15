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
-- [GRAB 탭] - F키 킥 그랩 (SetNetworkOwner만 유지)
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
        
        -- 카메라 앞으로 던지기
        local camCF = camera.CFrame
        pcall(function() tgtRoot.CFrame = CFrame.new(camCF.Position + camCF.LookVector * 20) end)
        
        if (myRoot.Position - tgtRoot.Position).Magnitude <= 30 then
            -- 매 프레임 SetNetworkOwner만 호출 (그랩 라인 제거)
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
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
-- [KICK 탭] - 블롭맨 오너 킥 (x=3, y=10 고정, 회전 없음)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickConnection = nil
local kickActive = false

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
    if kickConnection then kickConnection:Disconnect() end
    kickActive = true
    
    kickConnection = RunService.Heartbeat:Connect(function()
        if not kickActive or not selectedKickPlayer then return end
        
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChild("Humanoid")
        
        if not (myChar and myHRP and tHRP and tHum and tHum.Health > 0) then return end
        
        -- 거리 확인
        local dist = (tHRP.Position - myHRP.Position).Magnitude
        
        -- ★ FETCH: 거리가 30 이상이면 자신을 대상 쪽으로 텔레포트
        if dist > 30 then
            pcall(function()
                myChar:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
            end)
            -- 텔레포트 후에도 SetNetworkOwner 호출
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
            end)
            return -- 다음 프레임에 다시 처리
        end
        
        -- ★ 고정 위치: 내 HRP 위치 기준 (3, 10, 0) - 회전 영향 없음
        local targetPos = myHRP.Position + Vector3.new(3, 10, 0)
        
        -- ★ AlignPosition / AlignOrientation 설정 (XOCU 방식) - 고정력 극대화
        if not tHRP:FindFirstChild("KickAlign") then
            -- 기존 BodyPosition 등 정리
            for _, v in pairs(tHRP:GetChildren()) do
                if v:IsA("BodyPosition") or v:IsA("BodyGyro") or v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
                    v:Destroy()
                end
            end
            
            -- Attachment on target HRP
            local att0 = Instance.new("Attachment", tHRP)
            att0.Name = "KickAtt0"
            
            -- Attachment on Terrain (고정 기준점)
            local att1 = Instance.new("Attachment", workspace.Terrain)
            att1.Name = "KickAtt1"
            
            -- AlignPosition
            local alignPos = Instance.new("AlignPosition")
            alignPos.Name = "KickAlign"
            alignPos.Attachment0 = att0
            alignPos.Attachment1 = att1
            alignPos.MaxForce = math.huge
            alignPos.Responsiveness = 300  -- 더 빠르게 반응
            alignPos.RigidityEnabled = true
            alignPos.Parent = tHRP
            
            -- AlignOrientation (회전 고정)
            local alignRot = Instance.new("AlignOrientation")
            alignRot.Name = "KickRot"
            alignRot.Attachment0 = att0
            alignRot.MaxTorque = math.huge
            alignRot.Responsiveness = 300
            alignRot.RigidityEnabled = true
            alignRot.Parent = tHRP
        end
        
        -- 목표 위치 갱신 (Attachment1의 WorldPosition)
        local align = tHRP:FindFirstChild("KickAlign")
        if align and align.Attachment1 then
            align.Attachment1.WorldPosition = targetPos
        end
        
        -- 회전 고정 (정면을 바라보게)
        local rot = tHRP:FindFirstChild("KickRot")
        if rot then
            rot.CFrame = CFrame.Angles(0, 0, 0)
        end
        
        -- 물리 제거
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        tHum.PlatformStand = true
        tHum:ChangeState(Enum.HumanoidStateType.Physics)
        
        -- ★ 매 프레임 SetNetworkOwner만 호출 (그랩 라인 제거)
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(tHRP, CFrame.lookAt(myHRP.Position, tHRP.Position))
        end)
    end)
end

local function stopKickLoop()
    kickActive = false
    if kickConnection then
        kickConnection:Disconnect()
        kickConnection = nil
    end
    -- 정리
    if selectedKickPlayer and selectedKickPlayer.Character then
        local tHRP = selectedKickPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then
            for _, v in pairs(tHRP:GetChildren()) do
                if v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
                    v:Destroy()
                end
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (x=3, y=10 고정, 회전 없음)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            stopKickLoop()
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

Rayfield:Notify({Title = "로딩 완료", Content = "x=3, y=10 고정 (회전 없음) + SetNetworkOwner만 매 프레임", Duration = 3})
