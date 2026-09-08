-- FTAP V14.4 SERVER BLOB LOOP CONTROLLER
-- Previous client-side target/takeover/self-physics loops removed.
-- All blob motion is performed by server-stress.server.lua on a tagged test blob.
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A then warn("[FTAP V14.4 BLOB] core first"); return end
if A.packs["BLOB"] then return end
A.registerPack("BLOB")

local page=A.makePage("BLOB")
local remote=nil
local statusConn=nil

local function refreshRemote()
    remote=ReplicatedStorage:FindFirstChild("FTAPServerStressControl")
    return remote and remote:IsA("RemoteEvent") and remote:GetAttribute("AllowedPlaceId")==game.PlaceId
end
local function send(action,mode,params)
    if not refreshRemote() then
        A.setStatus("SERVER BLOB HARNESS OFFLINE: install server-stress.server.lua and set ALLOWED_PLACE_ID="..tostring(game.PlaceId))
        return false
    end
    remote:FireServer({action=action,mode=mode,params=params})
    return true
end
local function bindStatus()
    if statusConn then pcall(function() statusConn:Disconnect() end); statusConn=nil end
    if refreshRemote() then
        statusConn=remote.OnClientEvent:Connect(function(msg)
            if type(msg)=="table" and msg.kind=="STATUS" then A.setStatus("SERVER: "..tostring(msg.text)) end
        end)
    end
end
bindStatus()

A.addSection(page,"SERVER BLOB LOOP LAB",
    "All old client-side target/takeover/self Blob loops are removed. The server harness continually reacquires CollectionService tags FTAPStressBlob + FTAPStressTarget, so replacing/resetting either object does not kill the loop. Player Character models are explicitly rejected as stress targets.")

local spin=120
local radius=15
local speed=3
local height=8
A.addSlider(page,"Server blob spin",0,500,5,120,function(v) spin=v end)
A.addSlider(page,"Orbit radius",2,60,1,15,function(v) radius=v end)
A.addSlider(page,"Loop speed",0.1,15,0.1,3,function(v) speed=v end)
A.addSlider(page,"Vertical range / lock height",0,40,1,8,function(v) height=v end)

A.addButton(page,"BUILD / RESET SERVER BLOB TEST RIG",function() bindStatus(); send("BUILD_BLOB") end)
A.addButton(page,"START BLOB #1 CONTINUOUS SPIN",function() send("BLOB_START","SPIN",{spin=spin,radius=radius,speed=speed,height=height}) end)
A.addButton(page,"START BLOB #2 CONTINUOUS ORBIT",function() send("BLOB_START","ORBIT",{spin=spin,radius=radius,speed=speed,height=height}) end)
A.addButton(page,"START BLOB #3 CONTINUOUS SLAM",function() send("BLOB_START","SLAM",{spin=spin,radius=radius,speed=speed,height=height}) end)
A.addButton(page,"START BLOB #4 HARD LOCK",function() send("BLOB_START","LOCK",{spin=spin,radius=radius,speed=speed,height=height}) end)
A.addButton(page,"START BLOB #5 CHAOS LOOP",function() send("BLOB_START","CHAOS",{spin=spin,radius=radius,speed=speed,height=height}) end,true)
A.addButton(page,"STOP SERVER BLOB LOOP",function() send("BLOB_STOP") end)
A.addButton(page,"PANIC SERVER CLEANUP",function() send("PANIC") end,true)

A.toggleStops["server_blob_controller_cleanup"]=function()
    if statusConn then pcall(function() statusConn:Disconnect() end); statusConn=nil end
end

A.setStatus("V14.4 BLOB loaded: server-only continuous blob test controller.")
print("[FTAP V14.4 BLOB] READY")
