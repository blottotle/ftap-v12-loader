-- FTAP V12 ANTIS PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V12 ANTIS] core+shared first"); return end
if A.packs["ANTIS"] then return end
A.registerPack("ANTIS")
local S=A.shared
local page=A.makePage("ANTIS")
local anchored=false
local savedVoid=Workspace.FallenPartsDestroyHeight
local effectsSaved={}

A.addSection(page,"Consensus Anti Grab","IsHeld/PartOwner + Struggle + StopAllVelocity + temporary anchor.")
A.addToggle(page,"anti_grab","CONSENSUS Anti Grab",function()
    task.spawn(function()
        while A.toggleState["anti_grab"] do
            local r=S.getRefs()
            local c,h,root=A.getCharacter()
            if c and root then
                local held=LP:FindFirstChild("IsHeld")
                local head=c:FindFirstChild("Head")
                local owner=head and head:FindFirstChild("PartOwner")
                local active=(held and held.Value==true) or (owner and tostring(owner.Value)~=LP.Name)
                if active then
                    S.fire0(r.Struggle); S.fire1(r.Struggle,LP); S.fire0(r.StopAllVelocity)
                    root.AssemblyLinearVelocity=Vector3.new(0,0,0)
                    root.AssemblyAngularVelocity=Vector3.new(0,0,0)
                    local kids=c:GetChildren(); local i
                    for i=1,#kids do if kids[i]:IsA("BasePart") then kids[i].Anchored=true end end
                    anchored=true
                elseif anchored then
                    local kids=c:GetChildren(); local i
                    for i=1,#kids do if kids[i]:IsA("BasePart") then kids[i].Anchored=false end end
                    anchored=false
                end
            end
            task.wait(0.002)
        end
    end)
    return true
end,function()
    local c=LP.Character
    if c then local k=c:GetChildren(); local i; for i=1,#k do if k[i]:IsA("BasePart") then k[i].Anchored=false end end end
    anchored=false
end)

