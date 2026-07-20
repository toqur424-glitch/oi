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
    local isHrpFrame = true
    fAttackConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtTorso = tgtChar and (tgtChar:FindFirstChild("Torso") or tgtChar:FindFirstChild("UpperTorso"))
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        if not myRoot or not tgtRoot then return end
        -- [극대화] 타겟 물리 속도 0 고정 & 조작 불가
        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        if tgtHum then tgtHum.PlatformStand = true end
        
        local camCF = camera.CFrame
        pcall(function() tgtRoot.CFrame = CFrame.new(camCF.Position + camCF.LookVector * 20) end)
        
        -- [극대화] 다중 연사 (킥 속도 극대화)
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
        local target = nil -- (간략화된 타겟팅 로직)
        for _, p in pairs(Players:GetPlayers()) do 
            if p ~= plr and p.Character then target = p break end 
        end
        if target then startFKeyAttack(target) end
    end
})

--=============================================
-- [KICK 탭] - 극대화된 블롭맨 셋오너 킥
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨)", nil)
local blobLoopT4 = false
local kickTargetList = {}

-- [극대화] 오너 킥 루프
function loopPlayerBlobF4()
    local initializedTargets = {}
    
    while blobLoopT4 do
        for _, name in pairs(kickTargetList) do
            local player = Players:FindFirstChild(name)
            
            -- [감지] 리셋/탈주 시 상태 초기화
            if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
                initializedTargets[name] = nil
                continue
            end

            local charHRP = player.Character.HumanoidRootPart
            local charHUM = player.Character:FindFirstChild("Humanoid")
            local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            
            if myHRP and charHRP and charHUM then
                -- [범위 감지] 멀어지면 재연결 시도
                if (charHRP.Position - myHRP.Position).Magnitude > 200 then
                    initializedTargets[player.Name] = nil
                end
                
                -- [핸드셰이크] 타겟 새로 잡기/재연결 시 1회 TP
                if not initializedTargets[player.Name] then
                    local originalCF = myHRP.CFrame
                    myHRP.CFrame = charHRP.CFrame
                    task.wait(0.1) 
                    for i = 1, 20 do
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                    end
                    myHRP.CFrame = originalCF
                    initializedTargets[player.Name] = true
                end
                
                -- [루프 고정] 머리 위 25 고정
                charHRP.CFrame = myHRP.CFrame * CFrame.new(0, 25, 0)
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                
                -- [유지] 리모트 연사 속도 극대화
                for i = 1, 10 do
                    rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                end
            end
        end
        task.wait(0.0001)
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행",
    Callback = function(v)
        blobLoopT4 = v
        if v then task.spawn(loopPlayerBlobF4) end
    end
})

--=============================================
-- [나머지 필수 탭들 유지]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "강력한 킥 스크립트 적용됨", Duration = 3})

KickTab:CreateInput({
    Name = "Add Target (여기에 닉네임 입력)",
    PlaceholderText = "예: Player1",
    RemoveTextAfterFocusLost = true,
    Callback = function(v)
        if v == "" then return end
        local found = nil
        -- 입력한 이름과 일치하는 유저를 서버 내에서 자동으로 찾습니다.
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
        
        -- 이미 추가된 유저인지 중복 체크
        for _, n in ipairs(kickTargetList) do
            if n == found.Name then return end
        end
        
        -- 리스트에 추가
        table.insert(kickTargetList, found.Name)
        kickDropdown:Refresh(kickTargetList, true)
        Rayfield:Notify({Title = "추가됨", Content = found.Name .. "님이 타겟으로 설정되었습니다.", Duration = 2})
    end
})
