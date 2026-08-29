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
-- [탭 생성 - 원하는 대로 수정하세요]
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
-- GrabTab:CreateSection("=== 섹션 이름 ===")
-- GrabTab:CreateToggle({...})
-- GrabTab:CreateButton({...})
-- GrabTab:CreateKeybind({...})

local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
-- KickTab:CreateInput({...})
-- KickTab:CreateToggle({...})

local SettingsTab = Window:CreateTab("Settings", nil)
-- SettingsTab:CreateButton({Name = "재설정", Callback = function() end})

Rayfield:Notify({Title = "로딩 완료", Content = "안티그랩이 포함된 버전입니다.", Duration = 3})

--=============================================
-- [안티 그랩 구현 (즉시 탈출 + 7스터드 점프)]
--=============================================
local CharacterEvents = rs:WaitForChild("CharacterEvents")
local GrabEvents = rs:WaitForChild("GrabEvents")
local StruggleEvent = CharacterEvents:WaitForChild("Struggle")
local RagdollRemote = CharacterEvents:WaitForChild("RagdollRemote")

_G.AntiGrab = false
local antiGrabConnections = {}
local antiGrabCharAddedConn = nil
local lastPartOwnerTime = 0
local isEscaping = false

local function getCharacterParts()
    local char = plr.Character
    if not char then return nil, nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    local head = char:FindFirstChild("Head")
    local isHeld = plr:FindFirstChild("IsHeld")
    return char, hrp, hum, head, isHeld
end

local function escapeGrab(char, hrp, hum)
    if not char or not hrp or not hum then return end
    task.spawn(function()
        -- 1. 즉시 위로 튀는 힘 부여 (약 7스터드 높이)
        local bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.new(0, 52, 0)  -- 52 스터드/초 → 약 7스터드 높이
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Parent = hrp
        task.delay(0.15, function()
            if bv.Parent then bv:Destroy() end
        end)

        -- 2. 빠르게 Struggle & Ragdoll 발사 (0.05초 간격)
        local startTime = tick()
        local maxDuration = 1.5 -- 최대 1.5초 동안 시도
        while _G.AntiGrab and char.Parent and plr.Character == char and (tick() - startTime) < maxDuration do
            pcall(function()
                StruggleEvent:FireServer(plr)
                RagdollRemote:FireServer(hrp, 0)
            end)
            task.wait(0.05)
        end

        -- 3. 마무리 정리
        if hrp and hrp.Parent then
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

local function onPartOwnerAdded(child)
    if child.Name == "PartOwner" and _G.AntiGrab and (tick() - lastPartOwnerTime) > 0.3 then
        lastPartOwnerTime = tick()
        local char, hrp, hum = getCharacterParts()
        if char and hrp and hum then
            escapeGrab(char, hrp, hum)
        end
    end
end

local function onIsHeldChanged(value)
    if value and _G.AntiGrab and not isEscaping then
        isEscaping = true
        local char, hrp, hum = getCharacterParts()
        if char and hrp and hum then
            escapeGrab(char, hrp, hum)
        end
        task.delay(0.4, function() isEscaping = false end)
    else
        local char, hrp = getCharacterParts()
        if char and hrp then
            hrp.Anchored = false
        end
    end
end

local function onCharacterAdded(char)
    task.wait(0.5)
    local head = char:WaitForChild("Head", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    local isHeld = plr:FindFirstChild("IsHeld")
    if not isHeld then isHeld = plr:WaitForChild("IsHeld", 5) end

    for _, conn in ipairs(antiGrabConnections) do
        conn:Disconnect()
    end
    table.clear(antiGrabConnections)

    if _G.AntiGrab then
        table.insert(antiGrabConnections, head.ChildAdded:Connect(onPartOwnerAdded))
        table.insert(antiGrabConnections, isHeld.Changed:Connect(onIsHeldChanged))
    end
end

local function toggleAntiGrab(value)
    _G.AntiGrab = value
    if value then
        local char = plr.Character
        if char then onCharacterAdded(char) end
        if not antiGrabCharAddedConn then
            antiGrabCharAddedConn = plr.CharacterAdded:Connect(onCharacterAdded)
        end
        Rayfield:Notify({Title = "안티 그랩", Content = "활성화됨 (즉시 탈출 + 7스터드 점프)", Duration = 2})
    else
        for _, conn in ipairs(antiGrabConnections) do conn:Disconnect() end
        table.clear(antiGrabConnections)
        if antiGrabCharAddedConn then
            antiGrabCharAddedConn:Disconnect()
            antiGrabCharAddedConn = nil
        end
        local char, hrp = getCharacterParts()
        if char and hrp then hrp.Anchored = false end
        Rayfield:Notify({Title = "안티 그랩", Content = "비활성화됨", Duration = 2})
    end
end

SettingsTab:CreateToggle({
    Name = "안티 그랩",
    Default = false,
    Callback = toggleAntiGrab
})
