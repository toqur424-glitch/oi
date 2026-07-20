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
-- [TARGET 탭] - 타겟 설정 기능
--=============================================
local TargetTab = Window:CreateTab("Target (대상)", nil)
TargetTab:CreateSection("=== 특정 타겟 지정 ===")

getgenv().TargetPlayerName = ""

TargetTab:CreateInput({
    Name = "타겟 닉네임 입력",
    PlaceholderText = "닉네임 입력 (빈칸 시 전체/기본 대상)",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        getgenv().TargetPlayerName = Text
    end,
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
        local searchName = getgenv().TargetPlayerName or ""
        searchName = string.match(searchName, "^%s*(.-)%s*$") -- 앞뒤 공백 제거
        
        if searchName ~= "" then
            -- [수정] 평문 매칭(Plain Match) 적용으로 타겟팅 오작동 원천 차단
            for _, p in pairs(Players:GetPlayers()) do 
                if p ~= plr and p.Character and (string.find(string.lower(p.Name), string.lower(searchName), 1, true) or string.find(string.lower(p.DisplayName), string.lower(searchName), 1, true)) then 
                    target = p 
                    break 
                end 
            end
        else
            for _, p in pairs(Players:GetPlayers()) do 
                if p ~= plr and p.Character then target = p break end 
            end
        end
        
        if target then 
            startFKeyAttack(target) 
        else
            Rayfield:Notify({Title = "Error", Content = " 대상을 찾을 수 없습니다.", Duration = 3})
        end
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
    local searchName = getgenv().TargetPlayerName or ""
    searchName = string.match(searchName, "^%s*(.-)%s*$") -- 앞뒤 공백 제거
    
    if searchName ~= "" then
        -- [수정] 닉네임이 입력된 경우 정규식 패턴 오작동을 차단하고 정확히 해당 유저만 리스트에 삽입
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr then
                local nameMatch = string.find(string.lower(p.Name), string.lower(searchName), 1, true)
                local displayNameMatch = string.find(string.lower(p.DisplayName), string.lower(searchName), 1, true)
                
                if nameMatch or displayNameMatch then 
                    table.insert(kickTargetList, p.Name) 
                end
            end
        end
    else
        -- 입력창이 완전히 비어있을 때만 기존 원본 코드대로 전체 유저를 타겟팅
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr then table.insert(kickTargetList, p.Name) end
        end
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
                -- [★ 오직 이 리커버리 시스템만 완벽하게 고쳤습니다 ★]
                if ((charHRP.Position - myHRP.Position).Magnitude > 200 or not initializedTargets[player.Name]) and not recoveringTargets[player.Name] then
                    recoveringTargets[player.Name] = true
                    initializedTargets[player.Name] = true 
                    
                    task.spawn(function()
                        local originalCF = myHRP.CFrame
                        
                        -- 1. 상대방 위치로 즉시 순간이동 (끼임 방지를 위해 살짝 위로)
                        myHRP.CFrame = charHRP.CFrame * CFrame.new(0, 2, 0)
                        task.wait(0.15) -- 서버가 내 위치 이동을 동기화할 시간 확보
                        
                        -- 2. 그 자리에서 그랩 라인 생성 후 오너십 확실하게 강탈
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 30 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            end
                        end)
                        task.wait(0.05)
                        
                        -- 3. 상대를 내 공중 위치로 강제 이동 및 내 복귀를 동시에 처리 (디싱크 완전 차단)
                        charHRP.CFrame = originalCF * CFrame.new(0, 25, 0)
                        myHRP.CFrame = originalCF
                        task.wait(0.1)
                        
                        -- 4. 복귀 완료 후 확실하게 다시 한번 서버 잠금 (오너십 쐐기박기)
                        pcall(function()
                            rs.GrabEvents.CreateGrabLine:FireServer(charHRP, CFrame.new())
                            for i = 1, 30 do
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            end
                        end)
                        
                        task.wait(0.3)
                        recoveringTargets[player.Name] = nil
                    end)
                end
                
                -- [메인 루프 극한 고정 및 교차 킥] - 원본 유지
                local targetCF = myHRP.CFrame * CFrame.new(0, 25, 0)
                charHRP.CFrame = targetCF
                charHRP.AssemblyLinearVelocity = Vector3.zero
                charHRP.AssemblyAngularVelocity = Vector3.zero
                charHUM.PlatformStand = true
                charHUM:ChangeState(Enum.HumanoidStateType.Physics)
                
                frameToggle = not frameToggle
                if frameToggle then
                    for i = 1, 20 do rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position)) end
                else
                    charHRP.CFrame = targetCF 
                    for i = 1, 5 do rs.GrabEvents.DestroyGrabLine:FireServer(charHRP) end
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

