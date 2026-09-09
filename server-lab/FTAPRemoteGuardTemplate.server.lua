-- FTAP V14R5 DEFENSIVE REMOTE-GUARD TEMPLATE
-- IMPORTANT: put these checks INSIDE your real server remote handlers.
-- A second Script/OnServerEvent listener cannot cancel another listener's callback.

local Players=game:GetService("Players")

local buckets={}
local function allow(player,key,rate,burst,cost)
    cost=cost or 1
    local now=os.clock()
    local id=tostring(player.UserId)..":"..key
    local b=buckets[id]
    if not b then b={tokens=burst,last=now}; buckets[id]=b end
    local dt=math.max(0,now-b.last); b.last=now
    b.tokens=math.min(burst,b.tokens+dt*rate)
    if b.tokens<cost then return false end
    b.tokens=b.tokens-cost
    return true
end

local function finiteNumber(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end

local function finiteVector3(v,maxMagnitude)
    if typeof(v)~="Vector3" then return false end
    if not finiteNumber(v.X) or not finiteNumber(v.Y) or not finiteNumber(v.Z) then return false end
    return v.Magnitude<=(maxMagnitude or 100000)
end

local function finiteCFrame(cf,maxPositionMagnitude)
    if typeof(cf)~="CFrame" then return false end
    return finiteVector3(cf.Position,maxPositionMagnitude or 100000)
end

local function expectedPart(part,container)
    return typeof(part)=="Instance" and part:IsA("BasePart") and (not container or part:IsDescendantOf(container))
end

Players.PlayerRemoving:Connect(function(p)
    local prefix=tostring(p.UserId)..":"
    for k in pairs(buckets) do if k:sub(1,#prefix)==prefix then buckets[k]=nil end end
end)

-- Example shape for YOUR CreateGrabLine handler:
-- CreateGrabLine.OnServerEvent:Connect(function(player, part, cf)
--     if not allow(player,"CreateGrabLine",20,30) then return end
--     if not expectedPart(part, YOUR_ALLOWED_CONTAINER) then return end
--     if not finiteCFrame(cf, 10000) then return end
--     local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
--     if not root or (root.Position-part.Position).Magnitude>YOUR_MAX_GRAB_DISTANCE then return end
--     -- verify server-owned interaction/permission state, then normal game logic
-- end)
--
-- Example shape for YOUR ExtendGrabLine handler:
-- ExtendGrabLine.OnServerEvent:Connect(function(player, payload)
--     if not allow(player,"ExtendGrabLine",30,45) then return end
--     -- Enforce your REAL protocol. If legitimate traffic is not a string, reject strings entirely.
--     if type(payload)=="string" and #payload>YOUR_LEGITIMATE_MAX_BYTES then return end
--     -- normal game logic
-- end)

return {
    allow=allow,
    finiteNumber=finiteNumber,
    finiteVector3=finiteVector3,
    finiteCFrame=finiteCFrame,
    expectedPart=expectedPart,
}
