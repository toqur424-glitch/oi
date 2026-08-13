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
local rs = ReplicatedStorage

--=============================================
-- [UI 생성]
--=============================================
local Window = Rayfield:CreateWindow({
    Name = "💣 FSOF Bomb Auto-Kill",
    LoadingTitle = "스크립트 로딩 중...",
    LoadingSubtitle = "by Extreme Script",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Bomb Lock", nil)

--=============================================
-- [변수 및 메인 로직]
--=============================================
local selectedTarget = nil
local bombLoopActive = false
local lockConnection = nil
local isLockPaused = false

MainTab:CreateInput({
    Name = "타겟 닉네임 입력 (Add Target)",
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
        
        selectedTarget = found
        Rayfield:Notify({Title = "타겟 설정됨", Content = found.Name .. "님이 타겟으로 설정되었습니다.", Duration = 2})
    end
})

-- 폭탄 스폰 및 컨트롤 시퀀스
local function AttachAndDetonateSequence()
    if not selectedTarget or not selectedTarget.Character then return end
    
    local targetChar = selectedTarget.Character
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    
    if not targetHRP or not myHRP then return end

    -- 1. 폭탄 스폰 (상대방 위치 근처)
    local spawnPos = targetHRP.CFrame * CFrame.new(0, -2, 0)
    task.spawn(function()
        pcall(function()
            rs.MenuToys.SpawnToyRemoteFunction:InvokeServer("Bomb", spawnPos, Vector3.zero)
        end)
    end)
    
    -- 2. 생성된 폭탄 찾아서 발밑에 부착
    local toysFolder = Workspace:WaitForChild(plr.Name .. "SpawnedInToys", 3)
    if toysFolder then
        local bomb = nil
        
        -- 방금 소환된 폭탄(사용되지 않은 것) 찾기
        for i = 1, 15 do
            for _, child in pairs(toysFolder:GetChildren()) do
                if child.Name == "Bomb" and not child:GetAttribute("Used") then
                    bomb = child
                    child:SetAttribute("Used", true) -- 중복 선택 방지
                    break
                end
            end
            if bomb then break end
            task.wait(0.1)
        end
        
        if bomb then
            local soundPart = bomb:FindFirstChild("SoundPart") or bomb:FindFirstChildWhichIsA("BasePart")
            if soundPart then
                local bombConn
                -- 폭탄을 상대방 발밑(-3)에 지속적으로 텔레포트
                bombConn = RunService.Heartbeat:Connect(function()
                    if bomb.Parent and targetHRP.Parent and not isLockPaused then
                        pcall(function()
                            rs.GrabEvents.SetNetworkOwner:FireServer(soundPart, soundPart.CFrame)
                            soundPart.CFrame = targetHRP.CFrame * CFrame.new(0, -3, 0)
                            soundPart.AssemblyLinearVelocity = Vector3.zero
                        end)
                    else
                        if bombConn then bombConn:Disconnect() end
                    end
                end)
                
                -- 폭탄이 터지기 직전까지 대기 (스폰 후 약 2.5초 대기)
                task.wait(2.5) 
                
                -- 3. 폭탄에 맞고 날아갈 수 있도록 잠시 셋오너 고정 해제
                isLockPaused = true
                if bombConn then bombConn:Disconnect() end
                
                -- 4. 폭발 및 날아가는 시간 동안 대기
                task.wait(1.5)
                
                -- 5. 다시 공중(Y:30)으로 끌어오기 위해 고정 활성화
                isLockPaused = false
            end
        end
    end
end

MainTab:CreateToggle({
    Name = "자동 폭탄 & Y:30 공중 고정 실행",
    Callback = function(v)
        if v and not selectedTarget then
            Rayfield:Notify({Title = "알림", Content = "먼저 타겟 닉네임을 입력해주세요!", Duration = 3})
            bombLoopActive = false
            return
        end
        
        bombLoopActive = v
        isLockPaused = false
        
        if v then
            -- [1] 상대방 Y좌표 30 고정 루프
            lockConnection = RunService.RenderStepped:Connect(function()
                if not bombLoopActive or isLockPaused or not selectedTarget then return end
                
                local targetChar = selectedTarget.Character
                local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                local targetHum = targetChar and targetChar:FindFirstChild("Humanoid")
                local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                
                if targetHRP and targetHum and myHRP and targetHum.Health > 0 then
                    pcall(function()
                        -- 현재 상대방의 X, Z 좌표는 유지하되 Y좌표만 30으로 고정
                        local fixedCFrame = CFrame.new(targetHRP.Position.X, 30, targetHRP.Position.Z)
                        
                        targetHRP.CFrame = fixedCFrame
                        targetHRP.AssemblyLinearVelocity = Vector3.zero
                        targetHRP.AssemblyAngularVelocity = Vector3.zero
                        
                        targetHum.PlatformStand = true
                        targetHum:ChangeState(Enum.HumanoidStateType.Physics)
                        
                        -- 셋오너로 움직임 완벽 통제
                        rs.GrabEvents.CreateGrabLine:FireServer(targetHRP, CFrame.new())
                        rs.GrabEvents.SetNetworkOwner:FireServer(targetHRP, CFrame.lookAt(myHRP.Position, targetHRP.Position))
                        rs.GrabEvents.DestroyGrabLine:FireServer(targetHRP)
                    end)
                end
            end)
            
            -- [2] 지속적인 폭탄 스폰 및 터트리기 사이클 루프
            task.spawn(function()
                while bombLoopActive do
                    if not isLockPaused and selectedTarget and selectedTarget.Character then
                        AttachAndDetonateSequence()
                    end
                    task.wait(0.5) -- 연속 스폰 간격 (너무 짧으면 서버 렉 발생)
                end
            end)
            
        else
            -- 토글 껐을 때 이벤트 정리
            if lockConnection then
                lockConnection:Disconnect()
                lockConnection = nil
            end
            isLockPaused = false
        end
    end
})

local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({
    Name = "UI 닫기 / 스크립트 재설정", 
    Callback = function() 
        Rayfield:Destroy() 
    end
})

Rayfield:Notify({Title = "로딩 완료", Content = "상대 고정 및 폭탄 자동화가 준비되었습니다.", Duration = 3})
