-- [핵심 고정 1] BodyPosition의 힘을 '무한(math.huge)'으로 설정
                local bp = Instance.new("BodyPosition")
                bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge) -- 절대 못 벗어남
                bp.P = math.huge -- 위치 도달 속도 무한대
                bp.D = 50 -- 약간의 댐핑(튕김 방지)
                bp.Parent = charHRP
                bodyPositions[player] = bp
                
                independentHoldConnections[player] = RunService.Heartbeat:Connect(function()
                    if not blobLoopT4 or not character or not character.Parent or not charHRP or not charHRP.Parent or not charHUM or charHUM.Health <= 0 then
                        if independentHoldConnections[player] then 
                            independentHoldConnections[player]:Disconnect()
                            independentHoldConnections[player] = nil
                        end
                        if anchorToggleTasks[player] then
                            task.cancel(anchorToggleTasks[player])
                            anchorToggleTasks[player] = nil
                        end
                        if ownerTags[player] then
                            ownerTags[player]:Destroy()
                            ownerTags[player] = nil
                        end
                        if charTOR then
                            charTOR.Anchored = false
                        end
                        cleanupBodyPosition(player)
                        return
                    end
                    
                    -- [핵심 고정 2] 타겟의 물리적 속도를 0으로 완전히 박제
                    charHRP.AssemblyLinearVelocity = Vector3.zero
                    charHRP.AssemblyAngularVelocity = Vector3.zero
                    if charTOR then
                        charTOR.AssemblyLinearVelocity = Vector3.zero
                        charTOR.AssemblyAngularVelocity = Vector3.zero
                    end
                    charHUM.PlatformStand = true -- 조작 불가 상태
                    
                    local currentDistance = (myHRP.Position - charHRP.Position).Magnitude
                    if currentDistance > 50 then
                        TP(player)
                        if myOriginalCF then
                            charHRP.CFrame = myOriginalCF * CFrame.new(0, OLTPValue.Y, 0)
                        end
                        BACK(myOriginalCF)
                    end
                    
                    local currentSeat = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") and plr.Character:FindFirstChildOfClass("Humanoid").SeatPart
                    local isRidingNow = currentSeat and currentSeat.Parent and currentSeat.Parent.Name == "CreatureBlobman"
                    
                    -- [핵심 속도] 리모트를 프레임당 3번씩 강제 반복 호출
                    for i = 1, 3 do
                        if not isRidingNow and not OwnerKickMODED then
                            if not charHUM.Sit and not OnlyOwner then 
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position)) 
                            end
                            if charHUM.Sit and not OnlyOwner then 
                                rs.GrabEvents.DestroyGrabLine:FireServer(charHRP) 
                            end
                            if player.IsHeld then 
                                rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position)) 
                            end
                        end
                        
                        if isRidingNow then
                            rs.GrabEvents.SetNetworkOwner:FireServer(charHRP, CFrame.lookAt(myHRP.Position, charHRP.Position))
                            if not OnlyOwner then 
                                rs.GrabEvents.DestroyGrabLine:FireServer(charHRP) 
                            end
                        end
                    end
                    
                    if blobLoopT4 and bodyPositions[player] and bodyPositions[player].Parent then
                        bodyPositions[player].Position = myHRP.Position + OLTPValue
                    end
                end)
