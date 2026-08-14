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
-- [GRAB 탭] - F키 1회용 킥 그랩
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not targetPlayer then return end
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = targetPlayer.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        if not myRoot or not tgtRoot then return end
        
        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        pcall(function() tgtRoot.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 20) end)
        
        if (myRoot.Position - tgtRoot.Position).Magnitude <= 30 then
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
-- [KICK 탭] - 셋오너 디트로이트 룹 (빈도수 상향)
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
        if found then 
            selectedKickPlayer = found
            Rayfield:Notify({Title = "타겟 설정됨", Content = found.Name .. "님이 타겟으로 설정되었습니다.", Duration = 2})
        end
    end
})

function loopPlayerBlobF4()
    local frameToggle = false
    local checkTimer = 0
    
    while blobLoopT4 do
        local player = selectedKickPlayer
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            RunService.RenderStepped:Wait()
            continue
        end

        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        if myHRP and charHRP and charHUM then
            local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
            local currentDist = (charHRP.Position - targetCF.Position).Magnitude
            
            -- [수정] 10스터드 이상 벗어나면 즉시 추적 및 강제 셋오너 스팸
            if currentDist > 10 then
                pcall(function()
                    myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                    -- [핵심] RenderStepped로 프레임마다 셋오너 스팸 (빈도수 극대화)
                    for i = 1, 5 do
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                        RunService.RenderStepped:Wait()
                    end
                    charHRP.CFrame = myHRP.CFrame * CFrame.new(0, 20, 0)
                end)
            end
            
            -- [수정] 30스터드 이내에서 프레임마다 교차로 셋오너 스팸 (디트로이트 유지)
            if (myHRP.Position - charHRP.Position).Magnitude <= 30 then
                frameToggle = not frameToggle
                if frameToggle then
                    rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                    rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                else
                    rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                end
            end
            
            pcall(function()
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHUM.PlatformStand = true
            end)
        end
        RunService.RenderStepped:Wait()
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (디트로이트 고빈도)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟을 입력해주세요!", Duration = 3})
            return
        end
        blobLoopT4 = v
        if v then task.spawn(loopPlayerBlobF4) end
    end
})

--=============================================
-- [Pallet Ragdoll (Invis) - 관통 공격 버전]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (관통/순간이동)",
    Callback = function(Value)
        local RS = game:GetService("ReplicatedStorage")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
        local SpawnToy = RS:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
        local lpName = plr.Name
        local activeState = Value

        local function clearAttackLoop()
            if getgenv().ragdollSteppedConn then
                getgenv().ragdollSteppedConn:Disconnect()
                getgenv().ragdollSteppedConn = nil
            end
        end

        if activeState then
            if not selectedKickPlayer then
                Rayfield:Notify({Title = "알림", Content = "타겟을 먼저 입력해주세요", Duration = 3})
                return
            end

            getgenv().palletRagdollActive = true
            getgenv().PalletForRagdoll = nil
            clearAttackLoop()

            local toysFolder = workspace:WaitForChild(lpName .. "SpawnedInToys", 5)
            if not toysFolder then return end

            getgenv().palletCacheConn = toysFolder.ChildAdded:Connect(function(child)
                if not getgenv().palletRagdollActive then return end
                if child.Name ~= "PalletLightBrown" and child.Name ~= "PalletForRagdoll" then return end

                local soundPart = child:WaitForChild("SoundPart", 3)
                if not soundPart then return end

                pcall(function()
                    SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                    DestroyLine:FireServer(soundPart)
                end)

                if soundPart:WaitForChild("PartOwner", 1).Value == lpName then
                    child.Name = "PalletForRagdoll"
                    getgenv().PalletForRagdoll = child

                    getgenv().ragdollSteppedConn = RunService.Stepped:Connect(function()
                        if not getgenv().palletRagdollActive or not child.Parent then 
                            clearAttackLoop()
                            return 
                        end

                        local tChar = selectedKickPlayer and selectedKickPlayer.Character
                        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

                        if tRoot and tHum and soundPart.Parent and tHum.Health > 0 then
                            -- [수정] 팔레트를 타겟 위치로 순간이동 (몸속 파고들기)
                            soundPart.CFrame = tRoot.CFrame
                            soundPart.AssemblyLinearVelocity = Vector3.new(0, -1, 0) -- 관통 효과
                            task.wait(0.01)
                            soundPart.CFrame = CFrame.new(0, 9e9, 0) -- 즉시 하늘로 이동
                            soundPart.AssemblyLinearVelocity = Vector3.zero
                        else
                            soundPart.CFrame = CFrame.new(0, 9e9, 0)
                        end
                    end)

                    child.AncestryChanged:Connect(function()
                        if not child.Parent then
                            clearAttackLoop()
                            if getgenv().palletRagdollActive then
                                task.wait(0.03)
                                if getgenv().spawnNewPallet then getgenv().spawnNewPallet() end
                            end
                        end
                    end)
                end
            end)

            getgenv().spawnNewPallet = function()
                if getgenv().PalletForRagdoll and getgenv().PalletForRagdoll.Parent then return end
                local h = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not h then return end
                task.spawn(function() pcall(function() SpawnToy:InvokeServer("PalletLightBrown", h.CFrame * CFrame.new(0, 10, 20), Vector3.zero) end) end)
            end
            getgenv().spawnNewPallet()
        else
            getgenv().palletRagdollActive = false
            clearAttackLoop()
            local pallet = getgenv().PalletForRagdoll
            if pallet and pallet.Parent then pcall(function() DestroyToy:FireServer(pallet) end) end
            getgenv().PalletForRagdoll = nil
        end
    end,
})

--=============================================
-- [나머지 필수 탭들 유지]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "디트로이트 및 팔레트 관통 최적화 반영됨", Duration = 3})
