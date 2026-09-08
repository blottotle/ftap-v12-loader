-- FTAP V14.4 SERVER STRESS CONTROLLER
-- No local stress is performed here. This page only controls the place-locked
-- server-stress.server.lua harness installed by the game owner.
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A then warn("[FTAP V14.4 SERVER STRESS] core first"); return end
if A.packs["LAG"] then return end
A.registerPack("LAG")

local page=A.makePage("LAG")
local remote=ReplicatedStorage:FindFirstChild("FTAPServerStressControl")

local function refreshRemote()
    remote=ReplicatedStorage:FindFirstChild("FTAPServerStressControl")
    return remote and remote:IsA("RemoteEvent") and remote:GetAttribute("AllowedPlaceId")==game.PlaceId
end
local function send(action,mode,params)
    if not refreshRemote() then
        A.setStatus("SERVER HARNESS OFFLINE: install server-stress.server.lua in ServerScriptService and set ALLOWED_PLACE_ID="..tostring(game.PlaceId))
        return false
    end
    remote:FireServer({action=action,mode=mode,params=params})
    return true
end
local statusConn=nil
local function bindStatus()
    if statusConn then pcall(function() statusConn:Disconnect() end); statusConn=nil end
    if refreshRemote() then
        statusConn=remote.OnClientEvent:Connect(function(msg)
            if type(msg)=="table" and msg.kind=="STATUS" then A.setStatus("SERVER: "..tostring(msg.text)) end
        end)
    end
end
bindStatus()

A.addSection(page,"SERVER-ONLY CONTINUOUS STRESS LAB",
    "No client Beams/GUI/raycast/freeze loops remain. Every test runs on the server harness and continues until STOP/PANIC. Exact PlaceId gating lives in the server script.")
A.addButton(page,"CHECK SERVER HARNESS",function() bindStatus(); send("STATUS") end)

local cpuMs=6
local queryCount=500
local churnCount=20
local replicationCount=180
local physicsCount=160
local constraintCount=120
local pathJobs=2
local gcKB=512
local tweenCount=120
local jointCount=10
local signalFires=500
local signalListeners=8

A.addSlider(page,"CPU redline ms / heartbeat",0.25,14,0.25,6,function(v) cpuMs=v end)
A.addButton(page,"START #1 CPU HEARTBEAT REDLINE",function() send("START","CPU_REDLINE",{ms=cpuMs}) end)

A.addSlider(page,"Server spatial queries / heartbeat",10,2500,10,500,function(v) queryCount=v end)
A.addButton(page,"START #2 SERVER QUERY STORM",function() send("START","QUERY_STORM",{count=queryCount}) end)

A.addSlider(page,"Replicated instances / heartbeat",1,80,1,20,function(v) churnCount=v end)
A.addButton(page,"START #3 INSTANCE CREATE/DESTROY CHURN",function() send("START","INSTANCE_CHURN",{count=churnCount}) end)

A.addSlider(page,"Replicated property pool",10,700,10,180,function(v) replicationCount=v end)
A.addButton(page,"START #4 REPLICATION PROPERTY CHURN",function() send("START","REPLICATION_CHURN",{count=replicationCount}) end)

A.addSlider(page,"Server-owned physics bodies",10,450,10,160,function(v) physicsCount=v end)
A.addButton(page,"START #5 PHYSICS CONTACT LOAD",function() send("START","PHYSICS_CONTACT",{count=physicsCount}) end)

A.addSlider(page,"Constraint chain links",10,260,10,120,function(v) constraintCount=v end)
A.addButton(page,"START #6 CONSTRAINT SOLVER LOAD",function() send("START","CONSTRAINT_SOLVER",{count=constraintCount}) end)

A.addSlider(page,"Path jobs / burst",1,4,1,2,function(v) pathJobs=v end)
A.addButton(page,"START #7 PATHFINDING LOAD",function() send("START","PATHFIND",{jobs=pathJobs,interval=0.6}) end)

A.addSlider(page,"Server allocation churn KB / heartbeat",16,4096,16,512,function(v) gcKB=v end)
A.addButton(page,"START #8 ALLOCATION / GC CHURN",function() send("START","GC_CHURN",{kb=gcKB}) end)

A.addSlider(page,"Server tweened replicated parts",10,320,10,120,function(v) tweenCount=v end)
A.addButton(page,"START #9 SERVER TWEEN REPLICATION",function() send("START","TWEEN_REPLICATION",{count=tweenCount}) end)

A.addSlider(page,"Joint create/destroy pairs / heartbeat",1,40,1,10,function(v) jointCount=v end)
A.addButton(page,"START #10 JOINT / ASSEMBLY CHURN",function() send("START","JOINT_CHURN",{count=jointCount}) end)

A.addSlider(page,"Bindable fires / heartbeat",10,2500,10,500,function(v) signalFires=v end)
A.addSlider(page,"Signal listeners",1,24,1,8,function(v) signalListeners=v end)
A.addButton(page,"START #11 SERVER SIGNAL STORM",function() send("START","SIGNAL_STORM",{fires=signalFires,listeners=signalListeners}) end)

A.addSection(page,"SERVER REDLINE MIX",
    "The mixed preset combines bounded Heartbeat CPU time, spatial queries, replicated property changes and instance churn. It is the closest recoverable server-side analogue to a continuous 'everything feels frozen/behind' condition because low server heartbeat increases latency for all connected clients.")
A.addButton(page,"START #12 MIXED REDLINE",function()
    send("START","MIXED_REDLINE",{ms=math.min(cpuMs,10),queries=math.min(queryCount,1200),props=math.min(replicationCount,450),churn=math.min(churnCount,40)})
end,true)

A.addButton(page,"STOP SERVER STRESS",function() send("STOP") end)
A.addButton(page,"PANIC: STOP + DELETE TEST RUNTIME",function() send("PANIC") end,true)

A.toggleStops["server_stress_controller_cleanup"]=function()
    if statusConn then pcall(function() statusConn:Disconnect() end); statusConn=nil end
end

A.setStatus("V14.4 LAG loaded: server-only stress controller; local stress removed.")
print("[FTAP V14.4 LAG] READY")
