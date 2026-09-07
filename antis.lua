-- FTAP V13 ANTIS PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end

local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V13 ANTIS] core+shared first"); return end
if A.packs["ANTIS"] then return end
A.registerPack("ANTIS")

local S=A.shared
local page=A.makePage("ANTIS")
local savedVoid=Workspace.FallenPartsDestroyHeight
local effectsSaved={}

local function setAnchored(character,value)
    if not character then return end
    local k=character:GetChildren()
    local i
    for i=1,#k do
        if k[i]:IsA("BasePart") then
            pcall(function() k[i].Anchored=value end)
        end
    end
end

local function stopLocalVelocity()
    local c,h,r=A.getCharacter()
    if r then
        pcall(function()
            r.AssemblyLinearVelocity=Vector3.new(0,0,0)
            r.AssemblyAngularVelocity=Vector3.new(0,0,0)
        end)
    end
end

A.addSection(page,"Anti Grab",
    "AUTO is aggressive. Source 1 mirrors old Cosmic exactly. Source 2 mirrors Critcl's rapid IsHeld struggle loop.")

A.addToggle(page,"anti_grab_auto","Anti Grab AUTO aggressive",function()
    task.spawn(function()
        local anchored=false

        while A.toggleState["anti_grab_auto"] do
            local refs=S.getRefs()
            local c,h,root=A.getCharacter()

            if c and root then
                local held=LP:FindFirstChild("IsHeld")
                local head=c:FindFirstChild("Head")
                local owner=head and head:FindFirstChild("PartOwner")
                local active=(held and held.Value==true) or owner~=nil

                if active then
                    S.fire0(refs.Struggle)
                    S.fire1(refs.Struggle,LP)
                    S.fire0(refs.StopAllVelocity)
                    stopLocalVelocity()
                    setAnchored(c,true)
                    anchored=true
                elseif anchored then
                    setAnchored(c,false)
                    anchored=false
                end
            end

            task.wait(0.001)
        end

        setAnchored(LP.Character,false)
    end)

    return true
end,function()
    setAnchored(LP.Character,false)
end)

A.addToggle(page,"anti_grab_cosmic","Anti Grab 1 - COSMIC exact",function()
    task.spawn(function()
        while A.toggleState["anti_grab_cosmic"] do
            local refs=S.getRefs()
            local c,h,root=A.getCharacter()

            if c and c:FindFirstChild("Head") then
                local owner=c.Head:FindFirstChild("PartOwner")

                if owner then
                    S.fire0(refs.Struggle)
                    S.fire0(refs.StopAllVelocity)
                    setAnchored(c,true)

                    local held=LP:FindFirstChild("IsHeld")

                    while A.toggleState["anti_grab_cosmic"] and held and held.Value==true do
                        task.wait()
                    end

                    setAnchored(c,false)
                end
            end

            RunService.Heartbeat:Wait()
        end

        setAnchored(LP.Character,false)
    end)

    return true
end,function()
    setAnchored(LP.Character,false)
end)

A.addToggle(page,"anti_grab_critcl","Anti Grab 2 - CRITCL rapid",function()
    task.spawn(function()
        while A.toggleState["anti_grab_critcl"] do
            local refs=S.getRefs()
            local held=LP:FindFirstChild("IsHeld")

            if held and held.Value==true then
                local c=LP.Character
                setAnchored(c,true)

                while A.toggleState["anti_grab_critcl"] and held.Value==true do
                    S.fire1(refs.Struggle,LP)
                    task.wait(0.001)
                end

                setAnchored(c,false)
            end

            task.wait(0.002)
        end

        setAnchored(LP.Character,false)
    end)

    return true
end,function()
    setAnchored(LP.Character,false)
end)

A.addSection(page,"Anti Kick",
    "Rescue is Cosmic-source behavior. Guard toy is placed inside lower torso, hidden locally, and made non-queryable so it is much harder to grab.")

local guardToy=nil
local guardName=nil

