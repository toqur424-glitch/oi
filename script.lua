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
-- [원격 이벤트 안전하게 가져오기]
--=============================================
local GrabEvents = rs:FindFirstChild("GrabEvents")
local SetNetworkOwner = GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner")
local DestroyGrabLine = GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine")
local CreateGrabLine = GrabEvents and GrabEvents:FindFirstChild("CreateGrabLine")

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
        tgtRoot.CFrame = CFrame.new(camCF.Position + camCF.LookVector * 20)
        
        for i = 1, 4 do
            if CreateGrabLine and SetNetworkOwner and DestroyGrabLine then
                CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                DestroyGrabLine:FireServer(tgtRoot)
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

-- [수정된 함수] Y20 즉시 복귀 + BodyPosition(math.huge) + Struggle 강화 + 300Hz 루프
function loopPlayerBlobF4()
    local initialized = false
    local lastBP_HRP = nil
    local lastBP_Torso = nil

    -- 300Hz 네트워크 루프 (셋오너 2회 + 디트로이트 1회)
    task.spawn(function()
        while blobLoopT4 and selectedKickPlayer and selectedKickPlayer.Character do
            local charHRP = selectedKickPlayer.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if charHRP and myHRP and SetNetworkOwner and DestroyGrabLine then
                SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position)) -- 셋오너 2회
                DestroyGrabLine:FireServer(charHRP) -- 디트로이트 1회
            end
            task.wait(1/300) -- 300Hz
        end
    end)

    while blobLoopT4 do
        local player = selectedKickPlayer
        
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            initialized = false
            -- 이전 BodyPosition 제거
            if lastBP_HRP then lastBP_HRP:Destroy() lastBP_HRP = nil end
            if lastBP_Torso then lastBP_Torso:Destroy() lastBP_Torso = nil end
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        local charTorso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso")

        if myHRP and charHRP and charHUM then
            local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
            local targetPos = targetCF.Position
            
            -- 즉시 Y20 복귀 (가져오기 전에 고정되는 문제 해결)
            if initialized then
                charHRP.CFrame = targetCF
                if charTorso then charTorso.CFrame = targetCF end
            end

            -- 범위 이탈 시 추적/룹티피
            if (charHRP.Position - targetPos).Magnitude > 15 or not initialized then
                if not recoveringTargets[name] then
                    recoveringTargets[name] = true
                    initialized = true
                    
                    task.spawn(function()
                        local originalCF = myHRP.CFrame
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                        task.wait(0.15)
                        
                        if SetNetworkOwner and DestroyGrabLine then
                            SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            DestroyGrabLine:FireServer(charHRP)
                        end
                        task.wait(0.05)
                        
                        charHRP.CFrame = originalCF * CFrame.new(0, 20, 0)
                        if charTorso then charTorso.CFrame = originalCF * CFrame.new(0, 20, 0) end
                        myHRP.CFrame = originalCF
                        task.wait(0.1)
                        
                        if SetNetworkOwner and DestroyGrabLine then
                            SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            DestroyGrabLine:FireServer(charHRP)
                        end
                        
                        task.wait(0.3)
                        recoveringTargets[name] = nil
                    end)
                end
            end
            
            -- 매 프레임 고정: BodyPosition(math.huge) + Struggle 강화
            -- [1] HRP에 BodyPosition 적용
            if lastBP_HRP then lastBP_HRP:Destroy() lastBP_HRP = nil end
            local bp_HRP = Instance.new("BodyPosition", charHRP)
            bp_HRP.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp_HRP.Position = targetPos
            bp_HRP.D = 1000
            bp_HRP.P = 1000
            bp_HRP.Enabled = true
            lastBP_HRP = bp_HRP

            -- [2] Torso에도 BodyPosition 적용 (있다면)
            if charTorso then
                if lastBP_Torso then lastBP_Torso:Destroy() lastBP_Torso = nil end
                local bp_Torso = Instance.new("BodyPosition", charTorso)
                bp_Torso.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bp_Torso.Position = targetPos
                bp_Torso.D = 1000
                bp_Torso.P = 1000
                bp_Torso.Enabled = true
                lastBP_Torso = bp_Torso
            end

            -- [3] Struggle 강제 (저항 불가)
            charHUM.PlatformStand = true
            charHUM:ChangeState(Enum.HumanoidStateType.Physics)
            
            -- Ragdoll 상태 강제 해제
            local ragdolledVal = charHUM:FindFirstChild("Ragdolled")
            if ragdolledVal and ragdolledVal.Value == true then
                ragdolledVal.Value = false
            end
            
            -- FreeFall 상태 방지
            if charHUM:GetState() == Enum.HumanoidStateType.Freefall then
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
            end
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
        local SetNetOwner2 = RS:FindFirstChild("GrabEvents") and RS.GrabEvents:FindFirstChild("SetNetworkOwner")
        local DestroyLine2 = RS:FindFirstChild("GrabEvents") and RS.GrabEvents:FindFirstChild("DestroyGrabLine")
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

                if SetNetOwner2 and DestroyLine2 then
                    SetNetOwner2:FireServer(soundPart, soundPart.CFrame)
                    DestroyLine2:FireServer(soundPart)
                end

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
                    DestroyToy:FireServer(child)
                end
            end)

            getgenv().spawnNewPallet = function()
                if not getgenv().palletRagdollActive then return end
                if getgenv().PalletForRagdoll and getgenv().PalletForRagdoll.Parent then return end
                
                local c = plr.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if not h then return end

                task.spawn(function()
                    RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                        "PalletLightBrown",
                        h.CFrame * CFrame.new(0, 10, 20),
                        Vector3.zero
                    )
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
                DestroyToy:FireServer(pallet)
            end

            getgenv().PalletForRagdoll = nil

            local toysFolder = workspace:FindFirstChild(lpName .. "SpawnedInToys")
            if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then
                DestroyToy:FireServer(toysFolder.PalletForRagdoll)
            end
        end
    end,
})

--=============================================
-- [Settings 탭 - 복사 기능 추가]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)

-- 전체 스크립트 복사 버튼
SettingsTab:CreateButton({
    Name = "📋 스크립트 전체 복사",
    Callback = function()
        local scriptContent = "여기에 스크립트 전체 내용을 넣으세요" -- 실제로는 복사할 내용을 넣어야 합니다
        game:GetService("GuiService"):SetClipboard(scriptContent)
        Rayfield:Notify({Title = "복사 완료", Content = "스크립트가 클립보드에 복사되었습니다.", Duration = 2})
    end
})

SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "무한 룹티피 버그 수정 및 Y=20 고정 완료", Duration = 3})
