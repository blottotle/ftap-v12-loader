-- FTAP V14.2 LAG / LOCAL STRESS LAB
-- Research categories are retained for diagnostics, but this file never fires
-- CreateGrabLine / DestroyGrabLine / ExtendGrabLine traffic. Stress objects are
-- client-created under CurrentCamera or PlayerGui and auto-cleaned.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local LP=Players.LocalPlayer

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14.2 LAG] core+shared first"); return end
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
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")) or nil
end

A.addSection(page,"LINE VARIANTS - RESEARCH MAP",
    "Fixed-anchor, player fan-out, outlier-transform, lifecycle churn, and payload amplification remain visible as prerequisite/signature checks. Cross-player/server lag traffic is not fired.")

A.addButton(page,"CHECK Fixed-anchor line variant",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    A.setStatus("fixed-anchor: CreateGrabLine="..tostring(refs.CreateGrabLine~=nil).." spawn="..tostring(spawn~=nil).." remote="..fullName(refs.CreateGrabLine))
end)

A.addButton(page,"CHECK Player fan-out line variant",function()
    local refs=S.getRefs()
    local ps=Players:GetPlayers()
    local roots=0
    local i
    for i=1,#ps do if charRoot(ps[i]) then roots=roots+1 end end
    A.setStatus("fan-out: CreateGrabLine="..tostring(refs.CreateGrabLine~=nil).." liveRoots="..tostring(roots).."/"..tostring(#ps).." diagnostic-only")
end)

A.addButton(page,"CHECK Outlier-transform line variant",function()
    local refs=S.getRefs()
    local _,_,root=A.getCharacter()
    local finite=root and root.Position.X==root.Position.X and root.Position.Magnitude<1e8
    A.setStatus("outlier-transform: CreateGrabLine="..tostring(refs.CreateGrabLine~=nil).." localRootFinite="..tostring(finite==true).." no outlier sent")
end)

A.addButton(page,"CHECK Line lifecycle-churn variant",function()
    local refs=S.getRefs()
    A.setStatus("lifecycle: Create="..tostring(refs.CreateGrabLine~=nil).." Destroy="..tostring(refs.DestroyGrabLine~=nil).." remote churn disabled")
end)

A.addButton(page,"CHECK Payload-amplification variant",function()
    local refs=S.getRefs()
    A.setStatus("payload: ExtendGrabLine="..tostring(refs.ExtendGrabLine~=nil).." remote="..fullName(refs.ExtendGrabLine).." oversized traffic disabled")
end)

-- ============================================================
-- LOCAL STRESS CONTROLLER
-- ============================================================
A.addSection(page,"LOCAL STRESS LAB - HEAVIER",
    "All stress below is local to this client. END is an emergency stop. Every run has an automatic timeout and cleans up its Instances.")

local stressFolder=nil
local stressGui=nil
local stressGeneration=0
local stressRunning=false
local renderConn=nil
local simConn=nil
local inputConn=nil

local lineCount=1200
local lineSeconds=4
local lineMotion=1.0
local partCount=900
local partSeconds=4
local guiCount=1200
local guiSeconds=4
local churnPerFrame=120
local churnSeconds=4

local function destroyConn(c)
    if c then pcall(function() c:Disconnect() end) end
end

local function clearStress(reason)
    stressGeneration=stressGeneration+1
    stressRunning=false
    destroyConn(renderConn); renderConn=nil
    destroyConn(simConn); simConn=nil
    if stressFolder then pcall(function() stressFolder:Destroy() end); stressFolder=nil end
    if stressGui then pcall(function() stressGui:Destroy() end); stressGui=nil end
    if reason then A.setStatus("Local stress stopped: "..tostring(reason)) end
end

inputConn=UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.End then clearStress("END emergency stop") end
end)

A.addSlider(page,"Beam lines",100,8000,100,1200,function(v) lineCount=v end)
A.addSlider(page,"Beam seconds",1,20,1,4,function(v) lineSeconds=v end)
A.addSlider(page,"Beam motion multiplier",0,4,0.25,1,function(v) lineMotion=v end)

local function newStressFolder(name)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local f=Instance.new("Folder")
    f.Name=name
    f.Parent=cam
    return f
end

local function buildBeamStress(count)
    local _,_,root=A.getCharacter()
    if not root then return false,"root missing" end
    local folder=newStressFolder("FTAP_LocalBeamStress")
    if not folder then return false,"camera missing" end
    stressFolder=folder

    local origin=Instance.new("Part")
    origin.Name="Origin"
    origin.Anchored=true
    origin.CanCollide=false
    origin.CanTouch=false
    origin.CanQuery=false
    origin.CastShadow=false
    origin.Transparency=1
    origin.Size=Vector3.new(0.1,0.1,0.1)
    origin.CFrame=root.CFrame
    origin.Parent=folder

    local a0=Instance.new("Attachment")
    a0.Parent=origin

    local endpoints={}
    local i
    for i=1,count do
        if not stressRunning or not folder.Parent then return false,"stopped during build" end
        local p=Instance.new("Part")
        p.Name="E"..tostring(i)
        p.Anchored=true
        p.CanCollide=false
        p.CanTouch=false
        p.CanQuery=false
        p.CastShadow=false
        p.Transparency=1
        p.Size=Vector3.new(0.08,0.08,0.08)
        p.Parent=folder

        local a1=Instance.new("Attachment")
        a1.Parent=p
        local beam=Instance.new("Beam")
        beam.Attachment0=a0
        beam.Attachment1=a1
        beam.FaceCamera=true
        beam.Width0=0.035
        beam.Width1=0.015
        beam.Segments=2+(i%5)
        beam.LightEmission=0.5
        beam.Parent=folder
        endpoints[i]=p

        if i%250==0 then RunService.Heartbeat:Wait() end
    end

    local start=os.clock()
    local base=root.Position
    local myGen=stressGeneration
    renderConn=RunService.PreRender:Connect(function()
        if not stressRunning or myGen~=stressGeneration or not folder.Parent then return end
        local _,_,freshRoot=A.getCharacter()
        if freshRoot then base=freshRoot.Position end
        local t=(os.clock()-start)*lineMotion
        origin.CFrame=CFrame.new(base+Vector3.new(0,2+math.sin(t*4)*0.5,0))
        local stride=1
        local j
        for j=1,#endpoints,stride do
            local p=endpoints[j]
            if p and p.Parent then
                local ang=(j/#endpoints)*math.pi*2+t*(1+(j%7)*0.04)
                local radius=7+(j%41)*0.35
                p.Position=base+Vector3.new(math.cos(ang)*radius,((j%31)-15)*0.25+math.sin(t*3+j*0.03)*2,math.sin(ang)*radius)
            end
        end
    end)
    return true
end

A.addButton(page,"RUN Local Beam storm",function()
    clearStress()
    stressRunning=true
    local myGen=stressGeneration
    local ok,why=buildBeamStress(lineCount)
    if not ok then stressRunning=false; return A.setStatus("Beam stress failed: "..tostring(why)) end
    A.setStatus("Local Beam storm: "..tostring(lineCount).." moving beams / "..tostring(lineSeconds).."s | END stops")
    task.spawn(function()
        task.wait(lineSeconds)
        if stressRunning and myGen==stressGeneration then clearStress("Beam timeout") end
    end)
end)

A.addSlider(page,"Visible parts",100,5000,100,900,function(v) partCount=v end)
A.addSlider(page,"Part storm seconds",1,20,1,4,function(v) partSeconds=v end)

A.addButton(page,"RUN Local visible-part storm",function()
    clearStress()
    local _,_,root=A.getCharacter()
    if not root then return A.setStatus("Part stress failed: root missing") end
    local folder=newStressFolder("FTAP_LocalPartStress")
    if not folder then return A.setStatus("Part stress failed: camera missing") end
    stressFolder=folder
    stressRunning=true
    local myGen=stressGeneration
    local parts={}
    local i
    for i=1,partCount do
        if not stressRunning or not folder.Parent then return A.setStatus("Part stress stopped during build") end
        local p=Instance.new("Part")
        p.Name="V"..tostring(i)
        p.Anchored=true
        p.CanCollide=false
        p.CanTouch=false
        p.CanQuery=false
        p.CastShadow=false
        p.Material=Enum.Material.Neon
        p.Size=Vector3.new(0.18+(i%5)*0.06,0.18+(i%3)*0.08,0.18+(i%7)*0.04)
        p.Transparency=(i%4)*0.12
        p.Parent=folder
        parts[i]=p
        if i%250==0 then RunService.Heartbeat:Wait() end
    end
    local start=os.clock()
    renderConn=RunService.PreRender:Connect(function()
        if not stressRunning or myGen~=stressGeneration then return end
        local _,_,fresh=A.getCharacter()
        if fresh then root=fresh end
        local base=root.Position
        local t=os.clock()-start
        local j
        for j=1,#parts do
            local p=parts[j]
            if p and p.Parent then
                local a=(j/#parts)*math.pi*2+t*(0.8+(j%9)*0.03)
                local r=4+(j%45)*0.22
                p.CFrame=CFrame.new(base+Vector3.new(math.cos(a)*r,1+((j%33)-16)*0.18+math.sin(t*5+j)*0.7,math.sin(a)*r))*CFrame.Angles(t+j*0.01,t*1.7,t*0.5)
            end
        end
    end)
    A.setStatus("Local visible-part storm: "..tostring(partCount).." moving parts / "..tostring(partSeconds).."s | END stops")
    task.spawn(function()
        task.wait(partSeconds)
        if stressRunning and myGen==stressGeneration then clearStress("Part-storm timeout") end
    end)
end)

A.addSlider(page,"GUI rectangles",100,6000,100,1200,function(v) guiCount=v end)
A.addSlider(page,"GUI storm seconds",1,20,1,4,function(v) guiSeconds=v end)

A.addButton(page,"RUN Local GUI fill storm",function()
    clearStress()
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return A.setStatus("GUI stress failed: PlayerGui missing") end
    local g=Instance.new("ScreenGui")
    g.Name="FTAP_LocalGuiStress"
    g.IgnoreGuiInset=true
    g.ResetOnSpawn=false
    g.DisplayOrder=2147483000
    g.Parent=pg
    stressGui=g
    stressRunning=true
    local myGen=stressGeneration
    local frames={}
    local i
    for i=1,guiCount do
        if not stressRunning or not g.Parent then return A.setStatus("GUI stress stopped during build") end
        local f=Instance.new("Frame")
        f.BorderSizePixel=0
        f.BackgroundTransparency=0.15+(i%5)*0.12
        f.Size=UDim2.fromOffset(8+(i%13),8+(i%17))
        f.Position=UDim2.fromScale((i%97)/97,((i*37)%101)/101)
        f.Parent=g
        frames[i]=f
        if i%400==0 then RunService.Heartbeat:Wait() end
    end
    local start=os.clock()
    renderConn=RunService.PreRender:Connect(function()
        if not stressRunning or myGen~=stressGeneration then return end
        local t=os.clock()-start
        local j
        for j=1,#frames do
            local f=frames[j]
            if f and f.Parent then
                local x=(math.sin(t*(1+(j%7)*0.05)+j*0.13)+1)*0.5
                local y=(math.cos(t*(1.2+(j%11)*0.03)+j*0.07)+1)*0.5
                f.Position=UDim2.fromScale(x,y)
                f.Rotation=(t*90+j*3)%360
            end
        end
    end)
    A.setStatus("Local GUI fill storm: "..tostring(guiCount).." moving rectangles / "..tostring(guiSeconds).."s | END stops")
    task.spawn(function()
        task.wait(guiSeconds)
        if stressRunning and myGen==stressGeneration then clearStress("GUI-storm timeout") end
    end)
end)

A.addSlider(page,"Local churn / frame",20,400,20,120,function(v) churnPerFrame=v end)
A.addSlider(page,"Local churn seconds",1,15,1,4,function(v) churnSeconds=v end)

A.addButton(page,"RUN Local allocation churn",function()
    clearStress()
    local folder=newStressFolder("FTAP_LocalChurnStress")
    if not folder then return A.setStatus("Churn stress failed: camera missing") end
    stressFolder=folder
    stressRunning=true
    local myGen=stressGeneration
    local deadline=os.clock()+churnSeconds
    local pool={}
    simConn=RunService.Heartbeat:Connect(function()
        if not stressRunning or myGen~=stressGeneration then return end
        local i
        for i=1,churnPerFrame do
            local a=Instance.new("Attachment")
            a.Name="C"
            a.Parent=folder
            local b=Instance.new("Beam")
            b.Attachment0=a
            b.Attachment1=a
            b.Segments=1+(i%5)
            b.Parent=folder
            pool[#pool+1]=b
            pool[#pool+1]=a
        end
        local remove=math.min(#pool,churnPerFrame*2)
        for i=1,remove do
            local x=table.remove(pool,1)
            if x then pcall(function() x:Destroy() end) end
        end
        if os.clock()>=deadline then clearStress("Allocation-churn timeout") end
    end)
    A.setStatus("Local allocation churn: "..tostring(churnPerFrame).." Attachment+Beam pairs/frame / "..tostring(churnSeconds).."s | END stops")
end)

A.addButton(page,"RUN LOCAL HEAVY preset",function()
    lineCount=3500
    lineSeconds=6
    lineMotion=1.5
    clearStress()
    stressRunning=true
    local myGen=stressGeneration
    local ok,why=buildBeamStress(lineCount)
    if not ok then stressRunning=false; return A.setStatus("Heavy preset failed: "..tostring(why)) end
    A.setStatus("LOCAL HEAVY preset: 3500 moving beams / 6s | END stops")
    task.spawn(function()
        task.wait(6)
        if stressRunning and myGen==stressGeneration then clearStress("Heavy preset timeout") end
    end)
end)

A.addButton(page,"STOP/CLEAN ALL LOCAL STRESS",function() clearStress("manual cleanup") end)

A.toggleStops["lag_local_cleanup"]=function()
    clearStress()
    destroyConn(inputConn)
    inputConn=nil
end

A.addSection(page,"RESPAWN / LAG PREFLIGHT",nil)
A.addButton(page,"RUN LAG PREFLIGHT",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    local c,h,r=A.getCharacter()
    A.setStatus("char="..tostring(c~=nil).." root="..tostring(r~=nil).." Create="..tostring(refs.CreateGrabLine~=nil).." Destroy="..tostring(refs.DestroyGrabLine~=nil).." Extend="..tostring(refs.ExtendGrabLine~=nil).." Spawn="..tostring(spawn~=nil).." | remote spam disabled")
end)

A.setStatus("V14.2 LAG loaded: stronger local stress lab + END emergency cleanup.")
print("[FTAP V14.2 LAG] READY")