local function getOrSpawnGuardToy()
    local toy,name=S.findAnyWeapon()

    if toy then
        return toy,name
    end

    local c,h,root=A.getCharacter()
    local torso=c and (c:FindFirstChild("Torso") or c:FindFirstChild("LowerTorso"))

    if not torso then return nil,nil end

    local ok
    ok,toy=S.spawnToy(
        "NinjaKunai",
        torso.CFrame*CFrame.new(0,-0.7,0),
        Vector3.new(90,90,0)
    )
    name="NinjaKunai"

    if not toy then
        ok,toy=S.spawnToy(
            "NinjaShuriken",
            torso.CFrame*CFrame.new(0,-0.7,0),
            Vector3.new(90,90,0)
        )
        name="NinjaShuriken"
    end

    return toy,name
end

local function ensureInternalGuard()
    local refs=S.getRefs()
    local c,h,root=A.getCharacter()

    if not c or not root then
        return false,"character missing"
    end

    local torso=c:FindFirstChild("Torso") or c:FindFirstChild("LowerTorso") or root
    local toy,name=getOrSpawnGuardToy()

    if not toy then
        return false,"Kunai/Shuriken spawn unavailable"
    end

    guardToy=toy
    guardName=name

    local sticky=toy:FindFirstChild("StickyPart",true)

    if not sticky then
        return false,name.." StickyPart missing"
    end

    local weld=sticky:FindFirstChild("StickyWeld")
    local attached=weld and (weld.Part1==torso or weld.Part0==torso)

    if not attached and refs.StickyPartEvent then
        -- Lower-torso internal placement. If the server rejects Torso,
        -- fallback to source-like Right Leg while still hiding/query-disabling it.
        local ok=S.fire3(
            refs.StickyPartEvent,
            sticky,
            torso,
            CFrame.new(0,-0.75,0)*CFrame.Angles(math.rad(-90),0,math.rad(180))
        )

        task.wait(0.05)
        weld=sticky:FindFirstChild("StickyWeld")
        attached=weld and (weld.Part1==torso or weld.Part0==torso)

        if not attached then
            local leg=c:FindFirstChild("Right Leg")

            if leg then
                S.fire3(
                    refs.StickyPartEvent,
                    sticky,
                    leg,
                    CFrame.new(0,0.75,0)*CFrame.Angles(math.rad(-100),0,math.rad(180))
                )
            end
        end
    end

    S.hideGuardToy(toy)
    return true,name
end

A.addToggle(page,"anti_kick","Anti Kick + INTERNAL guard",function()
    task.spawn(function()
        while A.toggleState["anti_kick"] do
            ensureInternalGuard()

            local refs=S.getRefs()
            local c,h,root=A.getCharacter()

            if c and h and root then
                local fpp=root:FindFirstChild("FirePlayerPart")
                local owner=fpp and fpp:FindFirstChild("PartOwner")

                if owner and tostring(owner.Value)~=LP.Name then
                    S.fire2(refs.RagdollRemote,root,0)
                    task.wait(0.1)
                    S.fire0(refs.Struggle)
                    S.fire1(refs.Struggle,LP)

                    pcall(function()
                        h.PlatformStand=false
                        h.Sit=false
                        h:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end)
                end
            end

            task.wait(0.08)
        end
    end)

    return true
end,function() end)

A.addButton(page,"Guard weapon RECON",function()
    if not guardToy then
        local ok,name=ensureInternalGuard()
        if not ok then return A.setStatus("Guard failed: "..tostring(name)) end
    end

    local sticky=guardToy and guardToy:FindFirstChild("StickyPart",true)
    local weld=sticky and sticky:FindFirstChild("StickyWeld")
    local part="nil"

    if weld then
        if weld.Part1 then part=weld.Part1.Name
        elseif weld.Part0 then part=weld.Part0.Name end
    end

    A.setStatus(
        "guard="..tostring(guardName)..
        " sticky="..tostring(sticky~=nil)..
        " attached="..part
    )
end)

A.addSection(page,"Anti Blob / Explosion / Void / Fire",nil)

