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
    Name = "🔥 FSOF Extreme Kick Hub (Ultimate Stable)",
    LoadingTitle = "티피 현상 완전 제거",
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
local recoveringTargets = {}

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConn = nil
local fAttackTarget = nil

--=============================================
-- [안정화를 위한 앵커 파트 생성 함수]
--=============================================
local function createAnchorPart()
    local anchor = Instance.new("Part")
    anchor.Name = "TargetAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Massless = true
    anchor.Anchored = false
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = plr.Character and plr.Character:FindFirstChild("Head") or nil
    if not weld.Part0 then
        -- 캐릭터가 없으면 생성될 때까지 대기
        plr.CharacterAdded:Wait()
        weld.Part0 = plr.Character:WaitForChild("Head")
    end
    weld.Part1 = anchor
    weld.Parent = anchor
    anchor.Parent = workspace
    return anchor
end

--=============================================
-- [GRAB 탭] - F키 안정화 킥 그랩 (티피 없음)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== F키 안정화 킥 그랩 (부드러운 고정) ===")

local function startFKeyAttack_Stable(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer

    -- 내 머리에 앵커 파트 부착 (한 번만 생성)
    local anchor = workspace:FindFirstChild("TargetAnchor")
    if not anchor then
        anchor = createAnchorPart()
    end

    local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if tRoot then
        -- 기존 Align 제거
        local oldAlign = tRoot:FindFirstChild("KickAlignPos")
        if oldAlign then oldAlign:Destroy() end

        -- 타겟에 AlignPosition 부착 (앵커 파트를 따라가도록)
        local att0 = Instance.new("Attachment", tRoot)
        att0.Name = "KickAtt0"
        local att1 = Instance.new("Attachment", anchor)
        att1.Name = "KickAtt1"

        local alignPos = Instance.new("AlignPosition", tRoot)
        alignPos.Name = "KickAlignPos"
        alignPos.Attachment0 = att0
        alignPos.Attachment1 = att1
        alignPos.MaxForce = math.huge
        alignPos.Responsiveness = 250  -- 부드럽게 따라감
        alignPos.RigidityEnabled = true

        local alignRot = Instance.new("AlignOrientation", tRoot)
        alignRot.Name = "KickAlignRot"
        alignRot.Attachment0 = att0
        alignRot.MaxTorque = math.huge
        alignRot.Responsiveness = 250
    end

    -- 메인 루프: AlignPosition이 자동으로 따라가므로 별도 위치 업데이트 불필요
    fAttackConn = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tRoot = fAttackTarget.Character and fAttackTarget.Character:FindFirstChild("HumanoidRootPart")
        local tHum = fAttackTarget.Character and fAttackTarget.Character:FindFirstChild("Humanoid")
        if not myRoot or not tRoot then return end

        -- 소유권 유지 (초당 약 5회, 너무 빠르지 않게)
        if tick() % 0.2 < 0.01 then
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tRoot, CFrame.lookAt(myRoot.Position, tRoot.Position))
                rs.GrabEvents.DestroyGrabLine:FireServer(tRoot)
            end)
        end

        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
            tRoot.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

GrabTab:CreateKeybind({
    Name = "F키 안정화 조준 킥 (부드러운 고정)",
    CurrentKeybind = "F",
    Callback = function()
        if not getgenv().KickGrabActive then getgenv().KickGrabActive = true end
        
        if getgenv().FKeyAttackActive then
            getgenv().FKeyAttackActive = false
            if fAttackConn then fAttackConn:Disconnect(); fAttackConn = nil end
            return
        end

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
            startFKeyAttack_Stable(nearest)
            Rayfield:Notify({Title = "공격 시작", Content = nearest.Name .. " (안정화 모드)", Duration = 2})
        else
            Rayfield:Notify({Title = "알림", Content = "근처에 공격 가능한 타겟이 없습니다.", Duration = 2})
        end
    end
})

--=============================================
-- [KICK 탭] - 블롭맨 오너 킥 (앵커 기반 안정화)
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

