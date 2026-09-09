-- FTAP V14R3 DEFENSIVE REMOTE-GUARD TEMPLATE
-- Put the limiter INSIDE your own server remote handlers. A second Script cannot cancel
-- another Script's OnServerEvent callback after Roblox has already dispatched it.

local Players=game:GetService("Players")

local buckets={}
local function allow(player,key,rate,burst,cost)
    cost=cost or 1
    local now=os.clock()
    local id=tostring(player.UserId)..":"..key
    local b=buckets[id]
    if not b then b={tokens=burst,last=now}; buckets[id]=b end
    local dt=now-b.last; b.last=now
    b.tokens=math.min(burst,b.tokens+dt*rate)
    if b.tokens<cost then return false end
    b.tokens=b.tokens-cost
    return true
end

Players.PlayerRemoving:Connect(function(p)
    local prefix=tostring(p.UserId)..":"
    for k in pairs(buckets) do if k:sub(1,#prefix)==prefix then buckets[k]=nil end end
end)

-- Example for YOUR handler:
-- CreateGrabLine.OnServerEvent:Connect(function(player, part, cf)
--     if not allow(player,"CreateGrabLine",30,60,1) then return end
--     if typeof(part)~="Instance" or not part:IsA("BasePart") then return end
--     if typeof(cf)~="CFrame" then return end
--     -- normal game logic here
-- end)
--
-- ExtendGrabLine.OnServerEvent:Connect(function(player, payload)
--     if type(payload)=="string" and #payload>4096 then return end
--     if not allow(player,"ExtendGrabLine",20,40,1) then return end
--     -- normal game logic here
-- end)

return allow
