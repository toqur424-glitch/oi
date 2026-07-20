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
-- [KICK 탭] - 극대화된 블롭맨 셋오너 킥
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨)", nil)
local blobLoopT4 = false
local kickTargetList = {}
local recoveringTargets = {} 

local function updateTargetList()
    kickTargetList = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= plr then table.insert(kickTargetList, p.Name) end
    end
end

function loopPlayerBlobF4()
    local initializedTargets = {}
    local frameToggle = false
    
    while blobLoopT4 do
        updateTargetList()
        for _, name in pairs(kickTargetList) do
            local player = Players:FindFirstChild(name)
            local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            
            if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
                initializedTargets[name] = nil
                continue
            end

            local charHRP = player.Character.HumanoidRootPart
            local charHUM = player.Character:FindFirstChild("Humanoid")
            
            if myHRP and charHRP and charHUM then
                -- [정확도가 대폭 수정된 리커버리 판정 시스템]
                -- 지정된 하늘 격리 좌표에서 35스터드 이상 벗어나면 즉시 탈출로 인식하고 가져옴
                local targetAirPos = myHRP.Position + Vector3.new(0, 25, 0)
                if ((charHRP.Position - targetAirPos).Magnitude > 35 or not initializedTargets[player.Name]) and not recoveringTargets[player.Name] then
                    recoveringTargets[player.Name] = true
                    initializedTargets[player.Name] = true 
                    
                    task.spawn(function()
                        local originalCF = myHRP.CFrame
                        
                        -- 1. 상대방 위치로 즉시 순간이동
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                        task.wait(0.12) -- 서버가 내 위치 변경을 인지할 충분한 시간 확보
                        
                        -- 2. 그 자리에서 오너십 강탈 (그랩 라인 생성을 추가하여 가져오기 정확도 극대화)
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 40 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            end
                        end)
                        task.wait(0.05) -- 패킷 서버 도달 대기
                        
                        -- 3. 상대를 내 위치(공중)로 강제 이동 (가져오기)
                        charHRP.CFrame = originalCF * CFrame.new(0, 25, 0)
                        task.wait(0.1) -- 물리적 당겨오기가 네트워크에 반영될 시간 확보
                        
                        -- 4. 원래 내 위치로 복귀
                        myHRP.CFrame = originalCF
                        task.wait(0.1) -- 내 복귀 동기화 대기
                        
                        -- 5. 복귀 완료 후 확실하게 다시 한번 락(Lock)
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 40 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            end
                        end)
                        
                        task.wait(0.3) -- 완벽한 안정화 유예 (거리 체크 오작동 방지)
                        recoveringTargets[player.Name] = nil
                    end)
                end
                
                -- [메인 루프 극한 고정 및 교차 킥] - 원본 틀 유지 및 고정력 최상 상향
                local targetCF = myHRP.CFrame * CFrame.new(0, 25, 0)
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                frameToggle = not frameToggle
                if frameToggle then
                    -- 그랩라인 결속과 함께 락 주입 횟수를 늘려 뜀박질/탈출 완전 봉쇄
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        for i = 1, 35 do rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position)) end
                    end)
                else
                    charHRP.CFrame = targetCF 
                    pcall(function()
                        for i = 1, 5 do rs.GrabEvents.DestroyGrabLine:FireServer(charHRP) end
                    end)
                end
            end
        end
        RunService.RenderStepped:Wait()
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (자동 복귀)",
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

Rayfield:Notify({Title = "로딩 완료", Content = "네트워크 동기화 타이밍 최적화 완료", Duration = 3})

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