-- [ 설정 부분 ]
local targetPlayerName = "타겟_플레이어_이름을_여기에_입력하세요" -- 공격할 플레이어 이름

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- 리모트 이벤트 및 펑션 가져오기
local MenuToys = RS:WaitForChild("MenuToys")
local GrabEvents = RS:WaitForChild("GrabEvents")

local SpawnToy = MenuToys:WaitForChild("SpawnToyRemoteFunction")
local DestroyToy = MenuToys:WaitForChild("DestroyToy")
local SetNetOwner = GrabEvents:WaitForChild("SetNetworkOwner")
local DestroyLine = GrabEvents:WaitForChild("DestroyGrabLine")

-- 상태 변수
local isActive = true
local ragdollConnection
local palletToy

local function StartPalletRagdoll(targetName)
    local targetPlayer = Players:FindFirstChild(targetName)
    if not targetPlayer then
        warn("타겟 플레이어를 찾을 수 없습니다.")
        return
    end

    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    -- 1. 판자 소환하기
    SpawnToy:InvokeServer("PalletLightBrown", myHRP.CFrame * CFrame.new(0, 10, 20), Vector3.zero)

    -- 2. 소환된 판자 찾기
    local toysFolder = workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys", 5)
    if not toysFolder then return end

    palletToy = toysFolder:WaitForChild("PalletLightBrown", 5)
    if not palletToy then return end

    local soundPart = palletToy:WaitForChild("SoundPart", 3)
    if not soundPart then return end

    -- 3. 네트워크 소유권 가져오기 및 연결선 제거
    SetNetOwner:FireServer(soundPart, soundPart.CFrame)
    DestroyLine:FireServer(soundPart)

    -- 4. 로컬 플레이어에게 보이지 않게 투명화 및 충돌 해제
    for _, part in pairs(palletToy:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
            part.Transparency = 1 
        end
    end

    local strikePhase = false

    -- 5. 물리 충돌 루프 (RunService.Stepped 사용)
    ragdollConnection = RunService.Stepped:Connect(function()
        if not isActive or not palletToy.Parent then 
            if ragdollConnection then ragdollConnection:Disconnect() end
            return 
        end

        local tChar = targetPlayer.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

        if tRoot and tHum and tHum.Health > 0 then
            local ragdolledVal = tHum:FindFirstChild("Ragdolled")
            local isRagdolled = ragdolledVal and ragdolledVal.Value or false

            -- 타겟이 아직 레그돌 상태가 아니라면 초고속 타격
            if not isRagdolled then
                strikePhase = not strikePhase
                if strikePhase then
                    soundPart.CFrame = tRoot.CFrame * CFrame.new(0, 2, 0)
                    soundPart.AssemblyLinearVelocity = Vector3.new(0, -9e5, 0) -- 위에서 아래로
                else
                    soundPart.CFrame = tRoot.CFrame * CFrame.new(0, -1, 0)
                    soundPart.AssemblyLinearVelocity = Vector3.new(0, 9e5, 0)  -- 아래서 위로
                end
            else
                -- 레그돌 상태가 되면 렉 방지를 위해 공중으로 치워두기
                soundPart.CFrame = CFrame.new(0, 9e9, 0)
                soundPart.AssemblyLinearVelocity = Vector3.zero
            end
        else
            -- 타겟이 죽거나 없으면 대기 상태
            soundPart.CFrame = CFrame.new(0, 9e9, 0)
            soundPart.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

-- 실행
StartPalletRagdoll(targetPlayerName)

-- 멈추고 싶을 때 사용하는 함수 (예: 채팅 명령어 등에 연결하여 사용)
local function StopPalletRagdoll()
    isActive = false
    if ragdollConnection then
        ragdollConnection:Disconnect()
        ragdollConnection = nil
    end
    if palletToy and palletToy.Parent then
        DestroyToy:FireServer(palletToy)
    end
end

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