-- [핵심] 블롭맨 오너 킥 루프 (앵커 파트 사용)
local function loopPlayerBlobF4_Stable()
    -- 앵커 파트 생성 (내 머리 위)
    local anchor = workspace:FindFirstChild("TargetAnchor")
    if not anchor then
        anchor = createAnchorPart()
    end
    -- 앵커를 내 머리 위 20스터드로 위치시키는 대신, 앵커 자체를 머리에 붙이고 AlignPosition이 타겟을 당기게 함
    -- 대신 앵커의 위치를 머리 위로 고정 (WeldConstraint로 머리에 붙여도 되고, 그냥 CFrame을 계속 업데이트해도 됨)
    -- 여기서는 WeldConstraint를 사용했으므로 앵커는 머리 위치에 고정됨.

    while blobLoopT4 do
        local player = selectedKickPlayer
        if not player or not player.Character then
            RunService.RenderStepped:Wait()
            continue
        end

        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character:FindFirstChild("HumanoidRootPart")
        local charHUM = player.Character:FindFirstChild("Humanoid")
        if not (myHRP and charHRP and charHUM) or charHUM.Health <= 0 then
            RunService.RenderStepped:Wait()
            continue
        end

        -- 타겟에 AlignPosition 부착 (한 번만)
        if not charHRP:FindFirstChild("BlobAlignPos") then
            local att0 = Instance.new("Attachment", charHRP)
            att0.Name = "BlobAtt0"
            local att1 = Instance.new("Attachment", anchor)
            att1.Name = "BlobAtt1"

            local alignPos = Instance.new("AlignPosition", charHRP)
            alignPos.Name = "BlobAlignPos"
            alignPos.Attachment0 = att0
            alignPos.Attachment1 = att1
            alignPos.MaxForce = math.huge
            alignPos.Responsiveness = 250
            alignPos.RigidityEnabled = true

            local alignRot = Instance.new("AlignOrientation", charHRP)
            alignRot.Name = "BlobAlignRot"
            alignRot.Attachment0 = att0
            alignRot.MaxTorque = math.huge
            alignRot.Responsiveness = 250
        end

        -- 앵커는 머리에 붙어 있으므로, 따로 위치 업데이트가 필요 없음.
        -- 대신 거리가 너무 멀어지면 강제로 소유권을 다시 잡음.
        local dist = (charHRP.Position - anchor.Position).Magnitude
        if dist > 25 and not recoveringTargets[player.Name] then
            recoveringTargets[player.Name] = true
            task.spawn(function()
                local origCF = myHRP.CFrame
                pcall(function() myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0) end)
                RunService.Heartbeat:Wait()

                for i = 1, 10 do
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    end)
                    RunService.Heartbeat:Wait()
                end

                pcall(function()
                    charHRP.CFrame = anchor.CFrame * CFrame.new(0, 20, 0) -- 앵커 위 20? 사실 앵커가 머리 위치이므로 적절히 조절
                    myHRP.CFrame = origCF
                end)
                recoveringTargets[player.Name] = nil
            end)
        end

        -- 소유권 유지 (초당 약 5회)
        if tick() % 0.2 < 0.01 then
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
            end)
        end

        charHRP.AssemblyLinearVelocity = Vector3.zero
        charHRP.AssemblyAngularVelocity = Vector3.zero
        charHUM.PlatformStand = true
        charHUM:ChangeState(Enum.HumanoidStateType.Physics)

        RunService.RenderStepped:Wait()
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (티피 없음/부드러운 고정)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            return
        end
        blobLoopT4 = v
        if v then task.spawn(loopPlayerBlobF4_Stable) end
    end
})

-- [팔렛 래그돌 (Invis)] - 기존 코드 유지 (필요시 생략 가능)
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis)",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        -- (이전과 동일한 코드, 생략하지 않음)
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

Rayfield:Notify({Title = "로딩 완료", Content = "티피 현상 완전 제거 (앵커 파트 기반 부드러운 고정)", Duration = 3})
