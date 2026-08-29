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
-- [헬퍼 함수]
--=============================================
local function checkDistance(targetPart, maxDist)
    if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then return false end
    local myRoot = plr.Character.HumanoidRootPart
    return (myRoot.Position - targetPart.Position).Magnitude <= (maxDist or 30)
end

local function safeSetCFrame(targetPart, newCFrame)
    pcall(function()
        targetPart.CFrame = newCFrame
        targetPart.AssemblyLinearVelocity = Vector3.zero
        targetPart.AssemblyAngularVelocity = Vector3.zero
    end)
end

--=============================================
-- [UI 생성]
--=============================================
local Window = Rayfield:CreateWindow({
    Name = "🔥 SetOwner Kick Hub",
    LoadingTitle = "로딩 중...",
    LoadingSubtitle = "by SetOwner",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [GRAB 탭] - 셋오너킥 (버튼식)
--=============================================
local GrabTab = Window:CreateTab("Grab (셋오너킥)", nil)
GrabTab:CreateSection("=== 타겟 선택 ===")

local selectedTarget = nil

GrabTab:CreateInput({
    Name = "타겟 선택",
    PlaceholderText = "플레이어 이름 입력",
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
            Rayfield:Notify({Title = "오류", Content = "플레이어를 찾을 수 없습니다.", Duration = 2})
            return 
        end
        
        selectedTarget = found
        Rayfield:Notify({Title = "✅ 타겟 설정됨", Content = found.Name, Duration = 2})
    end
})

--=============================================
-- CreateGrabLine
--=============================================
GrabTab:CreateSection("=== CreateGrabLine ===")

GrabTab:CreateButton({
    Name = "CreateGrabLine 실행",
    Callback = function()
        if not selectedTarget or not selectedTarget.Character then
            Rayfield:Notify({Title = "오류", Content = "타겟을 먼저 선택하세요", Duration = 2})
            return
        end
        
        local tgtRoot = selectedTarget.Character:FindFirstChild("HumanoidRootPart")
        if not tgtRoot then return end
        
        pcall(function()
            rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
            Rayfield:Notify({Title = "✅ 실행됨", Content = "CreateGrabLine", Duration = 1})
        end)
    end
})

--=============================================
-- SetNetworkOwner (단일)
--=============================================
GrabTab:CreateSection("=== SetNetworkOwner ===")

GrabTab:CreateButton({
    Name = "SetNetworkOwner 1회 호출",
    Callback = function()
        if not selectedTarget or not selectedTarget.Character then
            Rayfield:Notify({Title = "오류", Content = "타겟을 먼저 선택하세요", Duration = 2})
            return
        end
        
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtRoot = selectedTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if not myRoot or not tgtRoot then return end
        
        if checkDistance(tgtRoot, 30) then
            pcall(function()
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                Rayfield:Notify({Title = "✅ 실행됨", Content = "SetNetworkOwner", Duration = 1})
            end)
        else
            Rayfield:Notify({Title = "⚠️ 거리초과", Content = "30스터드 이내에 있어야 합니다", Duration = 2})
        end
    end
})

--=============================================
-- SetNetworkOwner 반복 (토글)
--=============================================
local repeatActive = false
local repeatConnection = nil

GrabTab:CreateToggle({
    Name = "SetNetworkOwner 반복 (15회)",
    Default = false,
    Callback = function(v)
        if v then
            if not selectedTarget or not selectedTarget.Character then
                Rayfield:Notify({Title = "오류", Content = "타겟을 먼저 선택하세요", Duration = 2})
                return
            end
            
            repeatActive = true
            local target = selectedTarget
            local count = 0
            
            repeatConnection = RunService.Heartbeat:Connect(function()
                if not repeatActive or not target or not target.Character then
                    repeatActive = false
                    if repeatConnection then repeatConnection:Disconnect() end
                    return
                end
                
                if count < 15 then
                    local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    local tgtRoot = target.Character:FindFirstChild("HumanoidRootPart")
                    
                    if myRoot and tgtRoot and checkDistance(tgtRoot, 30) then
                        pcall(function()
                            rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                        end)
                        count = count + 1
                    end
                else
                    repeatActive = false
                    if repeatConnection then repeatConnection:Disconnect() end
                    Rayfield:Notify({Title = "✅ 완료", Content = "SetNetworkOwner 15회 호출 완료", Duration = 2})
                end
            end)
        else
            repeatActive = false
            if repeatConnection then repeatConnection:Disconnect() end
        end
    end
})

--=============================================
-- DestroyGrabLine
--=============================================
GrabTab:CreateSection("=== DestroyGrabLine ===")

GrabTab:CreateButton({
    Name = "DestroyGrabLine 실행",
    Callback = function()
        if not selectedTarget or not selectedTarget.Character then
            Rayfield:Notify({Title = "오류", Content = "타겟을 먼저 선택하세요", Duration = 2})
            return
        end
        
        local tgtRoot = selectedTarget.Character:FindFirstChild("HumanoidRootPart")
        if not tgtRoot then return end
        
        pcall(function()
            rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
            Rayfield:Notify({Title = "✅ 실행됨", Content = "DestroyGrabLine", Duration = 1})
        end)
    end
})

--=============================================
-- 전체 순서 실행 (CreateGrabLine → SetNetworkOwner → DestroyGrabLine)
--=============================================
GrabTab:CreateSection("=== 전체 순서 ===")

GrabTab:CreateButton({
    Name = "전체 실행 (Create→SetOwner→Destroy)",
    Callback = function()
        if not selectedTarget or not selectedTarget.Character then
            Rayfield:Notify({Title = "오류", Content = "타겟을 먼저 선택하세요", Duration = 2})
            return
        end
        
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtRoot = selectedTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if not myRoot or not tgtRoot then return end
        
        if checkDistance(tgtRoot, 30) then
            pcall(function()
                -- 1단계: CreateGrabLine
                rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                Rayfield:Notify({Title = "📍 단계 1/3", Content = "CreateGrabLine 호출됨", Duration = 0.5})
                
                task.wait(0.01)
                
                -- 2단계: SetNetworkOwner
                rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                Rayfield:Notify({Title = "📍 단계 2/3", Content = "SetNetworkOwner 호출됨", Duration = 0.5})
                
                task.wait(0.01)
                
                -- 3단계: DestroyGrabLine
                rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
                Rayfield:Notify({Title = "✅ 단계 3/3", Content = "DestroyGrabLine 호출됨 (완료)", Duration = 1})
            end)
        else
            Rayfield:Notify({Title = "⚠️ 거리초과", Content = "30스터드 이내에 있어야 합니다", Duration = 2})
        end
    end
})

--=============================================
-- 루프 제어 (계속 반복)
--=============================================
GrabTab:CreateSection("=== 루프 제어 ===")

local loopActive = false
local loopConnection = nil

GrabTab:CreateToggle({
    Name = "지속 SetNetworkOwner (루프)",
    Default = false,
    Callback = function(v)
        if v then
            if not selectedTarget or not selectedTarget.Character then
                Rayfield:Notify({Title = "오류", Content = "타겟을 먼저 선택하세요", Duration = 2})
                return
            end
            
            loopActive = true
            local target = selectedTarget
            
            loopConnection = RunService.RenderStepped:Connect(function()
                if not loopActive or not target or not target.Character then
                    loopActive = false
                    if loopConnection then loopConnection:Disconnect() end
                    return
                end
                
                local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local tgtRoot = target.Character:FindFirstChild("HumanoidRootPart")
                
                if myRoot and tgtRoot and checkDistance(tgtRoot, 30) then
                    pcall(function()
                        rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                    end)
                end
            end)
            
            Rayfield:Notify({Title = "▶️ 시작됨", Content = "지속 SetNetworkOwner 실행중", Duration = 1})
        else
            loopActive = false
            if loopConnection then loopConnection:Disconnect() end
            Rayfield:Notify({Title = "⏹️ 중지됨", Content = "루프 종료", Duration = 1})
        end
    end
})

--=============================================
-- 타겟 위치 이동 (카메라 앞 20스터드)
--=============================================
GrabTab:CreateSection("=== 타겟 이동 ===")

GrabTab:CreateButton({
    Name = "타겟을 카메라 앞으로 이동",
    Callback = function()
        if not selectedTarget or not selectedTarget.Character then
            Rayfield:Notify({Title = "오류", Content = "타겟을 먼저 선택하세요", Duration = 2})
            return
        end
        
        local tgtRoot = selectedTarget.Character:FindFirstChild("HumanoidRootPart")
        if not tgtRoot then return end
        
        local camCF = camera.CFrame
        local targetPos = camCF.Position + camCF.LookVector * 20
        
        safeSetCFrame(tgtRoot, CFrame.new(targetPos))
        Rayfield:Notify({Title = "✅", Content = "타겟이 카메라 앞으로 이동됨", Duration = 1})
    end
})

--=============================================
-- 설정
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateLabel("셋오너킥 버튼식 허브")
SettingsTab:CreateLabel("1. 타겟 이름 입력")
SettingsTab:CreateLabel("2. 원하는 버튼 클릭")
SettingsTab:CreateLabel("3. 효과 확인")

Rayfield:Notify({
    Title = "🚀 로딩 완료", 
    Content = "Grab 탭에서 시작하세요\n버튼식 셋오너킥", 
    Duration = 3
})
