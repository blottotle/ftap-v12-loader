-- FTAP V13 GRAB MODS PACK
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local Debris=game:GetService("Debris")
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V13 GRAB] core+shared first"); return end
if A.packs["GRAB"] then return end
A.registerPack("GRAB")
local S=A.shared
local page=A.makePage("GRAB MODS")
local strength=1000

A.addSection(page,"Strong Throw",nil)
A.addSlider(page,"Throw strength",100,10000,50,1000,function(v) strength=v end)
A.addToggle(page,"strong_throw","Strong Throw on release",function()
    local conn
    conn=Workspace.ChildAdded:Connect(function(m)
        if not A.toggleState["strong_throw"] or m.Name~="GrabParts" then return end
        task.spawn(function()
            local g=m:WaitForChild("GrabPart",2); local w=g and g:FindFirstChild("WeldConstraint"); local part=w and w.Part1
            if not part or not part:IsA("BasePart") then return end
            while A.toggleState["strong_throw"] and m.Parent do RunService.Heartbeat:Wait() end
            if A.toggleState["strong_throw"] and part.Parent and Workspace.CurrentCamera then
                local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.Velocity=Workspace.CurrentCamera.CFrame.LookVector*strength; bv.Parent=part; Debris:AddItem(bv,1)
            end
        end)
    end)
    A.toggleStops["strong_throw"]=function() conn:Disconnect() end
    return true
end,function() if A.toggleStops["strong_throw"] then A.toggleStops["strong_throw"](); A.toggleStops["strong_throw"]=nil end end)

local function effectLoop(key,name)
    task.spawn(function()
        while A.toggleState[key] do
            local grabbed,gp=S.currentGrabbedPart()
            local char=S.ancestorHumanoidModel(grabbed)
            local head=char and char:FindFirstChild("Head")
            local parts=S.allPartsNamed(name)
            if head and gp then
                while A.toggleState[key] and Workspace:FindFirstChild("GrabParts") do
                    local i; for i=1,#parts do local p=parts[i]; if p and p.Parent then pcall(function() p.Size=Vector3.new(2,2,2); p.Transparency=1; p.CFrame=head.CFrame end) end end
                    RunService.Heartbeat:Wait()
                end
                S.parkParts(parts)
            end
            task.wait(0.02)
        end
    end)
end

A.addSection(page,"Player Grab Effects",nil)
A.addToggle(page,"poison_grab","Poison Grab",function()
    if #S.allPartsNamed("PoisonHurtPart")==0 then A.setStatus("PoisonHurtPart missing."); return false end
    effectLoop("poison_grab","PoisonHurtPart"); return true
end,function() S.parkParts(S.allPartsNamed("PoisonHurtPart")) end)

A.addToggle(page,"paint_grab","Radioactive/Paint Grab",function()
    if #S.allPartsNamed("PaintPlayerPart")==0 then A.setStatus("PaintPlayerPart missing."); return false end
    effectLoop("paint_grab","PaintPlayerPart"); return true
end,function() S.parkParts(S.allPartsNamed("PaintPlayerPart")) end)

A.addToggle(page,"fire_grab","Fire Grab",function()
    if not S.ensureCampfire() then A.setStatus("Campfire unavailable."); return false end
    task.spawn(function()
        while A.toggleState["fire_grab"] do
            local grabbed=S.currentGrabbedPart(); local char=S.ancestorHumanoidModel(grabbed); local head=char and char:FindFirstChild("Head")
            local camp=S.ensureCampfire(); local f=camp and camp:FindFirstChild("FirePlayerPart")
            if head and f then pcall(function() f.Size=Vector3.new(7,7,7); f.CFrame=head.CFrame end); task.wait(0.3); pcall(function() f.CFrame=CFrame.new(0,-50,0) end) end
            task.wait(0.02)
        end
    end)
    return true
end,function() end)

A.addToggle(page,"noclip_grab","Noclip Grab",function()
    task.spawn(function()
        while A.toggleState["noclip_grab"] do
            local grabbed=S.currentGrabbedPart(); local char=S.ancestorHumanoidModel(grabbed)
            if char then
                local old={}
                while A.toggleState["noclip_grab"] and Workspace:FindFirstChild("GrabParts") do
                    local k=char:GetChildren(); local i
                    for i=1,#k do if k[i]:IsA("BasePart") then if old[k[i]]==nil then old[k[i]]=k[i].CanCollide end; k[i].CanCollide=false end end
                    RunService.Heartbeat:Wait()
                end
                for p,v in pairs(old) do if p.Parent then p.CanCollide=v end end
            end
            task.wait(0.02)
        end
    end)
    return true
end,function() end)

local originals={}
local function kickState(on)
    local ps=game:GetService("Players"):GetPlayers(); local i
    for i=1,#ps do
        local hrp=ps[i].Character and ps[i].Character:FindFirstChild("HumanoidRootPart")
        local f=hrp and hrp:FindFirstChild("FirePlayerPart")
        if f and f:IsA("BasePart") then
            if on then
                if not originals[f] then originals[f]={f.Size,f.CollisionGroup,f.CanQuery} end
                pcall(function() f.Size=Vector3.new(4.5,5.5,4.5); f.CollisionGroup="1"; f.CanQuery=true end)
            elseif originals[f] then
                local o=originals[f]; pcall(function() f.Size=o[1]; f.CollisionGroup=o[2]; f.CanQuery=o[3] end)
            end
        end
    end
    if not on then originals={} end
end

A.addToggle(page,"kick_grab","Kick Grab hitboxes",function()
    task.spawn(function() while A.toggleState["kick_grab"] do kickState(true); task.wait(0.5) end end)
    return true
end,function() kickState(false) end)

local anchors={}
A.addSection(page,"Anchor Object Grab",nil)
A.addToggle(page,"anchor_grab","Anchor Object after release",function()
    task.spawn(function()
        while A.toggleState["anchor_grab"] do
            local part,gp=S.currentGrabbedPart()
            if part and gp and part:IsA("BasePart") and not S.ancestorHumanoidModel(part) then
                local pos=part.Position; local cf=part.CFrame
                while A.toggleState["anchor_grab"] and gp.Parent do pos=part.Position; cf=part.CFrame; RunService.Heartbeat:Wait() end
                if A.toggleState["anchor_grab"] and part.Parent then
                    local bp=Instance.new("BodyPosition"); bp.Name="FTAPAnchorBP"; bp.P=15000; bp.D=200; bp.MaxForce=Vector3.new(5000000,5000000,5000000); bp.Position=pos; bp.Parent=part
                    local bg=Instance.new("BodyGyro"); bg.Name="FTAPAnchorBG"; bg.P=15000; bg.D=200; bg.MaxTorque=Vector3.new(5000000,5000000,5000000); bg.CFrame=cf; bg.Parent=part
                    anchors[#anchors+1]=part
                end
            end
            task.wait(0.02)
        end
    end)
    return true
end,function() end)

A.addButton(page,"Cleanup anchored objects",function()
    local i
    for i=1,#anchors do local p=anchors[i]; if p and p.Parent then local bp=p:FindFirstChild("FTAPAnchorBP"); local bg=p:FindFirstChild("FTAPAnchorBG"); if bp then bp:Destroy() end; if bg then bg:Destroy() end end end
    anchors={}
end)

A.setStatus("GRAB MODS pack loaded.")
print("[FTAP V13 GRAB] READY")
