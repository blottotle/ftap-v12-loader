-- FTAP V14.4 SERVER-ONLY LOAD TEST HARNESS
-- Install as a Script in ServerScriptService.
-- Set ALLOWED_PLACE_ID to the exact PlaceId before publishing.
-- Stress is bounded and refuses to run anywhere else.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local ALLOWED_PLACE_ID = 0 -- <<< SET THIS TO YOUR EXACT game.PlaceId
local REMOTE_NAME = "FTAPServerStressControl"
local RUNTIME_NAME = "FTAPServerStressRuntime"

if ALLOWED_PLACE_ID <= 0 then
    warn("[FTAP V14.4 SERVER] REFUSED: set ALLOWED_PLACE_ID first")
    return
end
if game.PlaceId ~= ALLOWED_PLACE_ID then
    warn(("[FTAP V14.4 SERVER] REFUSED: place %d != allowed %d"):format(game.PlaceId, ALLOWED_PLACE_ID))
    return
end

local oldRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if oldRemote then oldRemote:Destroy() end
local remote = Instance.new("RemoteEvent")
remote.Name = REMOTE_NAME
remote:SetAttribute("AllowedPlaceId", ALLOWED_PLACE_ID)
remote:SetAttribute("HarnessVersion", "14.4")
remote.Parent = ReplicatedStorage

local oldRuntime = Workspace:FindFirstChild(RUNTIME_NAME)
if oldRuntime then oldRuntime:Destroy() end
local runtime = Instance.new("Folder")
runtime.Name = RUNTIME_NAME
runtime.Parent = Workspace

local stressGeneration = 0
local stressMode = "IDLE"
local stressParams = {}
local stressConn = nil
local stressPool = nil
local constraintRoot = nil
local physicsRoot = nil
local pathOutstanding = 0
local signalEvent = nil
local signalConnections = {}
local serverTweens = {}
local pathClock = 0
local heartbeatSamples = {}
local controllers = {}

local blobGeneration = 0
local blobMode = "IDLE"
local blobParams = {}
local blobConn = nil
local generatedBlob = nil
local generatedTarget = nil

local commandLast = {}
local COMMAND_GAP = 0.15

local function clampNumber(v, lo, hi, fallback)
    v = tonumber(v)
    if not v or v ~= v then return fallback end
    if v < lo then v = lo end
    if v > hi then v = hi end
    return v
end

local function profile(name, fn)
    debug.profilebegin(name)
    local ok, err = pcall(fn)
    debug.profileend()
    if not ok then warn("[FTAP V14.4 SERVER] "..name..": "..tostring(err)) end
end

local function fireStatus(player, text, extra)
    if not player or player.Parent ~= Players then return end
    local payload = {kind="STATUS", text=tostring(text), stressMode=stressMode, blobMode=blobMode}
    if type(extra)=="table" then
        for k,v in pairs(extra) do payload[k]=v end
    end
    remote:FireClient(player, payload)
end

local function broadcastStatus(text, extra)
    for p in pairs(controllers) do
        if p.Parent == Players then fireStatus(p,text,extra) else controllers[p]=nil end
    end
end

local function clearChildren(folder)
    if not folder then return end
    for _,x in ipairs(folder:GetChildren()) do pcall(function() x:Destroy() end) end
end

local function stopStress(reason)
    stressGeneration += 1
    stressMode = "IDLE"
    stressParams = {}
    pathOutstanding = 0
    pathClock = 0
    for _,c in ipairs(signalConnections) do pcall(function() c:Disconnect() end) end
    signalConnections={}
    signalEvent=nil
    for _,tw in ipairs(serverTweens) do pcall(function() tw:Cancel() end) end
    serverTweens={}
    if stressConn then pcall(function() stressConn:Disconnect() end); stressConn=nil end
    if stressPool then pcall(function() stressPool:Destroy() end); stressPool=nil end
    if constraintRoot then pcall(function() constraintRoot:Destroy() end); constraintRoot=nil end
    if physicsRoot then pcall(function() physicsRoot:Destroy() end); physicsRoot=nil end
    local transient = runtime:FindFirstChild("Transient")
    if transient then transient:Destroy() end
    if reason then broadcastStatus("server stress stopped: "..tostring(reason)) end
