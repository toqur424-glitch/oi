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
                -- 실시간 하늘 고정 목표 위치 지정
                local targetCF = myHRP.CFrame * CFrame.new(0, 25, 0)
                
                -- [정확도 대폭 상향된 리커버리 감지]
                -- 지정된 하늘 격리구역에서 35스터드 이상 벗어나면 탈출로 간주하고 즉시 낚아챔
                local currentDist = (charHRP.Position - targetCF.Position).Magnitude
                if (currentDist > 35 or not initializedTargets[player.Name]) and not recoveringTargets[player.Name] then
                    recoveringTargets[player.Name] = true
                    initializedTargets[player.Name] = true 
                    
                    task.spawn(function()
                        local originalCF = myHRP.CFrame
                        
                        -- 1. 상대방 위치로 즉시 이동 후 물리 속도 완전 무력화 (가져오는 정확도 향상)
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2.5, 0)
                        charHRP.AssemblyLinearVelocity = Vector3.zero
                        charHRP.AssemblyAngularVelocity = Vector3.zero
                        task.wait(0.08)
                        
                        -- 2. 그 자리에서 즉시 그랩라인 활성화 및 강력한 오너십 탈취 (반복 횟수 상향으로 정확도 고정)
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 45 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            end
                        end)
                        task.wait(0.04)
                        
                        -- 3. 상대를 내 공중 감옥으로 정밀 텔레포트 시키면서 본체 동시 복귀
                        charHRP.CFrame = originalCF * CFrame.new(0, 25, 0)
                        charHRP.AssemblyLinearVelocity = Vector3.zero
                        myHRP.CFrame = originalCF
                        task.wait(0.06)
                        
                        -- 4. 복귀 후 락(Lock)을 완전히 굳히기 위한 쐐기 작업 (네트워크 소유권 강제 결속)
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 30 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.CFrame.Position))
                            end
                        end)
                        
                        task.wait(0.15) -- 반응 속도 극대화를 위해 리커버리 쿨타임 최적화 단축
                        recoveringTargets[player.Name] = nil
                    end)
                end
                
                -- [메인 루프 - 극대화된 강력 고정 락킹]
                -- 물리 저항을 차단하기 위해 임시 벨로시티 효과 추가 적용 및 좌표 강제 고정
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                
                -- 물리 저항 원천 차단을 위한 임시 BodyVelocity 강제 주입 (고정력 최상)
                if not charHRP:FindFirstChild("ExtremeLockBV") then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "ExtremeLockBV"
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Vector3.zero
                    bv.Parent = charHRP
                end
                
                -- 인간형 상태 강제 캔슬
                if charHUM.PlatformStand ~= true then charHUM.PlatformStand = true end
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                -- 락 풀림 방지를 위해 매 프레임 서버에 락 상태를 더욱 촘촘하게 갱신 및 주입
                pcall(function()
                    rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                    for i = 1, 25 do 
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position)) 
                    end
                end)
            else
                -- 대상이 범위를 벗어나거나 사라졌을 때 오브젝트 정리
                if charHRP and charHRP:FindFirstChild("ExtremeLockBV") then
                    charHRP.ExtremeLockBV:Destroy()
                end
            end
        end
        RunService.RenderStepped:Wait()
    end
    
    -- 루프가 종료되면 모든 플레이어의 고정 오브젝트 해제
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart:FindFirstChild("ExtremeLockBV") then
            p.Character.HumanoidRootPart.ExtremeLockBV:Destroy()
        end
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
