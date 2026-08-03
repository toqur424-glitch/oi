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

-- =========================================================================
-- 🔥 [수정 적용된 핵심 루프] 완벽 고정, 강제 흡수, 프레임 교차 연타 엔진
-- =========================================================================
local function cleanupAligns(tHRP)
    if not tHRP then return end
    if tHRP:FindFirstChild("FixedAlignPos") then tHRP.FixedAlignPos:Destroy() end
    if tHRP:FindFirstChild("FixedAlignRot") then tHRP.FixedAlignRot:Destroy() end
    if tHRP:FindFirstChild("FixedAtt0") then tHRP.FixedAtt0:Destroy() end
end

function loopPlayerBlobF4()
    while blobLoopT4 do
        local player = selectedKickPlayer
        
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            if player and player.Character then
                cleanupAligns(player.Character:FindFirstChild("HumanoidRootPart"))
            end
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        if myHRP and charHRP and charHUM then
            local playerDist = (charHRP.Position - myHRP.Position).Magnitude
            
            -- [1. 상대 가져오기 (Fetch)] : 30스터드 이상 멀어지면 순간이동하여 권한 강제 탈취 후 오프셋(X=6, Y=15)으로 흡수
            if playerDist > 30 and not recoveringTargets[name] then
                recoveringTargets[name] = true
                
                local savedPos = myHRP.CFrame
                local fetchStart = tick()
                
                while (tick() - fetchStart < 0.25) and blobLoopT4 do
                    myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 0, 3)
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, charHRP.CFrame)
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    end)
                    charHUM.PlatformStand = true
                    task.wait(0.02)
                end
                
                myHRP.CFrame = savedPos
                charHRP.CFrame = savedPos * CFrame.new(6, 15, 0)
                task.wait(0.05)
                recoveringTargets[name] = nil
                continue
            end

            -- [2. 완벽 고정 (Rigid Lock)] : 단순히 CFrame만 반복 주입하면 튕기므로 AlignPosition 객체로 고정력 극대화
            if not charHRP:FindFirstChild("FixedAlignPos") then
                cleanupAligns(charHRP)
                
                local oldBp = charHRP:FindFirstChildOfClass("BodyPosition")
                if oldBp then oldBp:Destroy() end

                local att0 = Instance.new("Attachment")
                att0.Name = "FixedAtt0"
                att0.Parent = charHRP

                local att1 = Instance.new("Attachment")
                att1.Name = "FixedAtt1"
                att1.Parent = workspace.Terrain

                local targetAlignPos = Instance.new("AlignPosition")
                targetAlignPos.Name = "FixedAlignPos"
                targetAlignPos.Attachment0 = att0
                targetAlignPos.Attachment1 = att1
                targetAlignPos.MaxForce = math.huge
                targetAlignPos.Responsiveness = 200
                targetAlignPos.Parent = charHRP

                local targetAlignRot = Instance.new("AlignOrientation")
                targetAlignRot.Name = "FixedAlignRot"
                targetAlignRot.Attachment0 = att0
                targetAlignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
                targetAlignRot.CFrame = CFrame.new()
                targetAlignRot.MaxTorque = math.huge
                targetAlignRot.Responsiveness = 200
                targetAlignRot.Parent = charHRP
            end

            -- X=6, Y=15 오프셋 위치 갱신
            local alignPos = charHRP:FindFirstChild("FixedAlignPos")
            if alignPos and alignPos.Attachment1 then
                alignPos.Attachment1.WorldPosition = (myHRP.CFrame * CFrame.new(6, 15, 0)).Position
            end

            -- 물리 속도 초기화 및 무력화
            charHRP.AssemblyLinearVelocity = Vector3.zero
            charHRP.AssemblyAngularVelocity = Vector3.zero
            charHUM.PlatformStand = true
            charHUM:ChangeState(Enum.HumanoidStateType.Physics)

            -- [3. 셋오너 & 라인파괴 교차 연타 (Alternating Spam)] : 프레임을 분리하여 서버 딜레이로 씹히는 현상 방지
            pcall(function()
                rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                charHRP.AssemblyLinearVelocity = Vector3.new(0, -9999, 0)
            end)
            
            RunService.RenderStepped:Wait() -- 1 프레임 지연
            
            pcall(function()
                rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                charHRP.AssemblyLinearVelocity = Vector3.zero
            end)
        end
        RunService.RenderStepped:Wait()
    end

    -- 토글 끌 때 대상 청소
    if selectedKickPlayer and selectedKickPlayer.Character then
        cleanupAligns(selectedKickPlayer.Character:FindFirstChild("HumanoidRootPart"))
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
-- [림브스 오프셋 고정 기능]
--=============================================
local limbsOffsetFixActive = false
KickTab:CreateToggle({
    Name = "림브스 오프셋 고정 (팔다리 늘어남 방지)",
    Default = false,
    Callback = function(Value)
        limbsOffsetFixActive = Value
        if Value then
            task.spawn(function()
                while limbsOffsetFixActive do
                    if selectedKickPlayer and selectedKickPlayer.Character then
                        pcall(function()
                            for _, descendant in ipairs(selectedKickPlayer.Character:GetDescendants()) do
                                if descendant:IsA("Motor6D") then
                                    descendant.Transform = CFrame.new()
                                end
                            end
                        end)
                    end
                    RunService.RenderStepped:Wait()
                end
            end)
        end
    end
})

--=============================================
-- [나머지 필수 탭들 유지]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "X=6, Y=15 오프셋, 상대 흡수 및 고정 수정 완료", Duration = 3})