end

local function newFolder(name)
    local old = runtime:FindFirstChild(name)
    if old then old:Destroy() end
    local f=Instance.new("Folder")
    f.Name=name
    f.Parent=runtime
    return f
end

local function cpuBurn(ms)
    local deadline=os.clock()+ms/1000
    local a=0.123456789
    repeat
        for i=1,350 do
            a=(a*1.0000001192092896 + math.sin(i+a)*0.00001337) % 1048576
        end
    until os.clock()>=deadline
    return a
end

local function doQueries(count)
    local origin=Vector3.new(0,64,0)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={runtime}
    for i=1,count do
        local a=i*0.61803398875
        local dir=Vector3.new(math.cos(a)*256, ((i%41)-20)*3, math.sin(a)*256)
        Workspace:Raycast(origin,dir,rp)
        if i%4==0 then Workspace:GetPartBoundsInRadius(origin+Vector3.new((i%31)-15,0,(i%23)-11),32) end
    end
end

local function ensureReplicationPool(count)
    count=math.floor(count)
    if stressPool and stressPool.Parent and #stressPool:GetChildren()>=count then return stressPool end
    if stressPool then stressPool:Destroy() end
    stressPool=newFolder("ReplicationPool")
    for i=1,count do
        local p=Instance.new("Part")
        p.Name="R"..i
        p.Anchored=true
        p.CanCollide=false
        p.CanTouch=false
        p.CanQuery=false
        p.CastShadow=false
        p.Size=Vector3.new(0.3,0.3,0.3)
        p.Position=Vector3.new((i%40)-20, -500-(math.floor(i/40)), (i%31)-15)
        p.Parent=stressPool
    end
    return stressPool
end