A.addSection(page,"Anti Kick","Visible NinjaKunai/NinjaShuriken StickyPart guard + FirePlayerPart rescue.")
A.addToggle(page,"anti_kick","CONSENSUS Anti Kick + visible weapon",function()
    task.spawn(function()
        while A.toggleState["anti_kick"] do
            local c,h,root=A.getCharacter()
            local r=S.getRefs()
            if c and h and root then
                local leg=c:FindFirstChild("Right Leg")
                local torso=c:FindFirstChild("Torso")
                if leg and torso then
                    local weapon,name=S.findAnyWeapon()
                    if not weapon then
                        local ok
                        ok,weapon=S.spawnToy("NinjaKunai",torso.CFrame*CFrame.new(-0.5,-torso.Size.Y/2,0),Vector3.new(90,90,0))
                        if not weapon then ok,weapon=S.spawnToy("NinjaShuriken",torso.CFrame*CFrame.new(-0.5,-torso.Size.Y/2,0),Vector3.new(90,90,0)) end
                    end
                    local sticky=weapon and (weapon:FindFirstChild("StickyPart") or weapon:FindFirstChild("StickyPart",true))
                    local weld=sticky and sticky:FindFirstChild("StickyWeld")
                    if sticky and r.StickyPartEvent and (not weld or weld.Part1~=leg) then
                        S.fire3(r.StickyPartEvent,sticky,leg,CFrame.new(0.049,0.50,0)*CFrame.Angles(math.rad(-100),0,math.rad(180)))
                    end
                end
                local fpp=root:FindFirstChild("FirePlayerPart")
                local owner=fpp and fpp:FindFirstChild("PartOwner")
                if owner and tostring(owner.Value)~=LP.Name then
                    S.fire2(r.RagdollRemote,root,0); task.wait(0.1); S.fire0(r.Struggle); S.fire1(r.Struggle,LP)
                    pcall(function() h.PlatformStand=false; h.Sit=false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                end
            end
            task.wait(0.08)
        end
    end)
    return true
end,function() end)

A.addSection(page,"Anti Blobman",nil)
A.addToggle(page,"anti_blob","CONSENSUS Anti Blobman SAFE",function()
    task.spawn(function()
        while A.toggleState["anti_blob"] do
            local own=S.mountedBlob()
            local d=Workspace:GetDescendants(); local i,j
            for i=1,#d do
                local b=d[i]
                if b:IsA("Model") and b.Name=="CreatureBlobman" and b~=own then
                    local bd=b:GetDescendants()
                    for j=1,#bd do
                        if bd[j].Name=="AttachPlayer" then pcall(function() bd[j]:Destroy() end)
                        elseif bd[j]:IsA("BasePart") then pcall(function() bd[j].Massless=false end) end
                    end
                end
            end
            task.wait(0.2)
        end
    end)
    return true
end,function() end)

A.addToggle(page,"anti_blob_aggr","Anti Blobman AGGRESSIVE detectors",function()
    task.spawn(function()
        while A.toggleState["anti_blob_aggr"] do
            local own=S.mountedBlob()
            local c,h,root=A.getCharacter()
            if root then
                local d=Workspace:GetDescendants(); local i,j
                for i=1,#d do
                    local b=d[i]
                    if b:IsA("Model") and b.Name=="CreatureBlobman" and b~=own then
                        local names={"LeftDetector","RightDetector"}
                        for j=1,2 do
                            local x=b:FindFirstChild(names[j])
                            if x and x:IsA("BasePart") and (x.Position-root.Position).Magnitude>10 then pcall(function() x:Destroy() end) end
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
    return true
end,function() end)

A.addSection(page,"Anti Explosion / Void / Fire",nil)
A.addToggle(page,"anti_explosion","CONSENSUS Anti Explosion",function()
    local function neut(x) if x:IsA("Explosion") then pcall(function() x.BlastPressure=0 end) end end
    local d=Workspace:GetDescendants(); local i; for i=1,#d do neut(d[i]) end
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
                on=(rag and rag.Value==true) or (arm and arm:FindFirstChild("RagdollLimbPart")~=nil)
                local k=c:GetChildren(); local j
                for j=1,#k do if k[j]:IsA("BasePart") then k[j].Anchored=on end end
                did=on
            end
            task.wait(0.01)
        end
        if did and LP.Character then
            local k=LP.Character:GetChildren(); local j
            for j=1,#k do if k[j]:IsA("BasePart") then k[j].Anchored=false end end
        end
    end)
    return true
end,function()
    if A.toggleStops["anti_explosion"] then A.toggleStops["anti_explosion"](); A.toggleStops["anti_explosion"]=nil end
end)

A.addToggle(page,"anti_void","Anti Void",function()
    pcall(function() Workspace.FallenPartsDestroyHeight=0/0 end)
    task.spawn(function()
        local safe=nil
        while A.toggleState["anti_void"] do
            local c,h,r=A.getCharacter()
            if r then
                if r.Position.Y>-50 and h and h.FloorMaterial~=Enum.Material.Air then safe=r.CFrame end
                if r.Position.Y<-100 and safe then r.AssemblyLinearVelocity=Vector3.new(0,0,0); r.CFrame=safe+Vector3.new(0,4,0) end
            end
            task.wait(0.05)
        end
    end)
    return true
end,function() pcall(function() Workspace.FallenPartsDestroyHeight=savedVoid end) end)

A.addToggle(page,"anti_fire","Anti Fire local",function()
    task.spawn(function()
        while A.toggleState["anti_fire"] do
            local c,h,r=A.getCharacter()
            if r then
                local d=r:GetDescendants(); local i
                for i=1,#d do
                    local x=d[i]
                    if x.Name=="FireLight" or x.Name=="FireParticleEmitter" or x:IsA("Fire") then pcall(function() x:Destroy() end) end
                end
            end
            task.wait(0.05)
        end
    end)
    return true
end,function() end)

A.addSection(page,"Anti Lag / Sticky variants",nil)
A.addToggle(page,"anti_lag_local","Anti Lag local effects",function()
    task.spawn(function()
        while A.toggleState["anti_lag_local"] do
            local d=Workspace:GetDescendants(); local i
            for i=1,#d do
                local x=d[i]
                if x:IsA("ParticleEmitter") or x:IsA("Trail") or x:IsA("Beam") then
                    if effectsSaved[x]==nil then effectsSaved[x]=x.Enabled end
                    pcall(function() x.Enabled=false end)
                end
            end
            task.wait(0.5)
        end
    end)
    return true
end,function()
    for x,v in pairs(effectsSaved) do if x.Parent then pcall(function() x.Enabled=v end) end end
    effectsSaved={}
end)

A.addToggle(page,"anti_sticky","Anti Sticky weld breaker [INFERRED]",function()
    task.spawn(function()
        while A.toggleState["anti_sticky"] do
            local c=LP.Character
            if c then
                local d=Workspace:GetDescendants(); local i
                for i=1,#d do
                    local w=d[i]
                    if w.Name=="StickyWeld" and (w:IsA("Weld") or w:IsA("WeldConstraint")) then
                        local p0=w.Part0; local p1=w.Part1
                        if (p0 and A.isDescendantOf(p0,c)) or (p1 and A.isDescendantOf(p1,c)) then pcall(function() w:Destroy() end) end
                    end
                end
            end
            task.wait(0.05)
        end
    end)
    return true
end,function() end)

A.setStatus("ANTIS pack loaded.")
print("[FTAP V12 ANTIS] READY")
