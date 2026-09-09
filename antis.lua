-- FTAP V14 ANTIS - SOURCE FAMILY REBUILD
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14 ANTIS] core+shared first"); return end
if A.packs["ANTIS"] then return end
A.registerPack("ANTIS")

local S=A.shared
local page=A.makePage("ANTIS")

local function setPartsAnchored(c,v)
    if not c then return end
    local k=c:GetChildren()
    local i
    for i=1,#k do
        if k[i]:IsA("BasePart") then pcall(function() k[i].Anchored=v end) end
    end
end

local function disableRagdollJoints(c)
    if not c then return end
    local k=c:GetChildren()
    local i
    for i=1,#k do
        local p=k[i]
        if p:IsA("BasePart") and p.Name~="Head" then
            local ball=p:FindFirstChild("BallSocketConstraint")
            if ball then pcall(function() ball.Enabled=false end) end
            local limb=p:FindFirstChild("RagdollLimbPart")
            local weld=limb and limb:FindFirstChild("WeldConstraint")
            if weld then pcall(function() weld.Enabled=false end) end
        end
    end
end

A.addSection(page,"ANTI GRAB SOURCE MATRIX",
    "1=Vovange strong event-driven. 2=Defiant/Critcl IsHeld. 3=freeze-position fallback. Test separately.")

A.addToggle(page,"ag_vovange","Anti Grab 1 - VOVANGE STRONG",function()
    local connections={}
    local processing=false

    local function disconnectAll()
        local i
        for i=1,#connections do pcall(function() connections[i]:Disconnect() end) end
        connections={}
    end
    A.toggleStops["ag_vovange"]=disconnectAll

    local function process(c,h,root,head)
        if processing or not A.toggleState["ag_vovange"] then return end
        processing=true
        task.spawn(function()
            local refs=S.getRefs()
            pcall(function() h.Sit=false end)
            S.fire1(refs.Struggle,LP)
            disableRagdollJoints(c)
            root.Anchored=true

            while A.toggleState["ag_vovange"] do
                local held=LP:FindFirstChild("IsHeld")
                local owner=head and head:FindFirstChild("PartOwner")
                if not owner and not (held and held.Value) then break end

                S.fire1(refs.Struggle,LP)
                S.fire2(refs.RagdollRemote,root,0)

                local md=h.MoveDirection
                if held and held.Value and md.Magnitude>0 then
                    pcall(function() root.CFrame=root.CFrame+md*0.43 end)
                end

                RunService.Heartbeat:Wait()
            end

            pcall(function() root.Anchored=false end)
            processing=false
        end)
    end

    local function setup(c)
        if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid",5)
        local root=c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart",5)
        local head=c:FindFirstChild("Head") or c:WaitForChild("Head",5)
        if not h or not root or not head then return end

        disableRagdollJoints(c)

        connections[#connections+1]=head.ChildAdded:Connect(function(x)
            if x.Name=="PartOwner" then process(c,h,root,head) end
        end)

        local rag=h:FindFirstChild("Ragdolled")
        if rag then
            connections[#connections+1]=rag.Changed:Connect(function()
                if rag.Value then disableRagdollJoints(c) end
            end)
        end

        local weld=root:FindFirstChild("WeldHRP")
        if weld then
            connections[#connections+1]=weld.Changed:Connect(function()
                local ok,en=pcall(function() return weld.Enabled end)
                if ok and en then
                    pcall(function()
                        h.Sit=false
                        h.AutoRotate=true
                        h.HipHeight=1
                    end)
                end
            end)
        end

        if head:FindFirstChild("PartOwner") then process(c,h,root,head) end
    end

    setup(LP.Character)
    connections[#connections+1]=LP.CharacterAdded:Connect(function(c)
        task.wait(0.2)
        setup(c)
    end)

    return true
end,function()
    if A.toggleStops["ag_vovange"] then
        A.toggleStops["ag_vovange"]()
        A.toggleStops["ag_vovange"]=nil
    end
    setPartsAnchored(LP.Character,false)
end)

A.addToggle(page,"ag_defiant","Anti Grab 2 - DEFIANT/CRITCL EXACT",function()
    task.spawn(function()
        while A.toggleState["ag_defiant"] do
            local c,h,root=A.getCharacter()
            local held=LP:FindFirstChild("IsHeld")
            if c and root and held and held.Value then
                root.Anchored=true
                local refs=S.getRefs()
                while A.toggleState["ag_defiant"] and held.Value do
                    S.fire1(refs.Struggle,LP)
                    task.wait(0.001)
                end
                root.Anchored=false
            end
            task.wait()
        end
        local c,h,root=A.getCharacter()
        if root then root.Anchored=false end
    end)
    return true
end,function()
    local c,h,root=A.getCharacter()
    if root then root.Anchored=false end
end)

