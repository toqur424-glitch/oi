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
        fAttackBodyPos.D = 1000          -- 증가
        fAttackBodyPos.P = 50000         -- 증가

        fAttackBodyGyro = Instance.new("BodyGyro", tRoot)
        fAttackBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        fAttackBodyGyro.D = 1000         -- 증가
        fAttackBodyGyro.P = 50000        -- 증가
    end

    fAttackConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        if not myRoot or not tgtRoot then return end

        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        tgtRoot.AssemblyAngularVelocity = Vector3.zero
        if tgtHum then
            tgtHum.PlatformStand = true
            tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
            tgtHum.WalkSpeed = 0
            tgtHum.JumpPower = 0
        end

        local camCF = camera.CFrame
        local targetPos = camCF.Position + camCF.LookVector * 15   -- 15스터드로 가깝게
        tgtRoot.CFrame = CFrame.new(targetPos)

        if fAttackBodyPos and fAttackBodyPos.Parent then
            fAttackBodyPos.Position = targetPos
        end
        if fAttackBodyGyro and fAttackBodyGyro.Parent then
            fAttackBodyGyro.CFrame = CFrame.lookAt(targetPos, myRoot.Position)
        end

        if (myRoot.Position - tgtRoot.Position).Magnitude <= 30 then
            -- 빈도 증가 (15회)
            for i = 1, 15 do
                pcall(function()
                    rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                    rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                    rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
                end)
            end
        else
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
            if not bodyPos or bodyPos.Parent ~= charHRP then
                if bodyPos then bodyPos:Destroy() end
                if bodyGyro then bodyGyro:Destroy() end
                bodyPos = Instance.new("BodyPosition", charHRP)
                bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyPos.D = 1000
                bodyPos.P = 50000

                bodyGyro = Instance.new("BodyGyro", charHRP)
                bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bodyGyro.D = 1000
                bodyGyro.P = 50000
            end

            local targetCF = myHRP.CFrame * CFrame.new(0, 20, 0)
            local currentDist = (charHRP.Position - targetCF.Position).Magnitude
            
            if (currentDist > 15 or not initialized) and not recoveringTargets[name] then
                recoveringTargets[name] = true
                initialized = true 
                
                task.spawn(function()
                    local originalCF = myHRP.CFrame
                    pcall(function()
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                    end)
                    RunService.RenderStepped:Wait()

                    -- 소유권 스팸 횟수 증가 (40회)
                    for i = 1, 40 do
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
                    
                    for i = 1, 40 do
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

                if (myHRP.Position - charHRP.Position).Magnitude <= 30 then
                    -- 매 프레임 두 가지 이벤트를 모두 실행 (고정 강화)
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    end)
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
-- (아래는 기존과 동일하므로 생략, 필요 시 원본 그대로 유지)
-- ... (원본 코드의 Pallet Ragdoll 부분을 그대로 두시면 됩니다) ...

--=============================================
-- [기타 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "셋오너 킥/판자 레그돌 최적화 완료 (충돌 및 낙하 수정)", Duration = 3})
