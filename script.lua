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
    Name = "🔥 FSOF Extreme Kick Hub (Unstable Pattern)",
    LoadingTitle = "최적화 및 로딩 중...",
    LoadingSubtitle = "by Extreme Script",
    ToggleUIKeybind = "T",
    Theme = "Dark",
    ConfigurationSaving = { Enabled = false }
})

--=============================================
-- [안티그랩: 탈출 리모트 차단]
--=============================================
local CharacterEvents = ReplicatedStorage:WaitForChild("CharacterEvents", 5)
local StruggleEvent = CharacterEvents and CharacterEvents:FindFirstChild("Struggle")
local GrabEvents = ReplicatedStorage:WaitForChild("GrabEvents", 5)
local ReleaseGrab = GrabEvents and GrabEvents:FindFirstChild("ReleaseGrab")

if StruggleEvent then
    StruggleEvent.OnClientEvent:Connect(function(...) return end)
end
if ReleaseGrab then
    ReleaseGrab.OnClientEvent:Connect(function(...) return end)
end

--=============================================
-- [공통: Torso 정밀 취득 (매 프레임 재조회)]
--=============================================
local function getTorsoPart(char)
    if not char then return nil end
    local torso = char:FindFirstChild("Torso")
    if torso and torso:IsA("BasePart") then return torso end
    local upper = char:FindFirstChild("UpperTorso")
    if upper and upper:IsA("BasePart") then return upper end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    return nil
end

--=============================================
-- [GRAB 탭] - 카메라 조준 킥 그랩 (UNSTABLE 원본 패턴)
--=============================================
local GrabTab = Window:CreateTab("Grab (공격)", nil)
GrabTab:CreateSection("=== 킥 그랩 (UNSTABLE 원본 패턴: 초기 버스트 5회 + 60Hz sno) ===")

getgenv().FKeyAttackActive = false
local fAttackThread = nil
local fAttackTarget = nil
local selectedGrabPlayer = nil

local function setupFKeyAlign(targetPlayer)
    local tChar = targetPlayer and targetPlayer.Character
    local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    for _, v in pairs(tHRP:GetChildren()) do
        if v:IsA("AlignPosition") and v.Name == "FKeyAlign" then v:Destroy() end
        if v:IsA("AlignOrientation") and v.Name == "FKeyRot" then v:Destroy() end
    end

    local att0 = Instance.new("Attachment", tHRP); att0.Name = "FKeyAtt0"
    local att1 = Instance.new("Attachment", workspace.Terrain); att1.Name = "FKeyAtt1"

    local alignPos = Instance.new("AlignPosition")
    alignPos.Name = "FKeyAlign"
    alignPos.Attachment0 = att0
    alignPos.Attachment1 = att1
    alignPos.MaxForce = math.huge
    alignPos.MaxVelocity = math.huge
    alignPos.Responsiveness = math.huge
    alignPos.RigidityEnabled = true
    alignPos.Parent = tHRP

    local alignRot = Instance.new("AlignOrientation")
    alignRot.Name = "FKeyRot"
    alignRot.Attachment0 = att0
    alignRot.MaxTorque = math.huge
    alignRot.Responsiveness = math.huge
    alignRot.RigidityEnabled = true
    alignRot.Parent = tHRP
end

-- ✅ 원본 UNSTABLE sno(): SetNetOwner:FireServer(part, part.CFrame)
local function sno(part)
    if not part or not part.Parent then return end
    pcall(function()
        rs.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame)
    end)
end

-- ✅ 원본 UNSTABLE 초기 버스트: DestroyGrabLine → RenderStepped → SetOwner × 5
local function unstableBurst(part, shouldContinue)
    if not part or not part.Parent then return end
    for _ = 1, 5 do
        if shouldContinue and not shouldContinue() then break end
        pcall(function()
            rs.GrabEvents.DestroyGrabLine:FireServer(part)
        end)
        RunService.RenderStepped:Wait()
        pcall(function()
            rs.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame)
        end)
    end
end

local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer
    setupFKeyAlign(targetPlayer)

    fAttackThread = task.spawn(function()
        -- ✅ 초기 버스트 (5회)
        do
            local tChar = fAttackTarget and fAttackTarget.Character
            local targetPart = tChar and getTorsoPart(tChar)
            if targetPart then
                unstableBurst(targetPart, function()
                    return getgenv().FKeyAttackActive
                end)
            end
        end

        -- ✅ 원본 UNSTABLE 연속 패턴: 매 프레임 1회 SetOwner (~60Hz)
        while getgenv().FKeyAttackActive do
            task.wait()

            local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local tChar = fAttackTarget and fAttackTarget.Character
            local tgtRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tgtHum = tChar and tChar:FindFirstChild("Humanoid")

            if not myRoot or not tgtRoot then continue end

            tgtRoot.AssemblyLinearVelocity = Vector3.zero
            if tgtHum then tgtHum.PlatformStand = true end

            local camCF = camera.CFrame
            local holdPos = camCF.Position + camCF.LookVector * 20

            local align = tgtRoot:FindFirstChild("FKeyAlign")
            if align and align.Attachment1 then
                align.Attachment1.WorldPosition = holdPos
            end
            local rot = tgtRoot:FindFirstChild("FKeyRot")
            if rot then rot.CFrame = CFrame.Angles(0, 0, 0) end

            local targetPart = getTorsoPart(tChar)
            if not targetPart then continue end

            -- ✅ 원본 sno() 방식
            sno(targetPart)
        end
    end)