A.addToggle(page,"ag_freeze","Anti Grab 3 - RAGALIC FREEZE JOINT",function()
    task.spawn(function()
        local align=nil
        local att=nil
        while A.toggleState["ag_freeze"] do
            local c,h,root=A.getCharacter()
            local refs=S.getRefs()
            local held=LP:FindFirstChild("IsHeld")
            local head=c and c:FindFirstChild("Head")
            local active=(held and held.Value) or (head and head:FindFirstChild("PartOwner"))

            if root and active then
                if not align or not align.Parent then
                    att=Instance.new("Attachment")
                    att.Name="FTAPV14FreezeAttachment"
                    att.Parent=root

                    align=Instance.new("AlignPosition")
                    align.Name="FTAPV14FreezeJoint"
                    align.Mode=Enum.PositionAlignmentMode.OneAttachment
                    align.MaxForce=1000000
                    align.MaxVelocity=0
                    align.Responsiveness=200
                    align.Attachment0=att
                    align.Position=root.Position
                    align.Parent=root
                end
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                S.fire1(refs.Struggle,LP)
                S.fire0(refs.StopAllVelocity)
            else
                if align then pcall(function() align:Destroy() end); align=nil end
                if att then pcall(function() att:Destroy() end); att=nil end
            end
            RunService.Heartbeat:Wait()
        end
        if align then pcall(function() align:Destroy() end) end
        if att then pcall(function() att:Destroy() end) end
    end)
    return true
end,function() end)

A.addSection(page,"ANTI KICK SOURCE MATRIX",
    "Primary is SAHAR FirePlayerPart guard. It is the source that actually places the sticky weapon inside the character kick hitbox.")

local guard=nil

local function hideGuard(toy)
    if not toy then return end
    local d=toy:GetDescendants()
    local i
    for i=1,#d do
        if d[i]:IsA("BasePart") then
            pcall(function()
                d[i].CanTouch=false
                d[i].CanCollide=false
                d[i].CanQuery=false
                d[i].LocalTransparencyModifier=1
            end)
        end
    end
end

local function spawnGuard()
    local c,h,root=A.getCharacter()
    if not root then return nil end

    local existingKunai=S.findOwnToy("NinjaKunai")
    if existingKunai and existingKunai:FindFirstChild("StickyPart",true) then
        return existingKunai
    end

    local existingShur=S.findOwnToy("NinjaShuriken")
    if existingShur and existingShur:FindFirstChild("StickyPart",true) then
        return existingShur
    end

    local ok,toy=S.spawnToy("NinjaShuriken",root.CFrame*CFrame.new(0,12,20),Vector3.zero)
    if ok then return toy end

    ok,toy=S.spawnToy("NinjaKunai",root.CFrame*CFrame.new(0,12,20),Vector3.new(90,90,0))
    if ok then return toy end
    return nil
end

local function attachFirePlayerPart(toy)
    local refs=S.getRefs()
    local c,h,root=A.getCharacter()
    if not toy or not root or not refs.StickyPartEvent then return false end

    local sticky=toy:FindFirstChild("StickyPart",true)
    if not sticky then return false end

    local sound=toy:FindFirstChild("SoundPart",true)
    if sound and refs.SetNetworkOwner then
        local po=sound:FindFirstChild("PartOwner")
        if not po or tostring(po.Value)~=LP.Name then
            S.fire2(refs.SetNetworkOwner,sound,sound.CFrame)
        end
    end

    local firePart=root:FindFirstChild("FirePlayerPart") or root:WaitForChild("FirePlayerPart",2)
    if not firePart then return false end

    S.fire3(
        refs.StickyPartEvent,
        sticky,
        firePart,
        CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(90),math.rad(90))
    )
    hideGuard(toy)
    return true
end

A.addToggle(page,"ak_sahar","Anti Kick 1 - SAHAR FIREPLAYERPART",function()
    task.spawn(function()
        while A.toggleState["ak_sahar"] do
            if not guard or not guard.Parent then
                guard=spawnGuard()
            end

            if guard then
                attachFirePlayerPart(guard)
                local sticky=guard:FindFirstChild("StickyPart",true)
                local root=select(3,A.getCharacter())

                if not sticky or not root or (sticky.Position-root.Position).Magnitude>=20 then
                    S.destroyToy(guard)
                    guard=nil
                end
            end

            task.wait(0.3)
        end
    end)
    return true
end,function()
    if guard then S.destroyToy(guard); guard=nil end
end)