local function propertyChurn(count,t)
    local pool=ensureReplicationPool(count)
    local kids=pool:GetChildren()
    for i=1,math.min(count,#kids) do
        local p=kids[i]
        local a=t*2+i*0.17
        p.CFrame=CFrame.new(math.cos(a)*(20+i%30), -500+(i%19), math.sin(a)*(20+i%30))*CFrame.Angles(a,a*0.7,a*0.3)
        p.Transparency=(i+math.floor(t*10))%5/5
        p:SetAttribute("Pulse", (i+math.floor(t*100))%100000)
    end
end

local function instanceChurn(perStep)
    local f=runtime:FindFirstChild("Transient")
    if not f then f=Instance.new("Folder"); f.Name="Transient"; f.Parent=runtime end
    for i=1,perStep do
        local p=Instance.new("Part")
        p.Name="C"
        p.Anchored=true
        p.CanCollide=false
        p.CanTouch=false
        p.CanQuery=false
        p.CastShadow=false
        p.Size=Vector3.new(0.2,0.2,0.2)
        p.Position=Vector3.new((i%25)-12,-700,(i%17)-8)
        p:SetAttribute("Serial", math.random(1,1000000000))
        p.Parent=f
        Debris:AddItem(p,0.35)
    end
end


local function buildServerTweens(count)
    local pool=ensureReplicationPool(count)
    serverTweens={}
    local kids=pool:GetChildren()
    for i=1,math.min(count,#kids) do
        local p=kids[i]
        local target={CFrame=CFrame.new((i%30)-15,-460+(i%17),40+((i%23)-11))*CFrame.Angles(i*0.1,i*0.2,i*0.3)}
        local tw=TweenService:Create(p,TweenInfo.new(0.35+(i%7)*0.03,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,true),target)
        serverTweens[#serverTweens+1]=tw
        tw:Play()
    end
end

local function jointChurn(perStep)
    local f=runtime:FindFirstChild("Transient")
    if not f then f=Instance.new("Folder"); f.Name="Transient"; f.Parent=runtime end
    for i=1,perStep do
        local a=Instance.new("Part")
        a.Name="JA"; a.Anchored=true; a.CanCollide=false; a.Size=Vector3.new(0.25,0.25,0.25)
        a.Position=Vector3.new((i%20)-10,-760,(i%17)-8); a.Parent=f
        local b=Instance.new("Part")
        b.Name="JB"; b.Anchored=false; b.CanCollide=false; b.Size=Vector3.new(0.25,0.25,0.25)
        b.Position=a.Position+Vector3.new(0,1,0); b.Parent=f
        pcall(function() b:SetNetworkOwner(nil) end)
        local aa=Instance.new("Attachment"); aa.Parent=a
        local ab=Instance.new("Attachment"); ab.Parent=b
        local c=Instance.new("BallSocketConstraint")
        c.Attachment0=aa; c.Attachment1=ab; c.Parent=f
        Debris:AddItem(a,0.3); Debris:AddItem(b,0.3); Debris:AddItem(c,0.3)
    end
end

local function buildSignalStorm(listeners)
    if stressPool then stressPool:Destroy() end
    stressPool=newFolder("SignalStorm")
    signalEvent=Instance.new("BindableEvent")
    signalEvent.Name="Pulse"
    signalEvent.Parent=stressPool
    signalConnections={}
    local sink=0
    for n=1,listeners do
        signalConnections[#signalConnections+1]=signalEvent.Event:Connect(function(v)
            sink=(sink+v+n)%1000003
        end)
    end
end

local function buildPhysics(count)
    if physicsRoot then physicsRoot:Destroy() end
    physicsRoot=newFolder("PhysicsBodies")
    for i=1,count do
        local p=Instance.new("Part")
        p.Name="P"..i
        p.Shape=Enum.PartType.Ball
        p.Size=Vector3.new(1.25,1.25,1.25)
        p.CanCollide=true
        p.Position=Vector3.new((i%18)-9,30+math.floor(i/18)*1.35,(i%16)-8)
        p.Parent=physicsRoot
        pcall(function() p:SetNetworkOwner(nil) end)
        p.AssemblyLinearVelocity=Vector3.new(((i%7)-3)*3, -5-(i%5), ((i%11)-5)*2)
        p.AssemblyAngularVelocity=Vector3.new(i%13, i%17, i%19)
    end
end

local function buildConstraints(count)
    if constraintRoot then constraintRoot:Destroy() end
    constraintRoot=newFolder("ConstraintChain")
    local prev=nil
    for i=1,count do
        local p=Instance.new("Part")
        p.Name="K"..i
        p.Size=Vector3.new(0.7,0.7,0.7)
        p.Position=Vector3.new(i*0.8,80+math.sin(i*0.2)*5,0)
        p.CanCollide=(i%3==0)
        p.Anchored=(i==1)
        p.Parent=constraintRoot
        if not p.Anchored then pcall(function() p:SetNetworkOwner(nil) end) end
        local a=Instance.new("Attachment"); a.Parent=p
        if prev then
            local c=Instance.new("BallSocketConstraint")
            c.Attachment0=prev
            c.Attachment1=a
            c.LimitsEnabled=true
            c.UpperAngle=35+(i%40)
            c.Parent=constraintRoot
        end
        prev=a
    end
end

local function pathBurst(jobs)
    if pathOutstanding>=4 then return end
    pathClock=os.clock()
    for j=1,jobs do
        if pathOutstanding>=4 then break end
        pathOutstanding+=1
        task.spawn(function()
            profile("FTAP_PATHFIND",function()
                local p=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
                local o=Vector3.new((j%7)*15,5,(j%11)*12)
                local d=Vector3.new(150-(j%9)*11,5,150-(j%13)*7)
                p:ComputeAsync(o,d)
            end)
            pathOutstanding-=1
        end)
    end
end

local function gcChurn(kb)
    local blocks={}
    local chars=math.max(64,math.floor(kb*1024/24))
    for i=1,math.min(chars,18000) do
        blocks[i]={i,i*3,tostring(i),Vector3.new(i%17,i%23,i%29)}
    end
    return blocks
end

local function sanitize(mode,p)
    p=type(p)=="table" and p or {}
    if mode=="CPU_REDLINE" then
        return {ms=clampNumber(p.ms,0.25,14.0,6)}
    elseif mode=="QUERY_STORM" then
        return {count=math.floor(clampNumber(p.count,10,2500,500))}
    elseif mode=="INSTANCE_CHURN" then
        return {count=math.floor(clampNumber(p.count,1,80,20))}
    elseif mode=="REPLICATION_CHURN" then
        return {count=math.floor(clampNumber(p.count,10,700,180))}
    elseif mode=="PHYSICS_CONTACT" then
        return {count=math.floor(clampNumber(p.count,10,450,160))}
    elseif mode=="CONSTRAINT_SOLVER" then
        return {count=math.floor(clampNumber(p.count,10,260,120))}
    elseif mode=="PATHFIND" then
        return {jobs=math.floor(clampNumber(p.jobs,1,4,2)), interval=clampNumber(p.interval,0.15,2,0.6)}
    elseif mode=="GC_CHURN" then
        return {kb=math.floor(clampNumber(p.kb,16,4096,512))}
    elseif mode=="TWEEN_REPLICATION" then
        return {count=math.floor(clampNumber(p.count,10,320,120))}
    elseif mode=="JOINT_CHURN" then
        return {count=math.floor(clampNumber(p.count,1,40,10))}
    elseif mode=="SIGNAL_STORM" then
        return {fires=math.floor(clampNumber(p.fires,10,2500,500)), listeners=math.floor(clampNumber(p.listeners,1,24,8))}
    elseif mode=="MIXED_REDLINE" then
        return {
            ms=clampNumber(p.ms,1,10,5),
            queries=math.floor(clampNumber(p.queries,20,1200,300)),
            props=math.floor(clampNumber(p.props,20,450,150)),
            churn=math.floor(clampNumber(p.churn,1,40,10))
        }
    end
    return nil
end

local function startStress(mode,p)
    local cfg=sanitize(mode,p)
    if not cfg then return false,"unknown mode" end
    stopStress()
    stressGeneration+=1
    local gen=stressGeneration
    stressMode=mode
    stressParams=cfg
    if mode=="PHYSICS_CONTACT" then buildPhysics(cfg.count) end
    if mode=="CONSTRAINT_SOLVER" then buildConstraints(cfg.count) end
    if mode=="TWEEN_REPLICATION" then buildServerTweens(cfg.count) end
    if mode=="SIGNAL_STORM" then buildSignalStorm(cfg.listeners) end
    stressConn=RunService.Heartbeat:Connect(function(dt)
        if gen~=stressGeneration then return end
        local t=os.clock()
        profile("FTAP_"..mode,function()
            if mode=="CPU_REDLINE" then
                cpuBurn(cfg.ms)
            elseif mode=="QUERY_STORM" then
                doQueries(cfg.count)
            elseif mode=="INSTANCE_CHURN" then
                instanceChurn(cfg.count)
            elseif mode=="REPLICATION_CHURN" then
                propertyChurn(cfg.count,t)
            elseif mode=="PHYSICS_CONTACT" then
                if physicsRoot then
                    local kids=physicsRoot:GetChildren()
                    for i=1,#kids,8 do
                        local x=kids[i]
                        if x:IsA("BasePart") then x.AssemblyLinearVelocity += Vector3.new(math.sin(t+i)*2,-1,math.cos(t-i)*2) end
                    end
                end
            elseif mode=="CONSTRAINT_SOLVER" then
                if constraintRoot then
                    local rootPart=constraintRoot:FindFirstChild("K1")
                    if rootPart then rootPart.CFrame=CFrame.new(math.sin(t*4)*8,80,math.cos(t*3)*8) end
                end
            elseif mode=="PATHFIND" then
                if t-pathClock>=cfg.interval then pathBurst(cfg.jobs) end
            elseif mode=="GC_CHURN" then
                local tmp=gcChurn(cfg.kb)
                if #tmp<0 then warn(tmp) end
            elseif mode=="TWEEN_REPLICATION" then
                if #serverTweens==0 then buildServerTweens(cfg.count) end
            elseif mode=="JOINT_CHURN" then
                jointChurn(cfg.count)
            elseif mode=="SIGNAL_STORM" then
                if signalEvent then for i=1,cfg.fires do signalEvent:Fire(i) end end
            elseif mode=="MIXED_REDLINE" then
                cpuBurn(cfg.ms)
                doQueries(cfg.queries)
                propertyChurn(cfg.props,t)
                instanceChurn(cfg.churn)
            end
        end)
    end)
    return true,cfg
end

local function modelIsPlayerCharacter(model)
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character==model then return true end
    end
    return false
end

local function taggedSafeModel(tag)
    for _,x in ipairs(CollectionService:GetTagged(tag)) do
        local m=x:IsA("Model") and x or x:FindFirstAncestorOfClass("Model")
        if m and m.Parent and not modelIsPlayerCharacter(m) then return m end
    end
    return nil
end

local function taggedSafePart(tag)
    for _,x in ipairs(CollectionService:GetTagged(tag)) do
        local p=x:IsA("BasePart") and x or (x:IsA("Model") and (x.PrimaryPart or x:FindFirstChildWhichIsA("BasePart",true)))
        local m=p and p:FindFirstAncestorOfClass("Model")
        if p and p.Parent and (not m or not modelIsPlayerCharacter(m)) then return p end
    end
    return nil
end

local function buildBlobRig()
    if generatedBlob then generatedBlob:Destroy() end
    if generatedTarget then generatedTarget:Destroy() end
    local m=Instance.new("Model")
    m.Name="FTAPStressBlob"
    local root=Instance.new("Part")
    root.Name="BlobRoot"
    root.Shape=Enum.PartType.Ball
    root.Size=Vector3.new(5,5,5)
    root.Position=Vector3.new(0,15,0)
    root.CanCollide=false
    root.Parent=m
    m.PrimaryPart=root
    m.Parent=runtime
    pcall(function() root:SetNetworkOwner(nil) end)
    CollectionService:AddTag(m,"FTAPStressBlob")

    local target=Instance.new("Part")
    target.Name="FTAPStressTarget"
    target.Anchored=true
    target.CanCollide=false
    target.Transparency=0.35
    target.Size=Vector3.new(3,6,3)
    target.Position=Vector3.new(0,8,18)
    target.Parent=runtime
    CollectionService:AddTag(target,"FTAPStressTarget")
    generatedBlob=m
    generatedTarget=target
    return m,target
end

local function getBlobRoot()
    local m=taggedSafeModel("FTAPStressBlob")
    if not m then return nil end
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("BlobRoot") or m:FindFirstChildWhichIsA("BasePart",true)
end

local function getBlobTarget()
    return taggedSafePart("FTAPStressTarget")
end

local function stopBlob(reason)
    blobGeneration+=1
    blobMode="IDLE"
    blobParams={}
    if blobConn then pcall(function() blobConn:Disconnect() end); blobConn=nil end
    local r=getBlobRoot()
    if r then pcall(function() r.AssemblyLinearVelocity=Vector3.zero; r.AssemblyAngularVelocity=Vector3.zero end) end
    if reason then broadcastStatus("blob loop stopped: "..tostring(reason)) end
end

local function startBlob(mode,p)
    p=type(p)=="table" and p or {}
    local cfg={
        spin=clampNumber(p.spin,0,500,120),
        radius=clampNumber(p.radius,2,60,15),
        speed=clampNumber(p.speed,0.1,15,3),
        height=clampNumber(p.height,0,40,8)
    }
    if mode~="SPIN" and mode~="ORBIT" and mode~="SLAM" and mode~="LOCK" and mode~="CHAOS" then return false,"unknown blob mode" end
    if not getBlobRoot() or not getBlobTarget() then buildBlobRig() end
    stopBlob()
    blobGeneration+=1
    local gen=blobGeneration
    blobMode=mode
    blobParams=cfg
    blobConn=RunService.PreSimulation:Connect(function(dt)
        if gen~=blobGeneration then return end
        local root=getBlobRoot()
        local target=getBlobTarget()
        if not root or not target then return end -- reacquire automatically after replacement/reset
        local t=os.clock()
        profile("FTAP_BLOB_"..mode,function()
            pcall(function() root:SetNetworkOwner(nil) end)
            if mode=="SPIN" then
                root.AssemblyAngularVelocity=Vector3.new(cfg.spin*0.35,cfg.spin,cfg.spin*0.2)
            elseif mode=="ORBIT" then
                local a=t*cfg.speed
                root.CFrame=target.CFrame*CFrame.new(math.cos(a)*cfg.radius,cfg.height,math.sin(a)*cfg.radius)*CFrame.Angles(a*0.7,a*2,a*0.3)
                root.AssemblyAngularVelocity=Vector3.new(0,cfg.spin,0)
            elseif mode=="SLAM" then
                local y=((math.sin(t*cfg.speed*math.pi)>=0) and cfg.height or -cfg.height)
                root.CFrame=target.CFrame*CFrame.new(0,y,0)*CFrame.Angles(t*cfg.speed, t*cfg.speed*2, 0)
                root.AssemblyAngularVelocity=Vector3.new(cfg.spin,cfg.spin,cfg.spin)
            elseif mode=="LOCK" then
                root.CFrame=target.CFrame*CFrame.new(0,cfg.height,0)
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
            elseif mode=="CHAOS" then
                local a=t*cfg.speed
                local r=cfg.radius*(0.55+0.45*math.abs(math.sin(t*1.7)))
                root.CFrame=target.CFrame*CFrame.new(math.cos(a*1.7)*r,math.sin(a*3.1)*cfg.height,math.sin(a*2.3)*r)*CFrame.Angles(a*3,a*5,a*2)
                root.AssemblyLinearVelocity=Vector3.new(math.sin(a*7)*cfg.spin,math.cos(a*5)*cfg.spin*0.4,math.sin(a*3)*cfg.spin)
                root.AssemblyAngularVelocity=Vector3.new(cfg.spin,cfg.spin*1.4,cfg.spin*0.8)
            end
        end)
    end)
    return true,cfg
end

local metricsConn=RunService.Heartbeat:Connect(function(dt)
    heartbeatSamples[#heartbeatSamples+1]=dt
    if #heartbeatSamples>=60 then
        local sum=0
        for i=1,#heartbeatSamples do sum+=heartbeatSamples[i] end
        local avg=sum/#heartbeatSamples
        heartbeatSamples={}
        broadcastStatus(("mode=%s blob=%s avgHeartbeat=%.2fms (~%.1f steps/s)"):format(stressMode,blobMode,avg*1000,1/math.max(avg,0.0001)),{avgHeartbeatMs=avg*1000})
    end
end)

remote.OnServerEvent:Connect(function(player,msg)
    controllers[player]=true
    local now=os.clock()
    if now-(commandLast[player] or 0)<COMMAND_GAP then return end
    commandLast[player]=now
    if type(msg)~="table" then return end
    local action=tostring(msg.action or "")
    if action=="START" then
        local ok,cfg=startStress(tostring(msg.mode or ""),msg.params)
        fireStatus(player,ok and ("started server stress "..tostring(msg.mode)) or ("start failed: "..tostring(cfg)),{config=cfg})
    elseif action=="STOP" then
        stopStress("manual")
        fireStatus(player,"all server stress stopped")
    elseif action=="STATUS" then
        fireStatus(player,"server harness online",{placeId=game.PlaceId,version="14.4"})
    elseif action=="BUILD_BLOB" then
        buildBlobRig()
        fireStatus(player,"server blob test rig rebuilt")
    elseif action=="BLOB_START" then
        local ok,cfg=startBlob(tostring(msg.mode or ""),msg.params)
        fireStatus(player,ok and ("started server blob loop "..tostring(msg.mode)) or ("blob start failed: "..tostring(cfg)),{config=cfg})
    elseif action=="BLOB_STOP" then
        stopBlob("manual")
        fireStatus(player,"server blob loop stopped")
    elseif action=="PANIC" then
        stopStress("PANIC")
        stopBlob("PANIC")
        clearChildren(runtime)
        fireStatus(player,"PANIC cleanup complete")
    end
end)

Players.PlayerRemoving:Connect(function(p) controllers[p]=nil; commandLast[p]=nil end)

game:BindToClose(function()
    stopStress()
    stopBlob()
    if metricsConn then metricsConn:Disconnect() end
end)

print(("[FTAP V14.4 SERVER] READY place=%d remote=%s"):format(game.PlaceId,REMOTE_NAME))
