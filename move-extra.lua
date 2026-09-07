-- FTAP V12 MOVE/EXTRA PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Debris=game:GetService("Debris")
local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V12 MOVE] core+shared first"); return end
if A.packs["MOVE"] then return end
A.registerPack("MOVE")
local S=A.shared
local page=A.makePage("MOVE")
local spin=550; local horiz=false; local speed=50; local jump=70

A.addSection(page,"AUTO SPIN",nil)
A.addSlider(page,"Spin speed",50,2500,25,550,function(v) spin=v end)
A.addToggle(page,"spin_axis","Horizontal spin axis",function() horiz=true return true end,function() horiz=false end)
A.addToggle(page,"auto_spin","AUTO SPIN",function()
    task.spawn(function()
        while A.toggleState["auto_spin"] do
            local c,h,r=A.getCharacter()
            if r then if horiz then r.AssemblyAngularVelocity=Vector3.new(spin,0,0) else r.AssemblyAngularVelocity=Vector3.new(0,spin,0) end end
            RunService.Heartbeat:Wait()
        end
        local c,h,r=A.getCharacter(); if r then r.AssemblyAngularVelocity=Vector3.new(0,0,0) end
    end)
    return true
end,function() local c,h,r=A.getCharacter(); if r then r.AssemblyAngularVelocity=Vector3.new(0,0,0) end end)

A.addSection(page,"Movement",nil)
A.addSlider(page,"WalkSpeed",16,120,1,50,function(v) speed=v end)
A.addToggle(page,"speed","Speed force",function()
    task.spawn(function() while A.toggleState["speed"] do local c,h,r=A.getCharacter(); if h then h.WalkSpeed=speed end; RunService.Heartbeat:Wait() end end); return true
end,function() local c,h,r=A.getCharacter(); if h then h.WalkSpeed=16 end end)
A.addSlider(page,"JumpPower",50,150,5,70,function(v) jump=v end)
A.addToggle(page,"jump","JumpPower force",function()
    task.spawn(function() while A.toggleState["jump"] do local c,h,r=A.getCharacter(); if h then h.UseJumpPower=true; h.JumpPower=jump end; RunService.Heartbeat:Wait() end end); return true
end,function() local c,h,r=A.getCharacter(); if h then h.JumpPower=50 end end)

A.addToggle(page,"noclip","Noclip",function()
    task.spawn(function()
        while A.toggleState["noclip"] do
            local c=LP.Character
            if c then local d=c:GetDescendants(); local i; for i=1,#d do if d[i]:IsA("BasePart") then d[i].CanCollide=false end end end
            RunService.Stepped:Wait()
        end
    end)
    return true
end,function() end)

A.addToggle(page,"inf_jump","Infinite Jump",function()
    local conn=UserInputService.JumpRequest:Connect(function()
        if A.toggleState["inf_jump"] then local c,h,r=A.getCharacter(); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end end
    end)
    A.toggleStops["inf_jump"]=function() conn:Disconnect() end
    return true
end,function() if A.toggleStops["inf_jump"] then A.toggleStops["inf_jump"](); A.toggleStops["inf_jump"]=nil end end)

A.addButton(page,"Teleport behind target",function()
    local p,tr=A.currentTarget(); local c,h,r=A.getCharacter()
    if p and tr and r then r.CFrame=tr.CFrame*CFrame.new(0,0,4) end
end)

local extra=A.makePage("EXTRA")
A.addSection(extra,"Self Defense variants",nil)
local function selfDef(key,power)
    task.spawn(function()
        while A.toggleState[key] do
            local refs=S.getRefs(); local c,h,root=A.getCharacter(); local head=c and c:FindFirstChild("Head"); local owner=head and head:FindFirstChild("PartOwner")
            if owner then
                local attacker=Players:FindFirstChild(tostring(owner.Value))
                local ar=attacker and A.targetRoot(attacker); local tor=attacker and attacker.Character and attacker.Character:FindFirstChild("Torso"); local fpp=ar and ar:FindFirstChild("FirePlayerPart")
                if attacker and ar then
                    S.fire0(refs.Struggle); if refs.SetNetworkOwner and fpp then S.fire2(refs.SetNetworkOwner,ar,fpp.CFrame) end; task.wait(0.1)
                    if tor then
                        local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(0,math.huge,0); bv.Velocity=Vector3.new(0,power,0); bv.Parent=tor; Debris:AddItem(bv,2)
                    end
                end
            end
            task.wait(0.02)
        end
    end)
end
A.addToggle(extra,"self1","Self Defense 1 +50",function() selfDef("self1",50); return true end,function() end)
A.addToggle(extra,"self2","Self Defense 2 +5000",function() selfDef("self2",5000); return true end,function() end)

A.addSection(extra,"Ragdoll/effects",nil)
A.addToggle(extra,"perm_rag","Perm Ragdoll local",function()
    local refs=S.getRefs(); if not refs.RagdollRemote then return false end
    task.spawn(function()
        while A.toggleState["perm_rag"] do local c,h,r=A.getCharacter(); if r then S.fire2(refs.RagdollRemote,r,1) end; task.wait(0.5) end
        local c,h,r=A.getCharacter(); if r then S.fire2(refs.RagdollRemote,r,0) end
    end)
    return true
end,function() end)

A.addButton(extra,"Fire selected",function()
    local p,tr=A.currentTarget(); local camp=S.ensureCampfire(); local f=camp and camp:FindFirstChild("FirePlayerPart")
    if p and tr and f then pcall(function() f.Size=Vector3.new(10,10,10); f.CFrame=tr.CFrame end); task.wait(0.3); pcall(function() f.CFrame=CFrame.new(0,-50,0) end) end
end)

A.addButton(extra,"Poison selected",function()
    local p,tr=A.currentTarget(); local target=p and p.Character and (p.Character:FindFirstChild("Head") or tr); local parts=S.allPartsNamed("PoisonHurtPart")
    if target and #parts>0 then local i; for i=1,#parts do pcall(function() parts[i].Size=Vector3.new(2,2,2); parts[i].Transparency=1; parts[i].CFrame=target.CFrame end) end; task.wait(0.25); S.parkParts(parts) end
end)

A.setStatus("MOVE + EXTRA packs loaded.")
print("[FTAP V12 MOVE] READY")