A.addToggle(page,"ak_wncly","Anti Kick 2 - WNCLY KUNAI THIGH",function()
    task.spawn(function()
        local toy=nil
        while A.toggleState["ak_wncly"] do
            local c,h,root=A.getCharacter()
            local torso=c and c:FindFirstChild("Torso")
            if torso and (not toy or not toy.Parent) then
                local cf=torso.CFrame*CFrame.new(-0.5,-torso.Size.Y/2,0)*CFrame.Angles(math.rad(-100),0,0)
                local ok
                ok,toy=S.spawnToy("NinjaKunai",cf,Vector3.new(90,90,0))
                if toy then hideGuard(toy) end
            end
            task.wait()
        end
    end)
    return true
end,function() end)

A.addToggle(page,"ak_pencil","Anti Kick 3 - PENCIL TORSO FALLBACK",function()
    task.spawn(function()
        local toy=nil
        while A.toggleState["ak_pencil"] do
            local c,h,root=A.getCharacter()
            local torso=c and c:FindFirstChild("Torso")
            local refs=S.getRefs()
            if torso and root then
                if not toy or not toy.Parent then
                    toy=S.findOwnToy("ToolPencil")
                    if not toy then
                        local ok
                        ok,toy=S.spawnToy("ToolPencil",root.CFrame*CFrame.new(0,3,-4),Vector3.zero)
                    end
                end
                local sticky=toy and toy:FindFirstChild("StickyPart",true)
                if sticky and refs.StickyPartEvent then
                    S.fire3(refs.StickyPartEvent,sticky,torso,CFrame.new(0,-1,0)*CFrame.Angles(0,math.pi,0))
                    hideGuard(toy)
                end
            end
            task.wait(0.2)
        end
    end)
    return true
end,function() end)

A.addSection(page,"SOURCE-BACKED LOCAL ANTIS",nil)

A.addToggle(page,"anti_lag_exact","Anti Lag - CharacterAndBeamMove.Disabled",function()
    local ps=LP:FindFirstChild("PlayerScripts")
    local s=ps and ps:FindFirstChild("CharacterAndBeamMove")
    if not s then A.setStatus("CharacterAndBeamMove missing."); return false end
    pcall(function() s.Disabled=true end)
    return true
end,function()
    local ps=LP:FindFirstChild("PlayerScripts")
    local s=ps and ps:FindFirstChild("CharacterAndBeamMove")
    if s then pcall(function() s.Disabled=false end) end
end)

A.addToggle(page,"anti_sticky_exact","Anti Sticky - StickyPartsTouchDetection.Disabled",function()
    local ps=LP:FindFirstChild("PlayerScripts")
    local s=ps and ps:FindFirstChild("StickyPartsTouchDetection")
    if not s then A.setStatus("StickyPartsTouchDetection missing."); return false end
    pcall(function() s.Disabled=true end)
    return true
end,function()
    local ps=LP:FindFirstChild("PlayerScripts")
    local s=ps and ps:FindFirstChild("StickyPartsTouchDetection")
    if s then pcall(function() s.Disabled=false end) end
end)


A.addSection(page,"ANTI GUCCI / FREEZE DEFENCE",
    "Defensive hub controls. Recent Gucci code repeatedly forces ragdoll while seated; recent freeze-like packet code uses sustained ExtendGrabLine traffic. These controls protect/observe your local client without changing the old loader.")

local antiGucciConnections={}
local antiGucciStats={foreignBlobEjects=0,cameraRestores=0,packetAlerts=0,lineAlerts=0,ragdollRepairs=0}
local antiFreezeQuietUntil=0
local antiFreezeBeamWasDisabled=nil
local antiFreezeEventTimes={}
local antiFreezeByteThreshold=8192
local antiFreezeRateThreshold=80
local antiFreezeLastSource="unknown"

local function antiGucciDisconnectAll()
    for i=1,#antiGucciConnections do
        pcall(function() antiGucciConnections[i]:Disconnect() end)
    end
    antiGucciConnections={}
end

local function ownToyFolderName()
    return LP.Name.."SpawnedInToys"
end

local function isForeignBlobSeat(seat)
    if not seat then return false,nil end
    local blob=seat:FindFirstAncestor("CreatureBlobman")
    if not blob then return false,nil end
    local folder=blob.Parent
    local foreign=(not folder) or folder.Name~=ownToyFolderName()
    return foreign,blob
end

