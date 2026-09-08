-- FTAP V14.1 LAG / LINE RESEARCH-INFORMED SAFE DIAGNOSTICS
-- The recent source families are categorized here, but destructive remote-spam
-- loops are intentionally not executed. The local render test only affects this client.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local LP=Players.LocalPlayer

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14.1 LAG] core+shared first"); return end
if A.packs["LAG"] then return end
A.registerPack("LAG")

local S=A.shared
local page=A.makePage("LAG")

local function fullName(x)
    if not x then return "missing" end
    local ok,name=pcall(function() return x:GetFullName() end)
    return ok and name or tostring(x.Name)
end

local function charRoot(p)
    local c=p and p.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso")) or nil
end

A.addSection(page,"LINE VARIANTS - 2025/2026 RESEARCH",
    "Subcategory: fixed-anchor, player fan-out, outlier-transform, lifecycle churn, and payload amplification. This build inspects prerequisites/signatures without firing lag/kick traffic.")

A.addButton(page,"CHECK Fixed-anchor line variant",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    A.setStatus(
        "fixed-anchor: CreateGrabLine="..tostring(refs.CreateGrabLine~=nil)..
        " spawn="..tostring(spawn~=nil)..
        " remote="..fullName(refs.CreateGrabLine)
    )
end)

A.addButton(page,"CHECK Player fan-out line variant",function()
    local refs=S.getRefs()
    local ps=Players:GetPlayers()
    local roots=0
    local i
    for i=1,#ps do if charRoot(ps[i]) then roots=roots+1 end end
    A.setStatus(
        "fan-out: CreateGrabLine="..tostring(refs.CreateGrabLine~=nil)..
        " liveRoots="..tostring(roots).."/"..tostring(#ps)..
        " (diagnostic only)"
    )
end)

A.addButton(page,"CHECK Outlier-transform line variant",function()
    local refs=S.getRefs()
    local _,_,root=A.getCharacter()
    local finite=root and root.Position.X==root.Position.X and root.Position.Magnitude<1e8
    A.setStatus(
        "outlier-transform: CreateGrabLine="..tostring(refs.CreateGrabLine~=nil)..
        " localRootFinite="..tostring(finite==true)..
        " | no extreme transform sent"
    )
end)

A.addButton(page,"CHECK Line lifecycle-churn variant",function()
    local refs=S.getRefs()
    A.setStatus(
        "lifecycle: Create="..tostring(refs.CreateGrabLine~=nil)..
        " Destroy="..tostring(refs.DestroyGrabLine~=nil)..
        " | create/destroy churn disabled in this build"
    )
end)

A.addButton(page,"CHECK Payload-amplification variant",function()
    local refs=S.getRefs()
    A.setStatus(
        "payload: ExtendGrabLine="..tostring(refs.ExtendGrabLine~=nil)..
        " remote="..fullName(refs.ExtendGrabLine)..
        " | oversized payload firing disabled"
    )
end)

A.addSection(page,"LOCAL-ONLY LINE RENDER STRESS",
    "Models the client-side cost of many visible lines without RemoteEvents, server replication, or other-player effects. Objects are parented under CurrentCamera and auto-cleaned.")

local localLineCount=250
local localLineSeconds=2
local stressFolder=nil
local stressRunning=false

A.addSlider(page,"Local lines",25,1000,25,250,function(v) localLineCount=v end)
A.addSlider(page,"Local stress seconds",1,10,1,2,function(v) localLineSeconds=v end)

local function clearStress()
    stressRunning=false
    if stressFolder then
        pcall(function() stressFolder:Destroy() end)
        stressFolder=nil
    end
end

A.addButton(page,"RUN Local-only line render test",function()
    if stressRunning then return A.setStatus("Local line test already running.") end
    local cam=Workspace.CurrentCamera
    local _,_,root=A.getCharacter()
    if not cam or not root then return A.setStatus("Camera/root missing.") end

    clearStress()
    stressRunning=true
    local folder=Instance.new("Folder")
    folder.Name="FTAP_LocalLineStress"
    folder.Parent=cam
    stressFolder=folder

    local origin=Instance.new("Part")
    origin.Name="Origin"
    origin.Anchored=true
    origin.CanCollide=false
    origin.CanTouch=false
    origin.CanQuery=false
    origin.Transparency=1
    origin.Size=Vector3.new(0.2,0.2,0.2)
    origin.CFrame=root.CFrame
    origin.Parent=folder

    local a0=Instance.new("Attachment")
    a0.Parent=origin

    local i
    for i=1,localLineCount do
        local endpoint=Instance.new("Part")
        endpoint.Name="P"..tostring(i)
        endpoint.Anchored=true
        endpoint.CanCollide=false
        endpoint.CanTouch=false
        endpoint.CanQuery=false
        endpoint.Transparency=1
        endpoint.Size=Vector3.new(0.15,0.15,0.15)
        local ang=(i/localLineCount)*math.pi*2
        local radius=10+(i%11)
        endpoint.Position=root.Position+Vector3.new(math.cos(ang)*radius,(i%9)-4,math.sin(ang)*radius)
        endpoint.Parent=folder

        local a1=Instance.new("Attachment")
        a1.Parent=endpoint
        local beam=Instance.new("Beam")
        beam.Attachment0=a0
        beam.Attachment1=a1
        beam.FaceCamera=true
        beam.Width0=0.03
        beam.Width1=0.03
        beam.Parent=folder
    end

    A.setStatus("Local-only line test active: "..tostring(localLineCount).." lines / "..tostring(localLineSeconds).."s")
    task.spawn(function()
        local untilTime=os.clock()+localLineSeconds
        while stressRunning and os.clock()<untilTime and folder.Parent do
            local t=os.clock()
            origin.CFrame=CFrame.new(root.Position+Vector3.new(0,2+math.sin(t*5)*0.5,0))
            RunService.RenderStepped:Wait()
        end
        clearStress()
        A.setStatus("Local-only line test finished and cleaned up.")
    end)
end)

A.addButton(page,"STOP/CLEAN Local line test",clearStress)

A.addSection(page,"LAG PREFLIGHT",nil)
A.addButton(page,"RUN LAG PREFLIGHT",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    A.setStatus(
        "CreateGrabLine="..tostring(refs.CreateGrabLine~=nil)..
        " DestroyGrabLine="..tostring(refs.DestroyGrabLine~=nil)..
        " ExtendGrabLine="..tostring(refs.ExtendGrabLine~=nil)..
        " SpawnLocation="..tostring(spawn~=nil)..
        " | remote-spam disabled"
    )
end)

A.setStatus("V14.1 LAG loaded: recent line families categorized; destructive lag traffic disabled.")
print("[FTAP V14.1 LAG] READY")
