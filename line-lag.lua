-- FTAP V14R LAG - ORIGINAL V14 + 2025-2026 RESEARCH VARIANTS
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14 LAG] core+shared first"); return end
if A.packs["LAG"] then return end
A.registerPack("LAG")

local S=A.shared
local page=A.makePage("LAG")

A.addSection(page,"LINE LAG SOURCE MATRIX",
    "A=Vovange SpawnLocation x250. B=Defiant/Critcl every player's Torso x400. Both call GrabEvents.CreateGrabLine with TWO args.")

local lineA=250
local lineB=400

A.addSlider(page,"Line A count",50,1000,10,250,function(v) lineA=v end)
A.addToggle(page,"line_vovange","Line Lag A - VOVANGE EXACT",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    if not refs.CreateGrabLine then A.setStatus("CreateGrabLine missing."); return false end
    if not spawn or not spawn:IsA("BasePart") then A.setStatus("workspace.SpawnLocation missing."); return false end

    task.spawn(function()
        while A.toggleState["line_vovange"] do
            local i
            for i=1,lineA do
                if not A.toggleState["line_vovange"] then break end
                S.fire2(refs.CreateGrabLine,spawn,spawn.CFrame)
            end
            task.wait(1)
        end
    end)
    return true
end,function() end)

A.addSlider(page,"Line B lines",50,1000,10,400,function(v) lineB=v end)
A.addToggle(page,"line_defiant","Line Lag B - DEFIANT/CRITCL EXACT",function()
    local refs=S.getRefs()
    if not refs.CreateGrabLine then A.setStatus("CreateGrabLine missing."); return false end

    task.spawn(function()
        while A.toggleState["line_defiant"] do
            local a,i
            local ps=Players:GetPlayers()
            for a=0,lineB do
                if not A.toggleState["line_defiant"] then break end
                for i=1,#ps do
                    local p=ps[i]
                    local c=p.Character
                    local part=c and (c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart"))
                    if part then
                        S.fire2(refs.CreateGrabLine,part,part.CFrame)
                    end
                end
            end
            task.wait(1)
        end
    end)
    return true
end,function() end)

A.addSection(page,"2025-2026 LINE VARIANT TESTS",
    "Research mapping: fixed-anchor=A above; player fan-out=B above; this adds bounded lifecycle-churn and transform-argument probes so each server-side path can be tested separately.")

local lifecycleBurst=30
local transformOffset=512

A.addSlider(page,"Lifecycle churn cycles",1,120,1,30,function(v) lifecycleBurst=v end)
A.addToggle(page,"line_lifecycle","Line Lag C - CREATE/DESTROY LIFECYCLE",function()
    local refs=S.getRefs()
    if not refs.CreateGrabLine or not refs.DestroyGrabLine then
        A.setStatus("CreateGrabLine/DestroyGrabLine missing.")
        return false
    end
    task.spawn(function()
        while A.toggleState["line_lifecycle"] do
            local _,tr=A.currentTarget()
            local part=tr or Workspace:FindFirstChild("SpawnLocation")
            if part and part:IsA("BasePart") then
                local i
                for i=1,lifecycleBurst do
                    if not A.toggleState["line_lifecycle"] then break end
                    S.fire2(refs.CreateGrabLine,part,part.CFrame)
                    S.fire1(refs.DestroyGrabLine,part)
                end
            end
            task.wait(0.20)
        end
    end)
    return true
end,function() end)

A.addSlider(page,"Transform probe offset",64,4096,64,512,function(v) transformOffset=v end)
A.addToggle(page,"line_transform_probe","Line Lag D - TRANSFORM ARG PROBE",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    if not refs.CreateGrabLine then A.setStatus("CreateGrabLine missing."); return false end
    if not spawn or not spawn:IsA("BasePart") then A.setStatus("workspace.SpawnLocation missing."); return false end
    task.spawn(function()
        local sign=1
        while A.toggleState["line_transform_probe"] do
            local probe=spawn.CFrame*CFrame.new(transformOffset*sign,0,0)
            S.fire2(refs.CreateGrabLine,spawn,probe)
            sign=-sign
            task.wait(0.50)
        end
    end)
    return true
end,function() end)

A.addSection(page,"PACKET / PING LAG SOURCE MATRIX",
    "Multiple leaked hubs agree this remote is GrabEvents.ExtendGrabLine. No manual remote-name guess anymore.")

local packetA=30000
local packetB=3000
local packetC=20

A.addSlider(page,"Packet A emoji count",30000,350000,10000,30000,function(v) packetA=v end)
A.addToggle(page,"packet_vovange","Packet Lag A - VOVANGE EXACT",function()
    local refs=S.getRefs()
    if not refs.ExtendGrabLine then A.setStatus("ExtendGrabLine missing."); return false end
    task.spawn(function()
        while A.toggleState["packet_vovange"] do
            local payload=string.rep("😂",packetA)
            S.fire1(refs.ExtendGrabLine,payload)
            task.wait(0.1)
        end
    end)
    return true
end,function() end)

A.addSlider(page,"Packet B Balls repetitions",500,5000,100,3000,function(v) packetB=v end)
A.addToggle(page,"packet_defiant","Packet Lag B - DEFIANT EXACT",function()
    local refs=S.getRefs()
    if not refs.ExtendGrabLine then A.setStatus("ExtendGrabLine missing."); return false end
    task.spawn(function()
        while A.toggleState["packet_defiant"] do
            S.fire1(refs.ExtendGrabLine,string.rep("Balls Balls Balls Balls",packetB))
            task.wait()
        end
    end)
    return true
end,function() end)

A.addSlider(page,"Packet C strength",1,100,1,20,function(v) packetC=v end)
A.addToggle(page,"packet_polar","Packet Lag C - POLAR EXACT FAMILY",function()
    local refs=S.getRefs()
    if not refs.ExtendGrabLine then A.setStatus("ExtendGrabLine missing."); return false end
    task.spawn(function()
        while A.toggleState["packet_polar"] do
            S.fire1(refs.ExtendGrabLine,string.rep("😂😂😂😂🤣🤣🤣🤣",100*packetC))
            task.wait(1)
        end
    end)
    return true
end,function() end)

A.addSection(page,"PAYLOAD SIZE SWEEP",
    "Research diagnostic for ExtendGrabLine payload amplification. Walks through bounded payload sizes instead of hiding the threshold inside one giant string.")

local packetSweepMax=131072
A.addSlider(page,"Payload sweep max bytes",4096,262144,4096,131072,function(v) packetSweepMax=v end)
A.addToggle(page,"packet_size_sweep","Packet Lag D - SIZE SWEEP",function()
    local refs=S.getRefs()
    if not refs.ExtendGrabLine then A.setStatus("ExtendGrabLine missing."); return false end
    task.spawn(function()
        local sizes={1024,4096,16384,65536,131072,262144}
        while A.toggleState["packet_size_sweep"] do
            local i
            for i=1,#sizes do
                if not A.toggleState["packet_size_sweep"] then break end
                local n=math.min(sizes[i],packetSweepMax)
                if n>=1024 then
                    S.fire1(refs.ExtendGrabLine,string.rep("X",n))
                    A.setStatus("Payload sweep sent bytes="..tostring(n))
                    task.wait(0.50)
                end
                if n>=packetSweepMax then break end
            end
            task.wait(2.0)
        end
    end)
    return true
end,function() end)

A.addSection(page,"SHURIKEN FPS / PHYSICS LAG",
    "Exact Defiant/Critcl family. V14 fixes the previous bug by searching your PlotItems folder as well as SpawnedInToys.")

local decoyCount=2
local shurCount=16
local shurBodies={}

A.addSlider(page,"Setup decoys",1,4,1,2,function(v) decoyCount=v end)
A.addSlider(page,"Setup shurikens",8,32,1,16,function(v) shurCount=v end)

A.addButton(page,"RUN Setup Shuriken-lag toys",function()
    local c,h,r=A.getCharacter()
    if not r then return A.setStatus("Root missing.") end
    local i
    for i=1,decoyCount do
        S.spawnToy("NpcRobloxianMascot",r.CFrame*CFrame.new(i*3,0,-8),Vector3.zero)
        task.wait(0.1)
    end
    for i=1,shurCount do
        S.spawnToy("NinjaShuriken",r.CFrame*CFrame.new(0,4,-4),Vector3.zero)
        task.wait(0.03)
    end
    local fs=S.describeToyFolders()
    A.setStatus("Toy setup requested. folders="..table.concat(fs," | "))
end)

A.addToggle(page,"fps_shuriken","FPS Lag - DEFIANT SHURIKEN EXACT",function()
    local decoys=S.findOwnToys("NpcRobloxianMascot")
    local shurs=S.findOwnToys("NinjaShuriken")
    if #decoys==0 or #shurs==0 then
        A.setStatus("Need owned decoy + shuriken. Press Setup first.")
        return false
    end

    shurBodies={}
    local di
    for di=1,#decoys do
        local dr=decoys[di]:FindFirstChild("HumanoidRootPart")
        if dr then
            local startIndex=(di-1)*8+1
            local endIndex=math.min(startIndex+7,#shurs)
            local si
            for si=startIndex,endIndex do
                local sh=shurs[si]
                local sticky=sh and sh:FindFirstChild("StickyPart",true)
                if sticky and sticky:IsA("BasePart") then
                    sticky.CanTouch=true

                    local dd=decoys[di]:GetDescendants()
                    local k
                    for k=1,#dd do if dd[k]:IsA("BasePart") then dd[k].CanCollide=false end end

                    local bp=Instance.new("BodyPosition")
                    bp.Name="FTAPV14LagBP"
                    bp.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
                    bp.P=10000
                    bp.D=500
                    bp.Parent=sticky

                    local sd=sh:GetDescendants()
                    for k=1,#sd do if sd[k]:IsA("BasePart") then sd[k].CanCollide=false end end

                    local kids=sticky:GetChildren()
                    for k=1,#kids do
                        if kids[k].Name=="TouchInterest" then pcall(function() kids[k]:Destroy() end) end
                    end

                    shurBodies[#shurBodies+1]={sticky=sticky,bp=bp,decoy=dr}
                end
            end
        end
    end

    if #shurBodies==0 then
        A.setStatus("No usable StickyPart/decoy pairs.")
        return false
    end

    task.spawn(function()
        while A.toggleState["fps_shuriken"] do
            local i
            for i=1,#shurBodies do
                local x=shurBodies[i]
                if x.sticky.Parent and x.bp.Parent and x.decoy.Parent then
                    x.sticky.AssemblyAngularVelocity=Vector3.new(
                        math.random(-100,100)*50,
                        math.random(-100,100)*50,
                        math.random(-100,100)*50
                    )
                    x.bp.Position=Vector3.new(x.decoy.Position.X,x.decoy.Position.Y-4,x.decoy.Position.Z)
                end
            end
            task.wait(0.0001)
            for i=1,#shurBodies do
                local x=shurBodies[i]
                if x.bp.Parent and x.decoy.Parent then
                    x.bp.Position=Vector3.new(x.decoy.Position.X,x.decoy.Position.Y+3,x.decoy.Position.Z)
                end
            end
            task.wait(0.0001)
        end
    end)

    A.setStatus("Defiant Shuriken lag pairs="..tostring(#shurBodies))
    return true
end,function()
    local i
    for i=1,#shurBodies do
        if shurBodies[i].bp then pcall(function() shurBodies[i].bp:Destroy() end) end
    end
    shurBodies={}
end)

A.addButton(page,"RUN Research variant summary",function()
    A.setStatus("Research map: A=fixed-anchor; B=player fan-out; C=create/destroy lifecycle churn; D=transform argument probe; Packet D=bounded payload-size sweep; FPS=physics saturation.")
end)

A.addSection(page,"LAG PREFLIGHT",nil)
A.addButton(page,"RUN LAG PREFLIGHT",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    local fs=S.ownToyFolders()
    A.setStatus(
        "CreateGrabLine="..tostring(refs.CreateGrabLine~=nil)..
        " DestroyGrabLine="..tostring(refs.DestroyGrabLine~=nil)..
        " ExtendGrabLine="..tostring(refs.ExtendGrabLine~=nil)..
        " SpawnLocation="..tostring(spawn~=nil)..
        " toyFolders="..tostring(#fs)
    )
end)

A.setStatus("V14R LAG loaded: original V14 exact families + lifecycle/transform/payload research tests.")
print("[FTAP V14R LAG] READY")