local function repairLocalRagdoll(c,h,root)
    if not c or not h or not root then return end
    disableRagdollJoints(c)
    pcall(function()
        h.PlatformStand=false
        h.AutoRotate=true
        h.Sit=false
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end)
    antiGucciStats.ragdollRepairs=antiGucciStats.ragdollRepairs+1
end

local function restoreCameraToHumanoid()
    local cam=Workspace.CurrentCamera
    local c,h=A.getCharacter()
    if not cam or not h then return end
    local subject=cam.CameraSubject
    if subject and subject~=h then
        local underBlob=false
        pcall(function()
            underBlob=subject:FindFirstAncestor("CreatureBlobman")~=nil
        end)
        if underBlob or (h.SeatPart and h.SeatPart:FindFirstAncestor("CreatureBlobman")) then
            pcall(function() cam.CameraSubject=h end)
            antiGucciStats.cameraRestores=antiGucciStats.cameraRestores+1
        end
    end
end

local function setCharacterBeamDisabled(v)
    local ps=LP:FindFirstChild("PlayerScripts")
    local beam=ps and ps:FindFirstChild("CharacterAndBeamMove")
    if not beam then return false end
    pcall(function() beam.Disabled=v end)
    return true
end

local function triggerFreezeShield(reason)
    antiFreezeQuietUntil=os.clock()+3.0
    setCharacterBeamDisabled(true)
    A.setStatus("ANTI FREEZE triggered: "..tostring(reason).." source="..tostring(antiFreezeLastSource).."; CharacterAndBeamMove disabled")
end

local function resolvePossibleSource(args)
    for i=1,#args do
        local v=args[i]
        if typeof(v)=="Instance" then
            if v:IsA("Player") then return v.Name end
            local model=v:IsA("Model") and v or v:FindFirstAncestorOfClass("Model")
            local plr=model and Players:GetPlayerFromCharacter(model)
            if plr then return plr.Name end
        end
    end
    return "unknown"
end

A.addToggle(page,"anti_gucci_all","Anti Gucci - ALL LOCAL DEFENCES",function()
    antiGucciDisconnectAll()
    local function setupCharacter(c)
        if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid",5)
        local root=c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart",5)
        if not h or not root then return end

        antiGucciConnections[#antiGucciConnections+1]=h:GetPropertyChangedSignal("SeatPart"):Connect(function()
            if not A.toggleState["anti_gucci_all"] then return end
            local seat=h.SeatPart
            local foreign,blob=isForeignBlobSeat(seat)
            if foreign and blob then
                antiGucciStats.foreignBlobEjects=antiGucciStats.foreignBlobEjects+1
                task.defer(function()
                    repairLocalRagdoll(c,h,root)
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                    restoreCameraToHumanoid()
                end)
            end
        end)

        local rag=h:FindFirstChild("Ragdolled")
        if rag then
            antiGucciConnections[#antiGucciConnections+1]=rag.Changed:Connect(function()
                if not A.toggleState["anti_gucci_all"] then return end
                local foreign=isForeignBlobSeat(h.SeatPart)
                if foreign and rag.Value then repairLocalRagdoll(c,h,root) end
            end)
        end
    end

    setupCharacter(LP.Character)
    antiGucciConnections[#antiGucciConnections+1]=LP.CharacterAdded:Connect(function(c)
        task.wait(0.15)
        setupCharacter(c)
    end)

    antiGucciConnections[#antiGucciConnections+1]=RunService.Heartbeat:Connect(function()
        if not A.toggleState["anti_gucci_all"] then return end
        restoreCameraToHumanoid()
        local c,h,root=A.getCharacter()
        if c and h and root then
            local held=LP:FindFirstChild("IsHeld")
            local head=c:FindFirstChild("Head")
            local owner=head and head:FindFirstChild("PartOwner")
            if (held and held.Value) or owner then
                local refs=S.getRefs()
                S.fire1(refs.Struggle,LP)
                repairLocalRagdoll(c,h,root)
            end
        end
    end)
    A.toggleStops["anti_gucci_all"]=antiGucciDisconnectAll
    return true
end,function()
    antiGucciDisconnectAll()
end)

A.addToggle(page,"anti_gucci_camera","Anti Gucci - CAMERA/SEAT RECOVERY",function()
    local conn=RunService.Heartbeat:Connect(function()
        if A.toggleState["anti_gucci_camera"] then restoreCameraToHumanoid() end
    end)
    A.toggleStops["anti_gucci_camera"]=function() pcall(function() conn:Disconnect() end) end
    return true
end,function()
    if A.toggleStops["anti_gucci_camera"] then A.toggleStops["anti_gucci_camera"](); A.toggleStops["anti_gucci_camera"]=nil end
end)

