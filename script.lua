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
-- [GRAB 탭] - F키 조준 킥 그랩 (절대 고정 버전)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (매 프레임 강제 고정) ===")

getgenv().KickGrabActive = false
getgenv().FKeyAttackActive = false
local fAttackConnection = nil
local fAttackTarget = nil

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer

    -- 타겟에 BodyPosition 부착 (만약 CFrame이 막힐 경우를 대비한 백업)
    local tRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if tRoot then
        local bp = Instance.new("BodyPosition", tRoot)
        bp.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bp.D = 50
        bp.P = 50000
        getgenv().fAttackBodyPos = bp
        
        local bg = Instance.new("BodyGyro", tRoot)
        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.D = 50
        bg.P = 50000
        getgenv().fAttackBodyGyro = bg
    end

    fAttackConnection = RunService.Stepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        if not myRoot or not tgtRoot then return end

        -- 내 바로 앞 3스터드 위치로 강제 고정 (절대 위치)
        local targetPos = myRoot.Position + myRoot.CFrame.LookVector * 3
        
        -- 속도 완전 초기화
        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        tgtRoot.AssemblyAngularVelocity = Vector3.zero
        
        -- Humanoid 상태 강제 고정
        if tgtHum then
            tgtHum.PlatformStand = true
            tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
            tgtHum.WalkSpeed = 0
            tgtHum.JumpPower = 0
        end

        -- CFrame 직접 강제 설정 (이게 가장 쎔)
        tgtRoot.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, 0, 0)
        
        -- BodyPosition/Gyro 백업 업데이트
        if getgenv().fAttackBodyPos and getgenv().fAttackBodyPos.Parent then
            getgenv().fAttackBodyPos.Position = targetPos
        end
        if getgenv().fAttackBodyGyro and getgenv().fAttackBodyGyro.Parent then
            getgenv().fAttackBodyGyro.CFrame = CFrame.lookAt(targetPos, myRoot.Position)
        end

        -- 매 프레임 지연 없이 소유권 강제 스팸 (기존 루프 제거)
        pcall(function()
            rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
            rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
            rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
        end)
        -- 한 번 더 추가로 쏴서 확실하게
        pcall(function()
            rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
            rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
            rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
        end)
    end)
end

GrabTab:CreateKeybind({
    Name = "F키 조준 킥 그랩 (절대 고정)",
    CurrentKeybind = "F",
    Callback = function()
        if not getgenv().KickGrabActive then getgenv().KickGrabActive = true end
        
        -- 이미 실행 중이면 종료
        if getgenv().FKeyAttackActive then 
            getgenv().FKeyAttackActive = false
            if fAttackConnection then fAttackConnection:Disconnect() end
            if getgenv().fAttackBodyPos then getgenv().fAttackBodyPos:Destroy() end
            if getgenv().fAttackBodyGyro then getgenv().fAttackBodyGyro:Destroy() end
            return 
        end
        
        -- 가장 가까운 플레이어 자동 타겟팅
        local target = nil 
        local closestDist = math.huge
        for _, p in pairs(Players:GetPlayers()) do 
            if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (plr.Character.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    target = p
                end
            end 
        end
        if target then startFKeyAttack(target) end
    end
})

--=============================================
-- [KICK 탭] - 블롭맨 오너 킥 (무조건 락온)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local blobLoopT4 = false
local selectedKickPlayer = nil
local blobSteppedConn = nil

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
    if blobSteppedConn then blobSteppedConn:Disconnect() end
    
    blobSteppedConn = RunService.Stepped:Connect(function()
        if not blobLoopT4 then return end
        
        local player = selectedKickPlayer
        if not player or not player.Character then return end
        
        local charHRP = player.Character:FindFirstChild("HumanoidRootPart")
        local charHUM = player.Character:FindFirstChild("Humanoid")
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        
        if not myHRP or not charHRP or not charHUM or charHUM.Health <= 0 then return end

        -- 내 머리 위 15스터드로 강제 텔레포트 (거리 상관없음)
        local targetCF = myHRP.CFrame * CFrame.new(0, 15, 0)

        charHRP.AssemblyLinearVelocity = Vector3.zero
        charHRP.AssemblyAngularVelocity = Vector3.zero
        charHUM.PlatformStand = true
        charHUM:ChangeState(Enum.HumanoidStateType.Physics)
        
        -- CFrame 직접 강제
        charHRP.CFrame = targetCF

        -- 매 프레임 소유권 스팸 (기존 루프 제거)
        pcall(function()
            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
            rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
        end)
        pcall(function()
            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
            rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
        end)
    end)
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (거리 무시, 매 프레임 강제 고정)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            blobLoopT4 = false
            return
        end
        
        blobLoopT4 = v
        if v then 
            loopPlayerBlobF4()
        else
            if blobSteppedConn then 
                blobSteppedConn:Disconnect() 
                blobSteppedConn = nil
            end
        end
    end
})

--=============================================
-- [기타 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "절대 고정 버전 적용 완료 (CFrame 강제 덮어쓰기 + 초고속 스팸)", Duration = 3})