end

local function stopFKeyAttack()
    getgenv().FKeyAttackActive = false
    if fAttackThread then
        pcall(function() task.cancel(fAttackThread) end)
        fAttackThread = nil
    end
    if fAttackTarget and fAttackTarget.Character then
        local tHRP = fAttackTarget.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then
            for _, v in pairs(tHRP:GetChildren()) do
                if v:IsA("AlignPosition") and v.Name == "FKeyAlign" then v:Destroy() end
                if v:IsA("AlignOrientation") and v.Name == "FKeyRot" then v:Destroy() end
            end
        end
    end
    fAttackTarget = nil
end

GrabTab:CreateInput({
    Name = "타겟 닉네임 입력",
    PlaceholderText = "예: Player1",
    RemoveTextAfterFocusLost = true,
    Callback = function(v)
        if v == "" then return end
        local found
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(v:lower()) or (p.DisplayName and p.DisplayName:lower():find(v:lower())) then
                found = p; break
            end
        end
        if not found then
            Rayfield:Notify({Title="오류", Content="해당 유저를 찾을 수 없습니다.", Duration=2}); return
        end
        selectedGrabPlayer = found
        Rayfield:Notify({Title="타겟 설정됨", Content=found.Name.."님이 타겟으로 설정되었습니다.", Duration=2})
    end
})

GrabTab:CreateToggle({
    Name = "카메라 조준 킥 그랩 (UNSTABLE 원본 패턴)",
    Callback = function(v)
        if v and not selectedGrabPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3}); return
        end
        if v then startFKeyAttack(selectedGrabPlayer) else stopFKeyAttack() end
    end
})

--=============================================
-- [KICK 탭] - 블롭맨 오너 킥 (UNSTABLE 원본 패턴)
--=============================================
local KickTab = Window:CreateTab("Kick (블롭맨 & 판자)", nil)
local selectedKickPlayer = nil
local kickLoopRunning = false

local steppedConn, kickThread = nil, nil
local respawnConn = nil
local targetBP_HRP, targetBG_HRP = nil, nil
local targetBodies = {}

KickTab:CreateInput({
    Name = "Add Target (타겟 닉네임 입력)",
    PlaceholderText = "예: Player1",
    RemoveTextAfterFocusLost = true,
    Callback = function(v)
        if v == "" then return end
        local found
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(v:lower()) or (p.DisplayName and p.DisplayName:lower():find(v:lower())) then
                found = p; break
            end
        end
        if not found then
            Rayfield:Notify({Title="오류", Content="해당 유저를 찾을 수 없습니다.", Duration=2}); return
        end
        selectedKickPlayer = found
        Rayfield:Notify({Title="타겟 설정됨", Content=found.Name.."님이 타겟으로 설정되었습니다.", Duration=2})
    end
})

local function clearAllBodies()
    for part, bodies in pairs(targetBodies) do
        for _, b in ipairs(bodies) do
            if b and b.Parent then b:Destroy() end
        end
    end
    targetBodies = {}
    targetBP_HRP, targetBG_HRP = nil, nil
end

local function setupBodiesForTarget()
    if not selectedKickPlayer then return end
    local tChar = selectedKickPlayer.Character
    local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    clearAllBodies()
    for _, v in pairs(tChar:GetDescendants()) do
        if (v:IsA("BodyPosition") or v:IsA("BodyGyro")) and
           (v.Name:sub(1,7) == "KickBP_" or v.Name:sub(1,7) == "KickBG_") then
            v:Destroy()
        end
    end

    for _, part in ipairs(tChar:GetDescendants()) do
        if part:IsA("BasePart") then
            local bp = Instance.new("BodyPosition")
            bp.Name = "KickBP_" .. part.Name
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.P = 1000000; bp.D = 10000
            bp.Parent = part

            local bg = Instance.new("BodyGyro")
            bg.Name = "KickBG_" .. part.Name
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 1000000; bg.D = 10000
            bg.CFrame = CFrame.Angles(0, 0, 0)
            bg.Parent = part

            targetBodies[part] = {bp, bg}
            if part == tHRP then targetBP_HRP, targetBG_HRP = bp, bg end
        end
    end
