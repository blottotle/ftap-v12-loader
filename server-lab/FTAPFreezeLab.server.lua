-- FTAP V14R3 OWN-GAME FREEZE REPRO LAB
-- Put this file in ServerScriptService in YOUR game.
-- No PlaceId lock. Actions are intentionally restricted to Studio/private servers.
-- The old bootstrap/loader does not load this server script.

local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local control=ReplicatedStorage:FindFirstChild("FTAPFreezeLabControl") or Instance.new("RemoteEvent")
control.Name="FTAPFreezeLabControl"
control.Parent=ReplicatedStorage

local status=ReplicatedStorage:FindFirstChild("FTAPFreezeLabStatus") or Instance.new("RemoteEvent")
status.Name="FTAPFreezeLabStatus"
status.Parent=ReplicatedStorage

local folder=Workspace:FindFirstChild("FTAPFreezeLabObjects") or Instance.new("Folder")
folder.Name="FTAPFreezeLabObjects"
folder.Parent=Workspace

local token=0
local hbConn=nil
local netActive=false
local netStopAt=0
local netWindowStart=os.clock()
local netCalls=0
local netBytes=0
local MAX_SECONDS=8
local MAX_STALL_MS=100
local MAX_PAYLOAD=8192
local MAX_NET_CALLS_PER_SEC=300

local function allowed()
    return RunService:IsStudio() or game.PrivateServerId~=""
end

local function cleanupObjects()
    folder:ClearAllChildren()
end

local function stopAll(reason)
    token=token+1
    netActive=false
    if hbConn then hbConn:Disconnect(); hbConn=nil end
    cleanupObjects()
    status:FireAllClients("stopped",reason or "stop")
end

local function busyFor(ms)
    local untilT=os.clock()+math.clamp(ms,0,MAX_STALL_MS)/1000
    local x=0
    while os.clock()<untilT do
        x=(x*1664525+1013904223)%2147483647
    end
    return x
end

local function makeReplicatedPool(count)
    cleanupObjects()
    count=math.clamp(count,1,128)
    for i=1,count do
        local p=Instance.new("Part")
        p.Name="LabPart"..i
        p.Anchored=true
        p.CanCollide=false
        p.Size=Vector3.new(1,1,1)
        p.CFrame=CFrame.new((i%16)*2,5000+math.floor(i/16)*2,0)
        p.Parent=folder
    end
end

local function startStall(ms,seconds,mixed)
    stopAll("restart")
    local myToken=token
    seconds=math.clamp(tonumber(seconds) or 5,1,MAX_SECONDS)
    ms=math.clamp(tonumber(ms) or 50,1,MAX_STALL_MS)
    local endAt=os.clock()+seconds
    if mixed then makeReplicatedPool(96) end
    local tickN=0
    hbConn=RunService.Heartbeat:Connect(function()
        if myToken~=token or os.clock()>=endAt then stopAll("completed"); return end
        tickN=tickN+1
        busyFor(ms)
        if mixed then
            local parts=folder:GetChildren()
            for i=1,#parts do
                local p=parts[i]
                p.CFrame=p.CFrame*CFrame.Angles(0,0.02+(i%3)*0.005,0)
                p:SetAttribute("Pulse",tickN%1000)
            end
        end
    end)
    status:FireAllClients("started",mixed and "mixed" or "stall",ms,seconds)
end

control.OnServerEvent:Connect(function(player,cmd,a,b)
    if not allowed() then
        status:FireClient(player,"denied","Studio/private-server only")
        return
    end
    if cmd=="stop" then stopAll("client stop"); return end
    if cmd=="stall" then startStall(a,b,false); return end
    if cmd=="mixed" then startStall(35,a,true); return end
    if cmd=="beginNet" then
        netActive=true
        netStopAt=os.clock()+math.clamp(tonumber(a) or 5,1,MAX_SECONDS)
        netWindowStart=os.clock(); netCalls=0; netBytes=0
        status:FireAllClients("started","net",a)
        return
    end
    if cmd=="netPulse" and netActive then
        if os.clock()>=netStopAt then netActive=false; status:FireAllClients("stopped","net complete"); return end
        local now=os.clock()
        if now-netWindowStart>=1 then
            status:FireAllClients("netRate",netCalls,netBytes)
            netWindowStart=now; netCalls=0; netBytes=0
        end
        if netCalls>=MAX_NET_CALLS_PER_SEC then return end
        if type(a)~="string" then return end
        local n=math.min(#a,MAX_PAYLOAD)
        netCalls=netCalls+1; netBytes=netBytes+n
        -- Bounded server work representing validation/serialization pressure.
        local checksum=0
        for i=1,n,64 do checksum=(checksum+string.byte(a,i))%65535 end
        folder:SetAttribute("LastChecksum",checksum)
        folder:SetAttribute("NetCount",(folder:GetAttribute("NetCount") or 0)+1)
    end
end)

game:BindToClose(function() stopAll("shutdown") end)
print("[FTAP Freeze Lab] ready; Studio/private-server only")
