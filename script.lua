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

Rayfield:Notify({Title = "로딩 완료", Content = "빈 스크립트 준비됨 - 안티그랩을 구현하세요", Duration = 3})

--=============================================
-- [안티 그랩 구현]
--=============================================
-- 사용할 원격 이벤트들을 미리 참조 (필요시 waitForChild)
local CharacterEvents = rs:WaitForChild("CharacterEvents")
local GrabEvents = rs:WaitForChild("GrabEvents")
local StruggleEvent = CharacterEvents:WaitForChild("Struggle")
local RagdollRemote = CharacterEvents:WaitForChild("RagdollRemote")
local SetNetworkOwner = GrabEvents:WaitForChild("SetNetworkOwner")
local DestroyGrabLine = GrabEvents:WaitForChild("DestroyGrabLine")
local PlayerEvents = rs:WaitForChild("PlayerEvents")
local StickyPartEvent = PlayerEvents:WaitForChild("StickyPartEvent") -- 참고용

-- 안티그랩 상태 전역
_G.AntiGrab = false
local antiGrabConnections = {} -- 연결 해제용 리스트
local antiGrabCharAddedConn = nil -- CharacterAdded 연결 별도 관리

-- 캐릭터 관련 객체 가져오기 (리스폰 시 갱신)
local function getCharacterParts()
    local char = plr.Character
    if not char then return nil, nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    local head = char:FindFirstChild("Head")
    local isHeld = plr:FindFirstChild("IsHeld")
    return char, hrp, hum, head, isHeld
end

-- 그랩 탈출 헬퍼 (여러 방법을 조합)
local function escapeGrab(char, hrp, hum)
    if not char or not hrp or not hum then return end
    task.spawn(function()
        -- 1. 지속적으로 Struggle & Ragdoll 발사
        while _G.AntiGrab and char.Parent and plr.Character == char do
            pcall(function()
                StruggleEvent:FireServer(plr)
                RagdollRemote:FireServer(hrp, 0)
            end)
            -- 2. Anchored 로 잠시 고정 + 이동 벡터로 탈출 시도
            hrp.Anchored = true
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            -- 이동 방향으로 약간 이동 (그랩이 풀리도록)
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + moveDir * 0.43
            end
            task.wait()
        end
        if hrp then
            hrp.Anchored = false
        end
    end)
end

-- Head에 PartOwner 추가 감지
local function onPartOwnerAdded(child)
    if child.Name == "PartOwner" and _G.AntiGrab then
        local char, hrp, hum = getCharacterParts()
        if char and hrp and hum then
            escapeGrab(char, hrp, hum)
        end
    end
end

-- IsHeld 변화 감지
local function onIsHeldChanged(value)
    if value and _G.AntiGrab then
        local char, hrp, hum = getCharacterParts()
        if char and hrp and hum then
            escapeGrab(char, hrp, hum)
        end
    else
        -- 그랩 해제되면 Anchored 해제
        local char, hrp = getCharacterParts()
        if char and hrp then
            hrp.Anchored = false
        end
    end
end

-- 캐릭터 리스폰 시 재연결
local function onCharacterAdded(char)
    task.wait(0.5) -- 캐릭터 완전 로드 대기
    local head = char:WaitForChild("Head", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    local isHeld = plr:FindFirstChild("IsHeld")

    if not isHeld then
        isHeld = plr:WaitForChild("IsHeld", 5)
    end

    -- 기존 연결 해제
    for _, conn in ipairs(antiGrabConnections) do
        conn:Disconnect()
    end
    table.clear(antiGrabConnections)

    if _G.AntiGrab then
        table.insert(antiGrabConnections, head.ChildAdded:Connect(onPartOwnerAdded))
        table.insert(antiGrabConnections, isHeld.Changed:Connect(onIsHeldChanged))
    end
end

-- 토글 콜백
local function toggleAntiGrab(value)
    _G.AntiGrab = value

    if value then
        -- 현재 캐릭터에 연결
        local char = plr.Character
        if char then
            onCharacterAdded(char)
        end
        -- 이후 리스폰 대비 연결 (중복 방지 위해 CharacterAdded 연결 저장)
        if not antiGrabCharAddedConn then
            antiGrabCharAddedConn = plr.CharacterAdded:Connect(onCharacterAdded)
        end
        Rayfield:Notify({Title = "안티 그랩", Content = "활성화됨", Duration = 2})
    else
        -- 연결 해제
        for _, conn in ipairs(antiGrabConnections) do
            conn:Disconnect()
        end
        table.clear(antiGrabConnections)
        if antiGrabCharAddedConn then
            antiGrabCharAddedConn:Disconnect()
            antiGrabCharAddedConn = nil
        end
        -- 현재 캐릭터 Anchored 해제
        local char, hrp = getCharacterParts()
        if char and hrp then
            hrp.Anchored = false
        end
        Rayfield:Notify({Title = "안티 그랩", Content = "비활성화됨", Duration = 2})
    end
end

-- Settings 탭에 토글 추가
SettingsTab:CreateToggle({
    Name = "안티 그랩",
    Default = false,
    Callback = toggleAntiGrab
})

--=============================================
-- [추가: 블롭맨 방어 (선택 사항)]
--=============================================
-- 블롭맨에 앉았을 때 자동으로 내려오기 (CreatureDrop 사용)
-- 실제 블롭 구조에 따라 조정 필요
local function onSeatChanged()
    if _G.AntiGrab then
        local char = plr.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and hum.SeatPart then
            local seatParent = hum.SeatPart.Parent
            if seatParent and seatParent.Name == "CreatureBlobman" then
                local blob = seatParent
                local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                if script then
                    local drop = script:FindFirstChild("CreatureDrop")
                    local detector = blob:FindFirstChild("LeftDetector") or blob:FindFirstChild("RightDetector")
                    local weld = detector and (detector:FindFirstChild("LeftWeld") or detector:FindFirstChild("RightWeld"))
                    if drop and weld then
                        drop:FireServer(weld, hum.RootPart)
                    end
                end
                -- 강제로 Sit 해제
                hum.Sit = false
            end
        end
    end
end

-- 안티그랩 토글에 SeatPart 감지 연결 (활성 시)
-- onCharacterAdded 함수에 SeatPart 감지를 추가하려면 다음을 추가하세요.
-- (원하면 아래 주석을 해제해서 사용 가능)
-- local function onSeatChangedWrapper()
--     onSeatChanged()
-- end
-- onCharacterAdded 함수에서 hum:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChangedWrapper)를 추가하면 됩니다.
-- 아래는 기본적으로 연결하지 않고, 필요시 직접 onCharacterAdded에 추가하는 예시입니다.

-- (필요시 주석 해제)
-- local function onCharacterAdded(char)
--     ... 기존 코드 ...
--     if _G.AntiGrab then
--         table.insert(antiGrabConnections, hum:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged))
--     end
-- end