end

local function startKickLoop()
    if steppedConn then steppedConn:Disconnect() end
    if kickThread then pcall(function() task.cancel(kickThread) end) end
    if respawnConn then respawnConn:Disconnect() end

    kickLoopRunning = true

    if selectedKickPlayer then
        respawnConn = selectedKickPlayer.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hrp and hum then
                while hum.Health <= 0 do task.wait(0.1) end
                task.wait(0.2)
                setupBodiesForTarget()
                local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    pcall(function()
                        hrp.CFrame = CFrame.new(myHRP.Position + Vector3.new(0, 20, 0))
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        end)
    end

    -- 전신 박제 (Stepped)
    steppedConn = RunService.Stepped:Connect(function()
        if not kickLoopRunning or not selectedKickPlayer then return end
        local myChar = plr.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = selectedKickPlayer.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not (myChar and myHRP) or not (tChar and tHRP) then return end

        if not targetBP_HRP or targetBP_HRP.Parent ~= tHRP then setupBodiesForTarget() end

        local targetPos = myHRP.Position + Vector3.new(0, 20, 0)
        local zeroCF = CFrame.Angles(0, 0, 0)
        for part, bodies in pairs(targetBodies) do
            if part and part.Parent then
                local bp, bg = bodies[1], bodies[2]
                if bp and bp.Parent then bp.Position = targetPos end
                if bg and bg.Parent then bg.CFrame = zeroCF end
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end

        local tHum = tChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = true
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- ✅ 원본 UNSTABLE 패턴 (초기 버스트 → 매 프레임 sno)
    kickThread = task.spawn(function()
        -- 초기 버스트
        do
            local tChar = selectedKickPlayer and selectedKickPlayer.Character
            local targetPart = tChar and getTorsoPart(tChar)
            if targetPart then
                unstableBurst(targetPart, function()
                    return kickLoopRunning
                end)
            end
        end

        -- 연속: 매 프레임 1회 (~60Hz), 원본과 동일
        while kickLoopRunning do
            task.wait()

            local tChar = selectedKickPlayer and selectedKickPlayer.Character
            local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not (tHRP and myHRP) then continue end

            -- 원거리 텔레포트
            if (tHRP.Position - myHRP.Position).Magnitude > 30 then
                pcall(function()
                    plr.Character:PivotTo(tHRP.CFrame * CFrame.new(0, 2, 4))
                end)
            end

            local targetPart = getTorsoPart(tChar)
            if not targetPart then continue end

            -- ✅ 원본 sno() = SetNetOwner(part, part.CFrame)
            sno(targetPart)
        end
    end)
end

local function stopKickLoop()
    kickLoopRunning = false
    if steppedConn then steppedConn:Disconnect(); steppedConn = nil end
    if kickThread then pcall(function() task.cancel(kickThread) end); kickThread = nil end
    if respawnConn then respawnConn:Disconnect(); respawnConn = nil end

    clearAllBodies()
    if selectedKickPlayer and selectedKickPlayer.Character then
        for _, v in pairs(selectedKickPlayer.Character:GetDescendants()) do
            if (v:IsA("BodyPosition") or v:IsA("BodyGyro")) and
               (v.Name:sub(1,7) == "KickBP_" or v.Name:sub(1,7) == "KickBG_") then
                v:Destroy()
            end
        end
    end
end

KickTab:CreateToggle({
    Name = "블롭맨 오너 킥 실행 (UNSTABLE 원본 패턴)",
    Callback = function(v)
        if v and not selectedKickPlayer then
            Rayfield:Notify({Title="알림", Content="먼저 타겟 닉네임을 입력해주세요!", Duration=3}); return
        end
        if v then startKickLoop() else stopKickLoop() end
    end
})

--=============================================
-- [팔레트 레그돌 (Invis) - 사인파로 부드럽게 출입]
--=============================================
KickTab:CreateToggle({
    Name = "Pallet Ragdoll (Invis) - 사인파 출입 (옆으로 95도 꺾임)",
    Flag = "Ragdoll Target",
    Default = false,
    Callback = function(Value)
        local RS = ReplicatedStorage
        local RunService = game:GetService("RunService")
        local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
        local SetNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local DestroyLine = RS:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine")
        local lpName = plr.Name
        local toysFolder = workspace:WaitForChild(lpName .. "SpawnedInToys", 5)

        local function clearAttackLoop()
            if getgenv().ragdollSteppedConn then
                getgenv().ragdollSteppedConn:Disconnect()
                getgenv().ragdollSteppedConn = nil
            end
        end

        if Value then
            if not selectedKickPlayer then
                Rayfield:Notify({Title = "알림", Content = "타겟을 먼저 입력해주세요!", Duration = 3})
                return
            end

            getgenv().palletRagdollActive = true
            getgenv().PalletForRagdoll = nil
            
            if getgenv().palletCacheConn then
                getgenv().palletCacheConn:Disconnect()
            end
            clearAttackLoop()

            if not toysFolder then
                Rayfield:Notify({Title = "오류", Content = "토이 폴더 없음 (캐릭터 재생성 후 시도)", Duration = 3})
                return
            end

            getgenv().palletCacheConn = toysFolder.ChildAdded:Connect(function(child)
                if not getgenv().palletRagdollActive then return end
                if child.Name ~= "PalletLightBrown" and child.Name ~= "PalletForRagdoll" then return end

                local soundPart = child:WaitForChild("SoundPart", 3)
                if not soundPart then return end

                pcall(function()
                    SetNetOwner:FireServer(soundPart, soundPart.CFrame)
                    DestroyLine:FireServer(soundPart)
                end)

                local partOwner = soundPart:WaitForChild("PartOwner", 1)
                if partOwner and partOwner.Value == lpName then
                    for _, v in pairs(child:GetChildren()) do
                        if v:IsA("BasePart") then
                            v.CanCollide = false
                            v.CanQuery = false
                            v.Transparency = 0.5
                            v.Massless = true
                        end
                    end

                    child.Name = "PalletForRagdoll"
                    getgenv().PalletForRagdoll = child

                    getgenv().ragdollSteppedConn = RunService.Stepped:Connect(function()
                        if not getgenv().palletRagdollActive or not child.Parent then 
                            clearAttackLoop()
                            return 
                        end

                        local tChar = selectedKickPlayer and selectedKickPlayer.Character
                        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

                        if tRoot and tHum and soundPart.Parent and tHum.Health > 0 then
                            local ragdolledVal = tHum:FindFirstChild("Ragdolled")
                            local isRagdolled = ragdolledVal and ragdolledVal.Value or false

                            if not isRagdolled then
                                local t = tick() * 20
                                local offsetY = 15 * math.sin(t)
                                soundPart.CFrame = tRoot.CFrame * CFrame.Angles(0, 0, math.rad(95)) * CFrame.new(0, offsetY, 0)
                                soundPart.AssemblyLinearVelocity = Vector3.new(0, -9e5 * math.cos(t), 0)
                                soundPart.CanCollide = false
                                soundPart.Massless = true
                            else
                                soundPart.CFrame = CFrame.new(0, 9e9, 0)
                                soundPart.AssemblyLinearVelocity = Vector3.zero
                            end
                        else
                            soundPart.CFrame = CFrame.new(0, 9e9, 0)
                            soundPart.AssemblyLinearVelocity = Vector3.zero
                        end
                    end)

                    child.AncestryChanged:Connect(function()
                        if not child.Parent then
                            clearAttackLoop()
                            getgenv().PalletForRagdoll = nil
                            if getgenv().palletRagdollActive then
                                task.wait(0.03)
                                if getgenv().spawnNewPallet then getgenv().spawnNewPallet() end
                            end
                        end
                    end)
                else
                    pcall(function() DestroyToy:FireServer(child) end)
                end
            end)

            getgenv().spawnNewPallet = function()
                if not getgenv().palletRagdollActive then return end
                if getgenv().PalletForRagdoll and getgenv().PalletForRagdoll.Parent then return end
                
                local c = plr.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if not h then return end

                task.spawn(function()
                    pcall(function()
                        RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                            "PalletLightBrown",
                            h.CFrame * CFrame.new(0, 10, 20),
                            Vector3.zero
                        )
                    end)
                end)
            end

            getgenv().spawnNewPallet()
        else
            getgenv().palletRagdollActive = false
            clearAttackLoop()

            if getgenv().palletCacheConn then
                getgenv().palletCacheConn:Disconnect()
                getgenv().palletCacheConn = nil
            end

            local pallet = getgenv().PalletForRagdoll
            if pallet and pallet.Parent then
                pcall(function() DestroyToy:FireServer(pallet) end)
            end

            getgenv().PalletForRagdoll = nil

            if toysFolder and toysFolder:FindFirstChild("PalletForRagdoll") then
                pcall(function() DestroyToy:FireServer(toysFolder.PalletForRagdoll) end)
            end
        end
    end,
})

--=============================================
-- [나머지 필수 탭]
--=============================================
local SettingsTab = Window:CreateTab("Settings", nil)
SettingsTab:CreateButton({Name = "재설정", Callback = function() Rayfield:Notify({Title="알림", Content="초기화 완료"}) end})

Rayfield:Notify({Title = "로딩 완료", Content = "UNSTABLE 원본 패턴: 초기 버스트 5회 + 매 프레임 sno (60Hz)", Duration = 3})
