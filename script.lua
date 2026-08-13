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

-- [추가] Y좌표 교차 변수 설정
local yHeights = {20, 23, 25}
local yIndex = 1
local frameCounter = 0

function loopPlayerBlobF4()
    local initialized = false
    local frameToggle = false
    
    while blobLoopT4 do
        local player = selectedKickPlayer
        
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            initialized = false
            RunService.RenderStepped:Wait()
            continue
        end

        local name = player.Name
        local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local charHRP = player.Character.HumanoidRootPart
        local charHUM = player.Character:FindFirstChild("Humanoid")
        
        if myHRP and charHRP and charHUM then
            -- [수정] 4프레임마다 Y좌표를 20, 23, 25로 번갈아가며 변경
            frameCounter = frameCounter + 1
            if frameCounter >= 4 then
                yIndex = yIndex + 1
                if yIndex > #yHeights then yIndex = 1 end
                frameCounter = 0
            end
            local currentY = yHeights[yIndex]
            
            -- Y좌표 교차 적용 목표 위치
            local targetCF = myHRP.CFrame * CFrame.new(0, currentY, 0)
            
            local currentDist = (charHRP.Position - targetCF.Position).Magnitude
            
            if (currentDist > 15 or not initialized) and not recoveringTargets[name] then
                recoveringTargets[name] = true
                initialized = true 
                
                task.spawn(function()
                    local originalCF = myHRP.CFrame
                    pcall(function()
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                    end)
                    task.wait(0.15)
                    
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        for i = 1, 15 do
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            RunService.Heartbeat:Wait()
                        end
                    end)
                    task.wait(0.05)
                    
                    pcall(function()
                        -- 복귀 시에도 현재 교차 중인 Y좌표 반영
                        charHRP.CFrame = originalCF * CFrame.new(0, currentY, 0)
                        myHRP.CFrame = originalCF
                    end)
                    task.wait(0.1)
                    
                    pcall(function()
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        for i = 1, 15 do
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            RunService.Heartbeat:Wait()
                        end
                    end)
                    
                    task.wait(0.3)
                    recoveringTargets[name] = nil
                end)
            end
            
            pcall(function()
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                if (myHRP.Position - charHRP.Position).Magnitude <= 30 then
                    frameToggle = not frameToggle
                    if frameToggle then
                        rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                    else
                        rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                        rs.GrabEvents.DestroyGrabLine:FireServer(charHRP)
                    end
                end
            end)
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
-- [디트로이트 판자 (Detroit Plank) 통합]
--=============================================
local detroitActive = false
local detroitHeartbeatConn = nil

-- 1.5초마다 높이(20, 23, 25)를 순환하는 전역 로직
local plankHeights = {20, 23, 25}
local heightIdx = 1
local currentPlankHeight = plankHeights[heightIdx]

task.spawn(function()
    while true do
        task.wait(1.5)
        heightIdx = heightIdx + 1
        if heightIdx > #plankHeights then 
            heightIdx = 1 
        end
        currentPlankHeight = plankHeights[heightIdx]
    end
end)

-- 스폰 대기 헬퍼 함수
local function SpawnToyRobust(toyName, hrp)
    local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    if not inv then return nil end
    
    local spawnCF = hrp.CFrame * CFrame.new(0, 14, 20)
    task.spawn(function()
        pcall(function()
            rs.MenuToys.SpawnToyRemoteFunction:InvokeServer(toyName, spawnCF, Vector3.zero)
        end)
    end)

    local t = tick()
    local spawnedToy = nil
    repeat
        task.wait(0.1)
        spawnedToy = inv:FindFirstChild(toyName)
    until spawnedToy or (tick() - t > 3)
    
    return spawnedToy
end

KickTab:CreateToggle({
    Name = "Detroit Plank (디트로이트 판자 킥)",
    Flag = "DetroitPlankTarget",
    Default = false,
    Callback = function(Value)
        detroitActive = Value
        local DestroyToy = rs:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = rs:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = rs:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")

        if Value then
            if not selectedKickPlayer then
                Rayfield:Notify({Title = "알림", Content = "타겟을 먼저 입력해주세요", Duration = 3})
                -- UI 토글 상태 복구는 Rayfield 특성상 생략
                return
            end

            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            -- 기존에 소환된 판자 정리
            local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if inv then
                for _, v in pairs(inv:GetChildren()) do
                    if v.Name == "DetroitPlankToy" or v.Name == "PalletLightBrown" then
                        pcall(function() DestroyToy:FireServer(v) end)
                    end
                end
            end

            local pallet = SpawnToyRobust("PalletLightBrown", hrp)
            if not pallet then
                Rayfield:Notify({Title = "오류", Content = "판자 소환에 실패했습니다.", Duration = 3})
                return
            end

            pallet.Name = "DetroitPlankToy"
            local soundPart = pallet:WaitForChild("SoundPart", 3) or pallet:FindFirstChildWhichIsA("BasePart")
            
            -- [수정 핵심]: 물리 충돌을 강제로 활성화하여 뚫리지 않고 레그돌을 유도함
            if soundPart then
                soundPart.CanCollide = true
                soundPart.Massless = false
            end

            if detroitHeartbeatConn then detroitHeartbeatConn:Disconnect() end
            detroitHeartbeatConn = RunService.Heartbeat:Connect(function()
                if not detroitActive or not pallet.Parent then 
                    if detroitHeartbeatConn then detroitHeartbeatConn:Disconnect() end
                    return 
                end

                local tChar = selectedKickPlayer and selectedKickPlayer.Character
                local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

                if tRoot and tHum and soundPart and soundPart.Parent and tHum.Health > 0 then
                    -- 1. 셋오너 빈도 극대화
                    pcall(function()
                        SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                        DestroyLine:FireServer(soundPart)
                    end)

                    -- 2. 1.5초마다 바뀌는 높이를 타겟 머리 위에 실시간 적용
                    local targetPos = tRoot.Position
                    soundPart.CFrame = CFrame.new(targetPos + Vector3.new(0, currentPlankHeight, 0), targetPos)
                    
                    -- 3. 아래로 강하게 내리꽂는 물리 속도 부여 (레그돌 완벽 유도)
                    soundPart.AssemblyLinearVelocity = Vector3.new(0, -500, 0)
                    soundPart.AssemblyAngularVelocity = Vector3.new(math.random(-100, 100), 0, math.random(-100, 100))
                else
                    if soundPart then
                        soundPart.CFrame = CFrame.new(0, 50000, 0)
                        soundPart.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end)
            
        else
            if detroitHeartbeatConn then
                detroitHeartbeatConn:Disconnect()
                detroitHeartbeatConn = nil
            end

            -- 토글 OFF 시 장난감 삭제
            local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if inv then
                for _, v in pairs(inv:GetChildren()) do
                    if v.Name == "DetroitPlankToy" or v.Name == "PalletLightBrown" then
                        pcall(function() DestroyToy:FireServer(v) end)
                    end
                end
            end
        end
    end,
})

--=============================================
-- [나머지 필수 탭들 유지]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "디트로이트 및 오너 룹 최적화 반영됨", Duration = 3})