A.addToggle(page,"anti_blob","Anti Blobman SAFE",function()
    task.spawn(function()
        while A.toggleState["anti_blob"] do
            local own=S.mountedBlob()
            local d=Workspace:GetDescendants()
            local i,j

            for i=1,#d do
                local b=d[i]

                if b:IsA("Model") and b.Name=="CreatureBlobman" and b~=own then
                    local bd=b:GetDescendants()

                    for j=1,#bd do
                        if bd[j].Name=="AttachPlayer" then
                            pcall(function() bd[j]:Destroy() end)
                        elseif bd[j]:IsA("BasePart") then
                            pcall(function() bd[j].Massless=false end)
                        end
                    end
                end
            end

            task.wait(0.2)
        end
    end)

    return true
end,function() end)

A.addToggle(page,"anti_explosion","Anti Explosion consensus",function()
    local function neut(x)
        if x:IsA("Explosion") then
            pcall(function() x.BlastPressure=0 end)
        end
    end

    local d=Workspace:GetDescendants()
    local i
    for i=1,#d do neut(d[i]) end

    local conn=Workspace.DescendantAdded:Connect(neut)
    A.toggleStops["anti_explosion"]=function() conn:Disconnect() end

    task.spawn(function()
        local did=false

        while A.toggleState["anti_explosion"] do
            local c,h,root=A.getCharacter()
            local on=false

            if c and h then
                local rag=h:FindFirstChild("Ragdolled")
                local arm=c:FindFirstChild("Right Arm")

                on=(rag and rag.Value==true) or
                   (arm and arm:FindFirstChild("RagdollLimbPart")~=nil)

                setAnchored(c,on)
                did=on
            end

            task.wait(0.01)
        end

        if did then setAnchored(LP.Character,false) end
    end)

    return true
end,function()
    if A.toggleStops["anti_explosion"] then
        A.toggleStops["anti_explosion"]()
        A.toggleStops["anti_explosion"]=nil
    end

    setAnchored(LP.Character,false)
end)

A.addToggle(page,"anti_void","Anti Void",function()
    pcall(function() Workspace.FallenPartsDestroyHeight=0/0 end)

    task.spawn(function()
        local safe=nil

        while A.toggleState["anti_void"] do
            local c,h,r=A.getCharacter()

            if r then
                if r.Position.Y>-50 and h and h.FloorMaterial~=Enum.Material.Air then
                    safe=r.CFrame
                end

                if r.Position.Y<-100 and safe then
                    r.AssemblyLinearVelocity=Vector3.new(0,0,0)
                    r.CFrame=safe+Vector3.new(0,4,0)
                end
            end

            task.wait(0.05)
        end
    end)

    return true
end,function()
    pcall(function() Workspace.FallenPartsDestroyHeight=savedVoid end)
end)

A.addToggle(page,"anti_fire","Anti Fire local",function()
    task.spawn(function()
        while A.toggleState["anti_fire"] do
            local c,h,r=A.getCharacter()

            if r then
                local d=r:GetDescendants()
                local i

                for i=1,#d do
                    local x=d[i]

                    if x.Name=="FireLight" or
                       x.Name=="FireParticleEmitter" or
                       x:IsA("Fire") then
                        pcall(function() x:Destroy() end)
                    end
                end
            end

            task.wait(0.05)
        end
    end)

    return true
end,function() end)

A.addToggle(page,"anti_lag_local","Anti Lag local effects",function()
    task.spawn(function()
        while A.toggleState["anti_lag_local"] do
            local d=Workspace:GetDescendants()
            local i

            for i=1,#d do
                local x=d[i]

                if x:IsA("ParticleEmitter") or
                   x:IsA("Trail") or
                   x:IsA("Beam") then
                    if effectsSaved[x]==nil then effectsSaved[x]=x.Enabled end
                    pcall(function() x.Enabled=false end)
                end
            end

            task.wait(0.5)
        end
    end)

    return true
end,function()
    for x,v in pairs(effectsSaved) do
        if x.Parent then pcall(function() x.Enabled=v end) end
    end

    effectsSaved={}
end)

A.setStatus("V13 ANTIS loaded: 3 Anti-Grab families + internal Anti-Kick guard.")
print("[FTAP V13 ANTIS] READY")
