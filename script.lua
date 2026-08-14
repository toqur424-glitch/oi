local function startFKeyAttack(targetPlayer)
    getgenv().FKeyAttackActive = true
    fAttackTarget = targetPlayer

    local tRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if tRoot then
        fAttackBodyPos = Instance.new("BodyPosition", tRoot)
        fAttackBodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        fAttackBodyPos.D = 500
        fAttackBodyPos.P = 50000  -- ★ 강도 증가

        fAttackBodyGyro = Instance.new("BodyGyro", tRoot)
        fAttackBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        fAttackBodyGyro.D = 500
        fAttackBodyGyro.P = 50000
    end

    fAttackConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().FKeyAttackActive or not fAttackTarget then return end
        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local tgtChar = fAttackTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        local tgtHum = tgtChar and tgtChar:FindFirstChild("Humanoid")
        if not myRoot or not tgtRoot then return end

        tgtRoot.AssemblyLinearVelocity = Vector3.zero
        tgtRoot.AssemblyAngularVelocity = Vector3.zero
        if tgtHum then
            tgtHum.PlatformStand = true
            tgtHum:ChangeState(Enum.HumanoidStateType.Physics)
            tgtHum.WalkSpeed = 0
            tgtHum.JumpPower = 0
        end

        local camCF = camera.CFrame
        local targetPos = camCF.Position + camCF.LookVector * 20
        tgtRoot.CFrame = CFrame.new(targetPos)

        if fAttackBodyPos and fAttackBodyPos.Parent then
            fAttackBodyPos.Position = targetPos
        end
        if fAttackBodyGyro and fAttackBodyGyro.Parent then
            fAttackBodyGyro.CFrame = CFrame.lookAt(targetPos, myRoot.Position)
        end

        if (myRoot.Position - tgtRoot.Position).Magnitude <= 30 then
            for i = 1, 12 do  -- ★ 10→12회
                pcall(function()
                    rs.GrabEvents.CreateGrabLine:FireServer(tgtRoot, CFrame.new())
                    rs.GrabEvents.SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
                    rs.GrabEvents.DestroyGrabLine:FireServer(tgtRoot)
                end)
            end
        else
            pcall(function()
                myRoot.CFrame = tgtRoot.CFrame * CFrame.new(0, 0, -3)
            end)
        end
    end)
end