A.addToggle(page,"anti_freeze_auto","Auto Anti Freeze - PACKET/LINE DETECTOR",function()
    local refs=S.getRefs()
    if not refs.ExtendGrabLine then A.setStatus("ExtendGrabLine missing for detector."); return false end
    local conns={}
    local function observe(remoteName,...)
        if not A.toggleState["anti_freeze_auto"] then return end
        local now=os.clock()
        local args={...}
        antiFreezeLastSource=resolvePossibleSource(args)
        local bytes=0
        for i=1,#args do if type(args[i])=="string" then bytes=bytes+#args[i] end end
        antiFreezeEventTimes[#antiFreezeEventTimes+1]=now
        local cut=now-1
        local j=1
        while j<=#antiFreezeEventTimes and antiFreezeEventTimes[j]<cut do j=j+1 end
        if j>1 then
            local n={}
            for k=j,#antiFreezeEventTimes do n[#n+1]=antiFreezeEventTimes[k] end
            antiFreezeEventTimes=n
        end
        local rate=#antiFreezeEventTimes
        if bytes>=antiFreezeByteThreshold then
            antiGucciStats.packetAlerts=antiGucciStats.packetAlerts+1
            triggerFreezeShield(remoteName.." payload="..tostring(bytes).."B")
        elseif rate>=antiFreezeRateThreshold then
            antiGucciStats.lineAlerts=antiGucciStats.lineAlerts+1
            triggerFreezeShield(remoteName.." rate="..tostring(rate).."/s")
        end
    end
    conns[#conns+1]=refs.ExtendGrabLine.OnClientEvent:Connect(function(...) observe("ExtendGrabLine",...) end)
    if refs.CreateGrabLine then
        conns[#conns+1]=refs.CreateGrabLine.OnClientEvent:Connect(function(...) observe("CreateGrabLine",...) end)
    end
    local hb=RunService.Heartbeat:Connect(function()
        if not A.toggleState["anti_freeze_auto"] then return end
        if antiFreezeQuietUntil>0 and os.clock()>antiFreezeQuietUntil then
            antiFreezeQuietUntil=0
            if not A.toggleState["anti_lag_exact"] then
                setCharacterBeamDisabled(false)
                A.setStatus("ANTI FREEZE quiet window passed; CharacterAndBeamMove restored")
            else
                A.setStatus("ANTI FREEZE quiet window passed; manual Anti Lag remains enabled")
            end
        end
    end)
    A.toggleStops["anti_freeze_auto"]=function()
        for i=1,#conns do pcall(function() conns[i]:Disconnect() end) end
        pcall(function() hb:Disconnect() end)
        antiFreezeEventTimes={}
        antiFreezeQuietUntil=0
        if not A.toggleState["anti_lag_exact"] then setCharacterBeamDisabled(false) end
    end
    return true
end,function()
    if A.toggleStops["anti_freeze_auto"] then A.toggleStops["anti_freeze_auto"](); A.toggleStops["anti_freeze_auto"]=nil end
end)

A.addSlider(page,"Anti Freeze payload threshold KB",4,128,1,8,function(v) antiFreezeByteThreshold=math.floor(v*1024) end)
A.addSlider(page,"Anti Freeze event-rate / sec",20,240,5,80,function(v) antiFreezeRateThreshold=v end)

A.addButton(page,"ANTI GUCCI / FREEZE STATUS",function()
    local c,h,root=A.getCharacter()
    local seat=h and h.SeatPart
    local foreign,blob=isForeignBlobSeat(seat)
    local held=LP:FindFirstChild("IsHeld")
    local head=c and c:FindFirstChild("Head")
    local po=head and head:FindFirstChild("PartOwner")
    A.setStatus(
        "AntiGucci foreignSeat="..tostring(foreign)..
        " blob="..tostring(blob and blob:GetFullName() or "nil")..
        " held="..tostring(held and held.Value or false)..
        " PartOwner="..tostring(po and po.Value or "nil")..
        " eject="..antiGucciStats.foreignBlobEjects..
        " camera="..antiGucciStats.cameraRestores..
        " packetAlerts="..antiGucciStats.packetAlerts..
        " rateAlerts="..antiGucciStats.lineAlerts..
        " source="..tostring(antiFreezeLastSource)
    )
end)

A.setStatus("V14R3 ANTIS loaded: V14 source families + Anti Gucci + sustained-freeze detector.")
print("[FTAP V14R3 ANTIS] READY")
