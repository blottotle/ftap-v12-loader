-- FTAP V14 MOVE / AUTO SLOT PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")

local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end

local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14 MOVE] core+shared first"); return end
if A.packs["MOVE"] then return end
A.registerPack("MOVE")

local S=A.shared
local page=A.makePage("MOVE/SLOT")

-- ============================================================
-- AUTO SLOT / CASINO SPIN
-- ============================================================

A.addSection(page,"AUTO SLOT MACHINE SPIN",
    "FTAP slot machines activate by touching the handle when ready. V13 scans handles, uses executor interaction helpers if available, otherwise physically touches them.")

local slotCooldown=900
local slotGap=0.35
local slotNext={}

local function slotAncestor(part)
    local n=part
    local depth=0

    while n and n~=Workspace and depth<7 do
        local name=string.lower(n.Name)

        if string.find(name,"slot",1,true) or
           string.find(name,"casino",1,true) or
           string.find(name,"coinmachine",1,true) or
           string.find(name,"coin machine",1,true) then
            return n
        end

        n=n.Parent
        depth=depth+1
    end

    return nil
end

local function findSlotHandles()
    local out={}
    local seen={}
    local d=Workspace:GetDescendants()
    local i

    for i=1,#d do
        local x=d[i]

        if x:IsA("BasePart") then
            local n=string.lower(x.Name)

            if string.find(n,"handle",1,true) or
               string.find(n,"lever",1,true) then
                local machine=slotAncestor(x)

                if machine and not seen[x] then
                    seen[x]=true
                    out[#out+1]={handle=x,machine=machine}
                end
            end
        end
    end

    return out
end

local function isBrightRed(part)
    local c=part.Color

    if c.R>0.65 and c.R>c.G*1.4 and c.R>c.B*1.4 then
        return true
    end

    local d=part:GetDescendants()
    local i

    for i=1,#d do
        local x=d[i]

        if x:IsA("PointLight") or
           x:IsA("SurfaceLight") or
           x:IsA("SpotLight") then
            if x.Enabled and x.Brightness>0 then
                local lc=x.Color

                if lc.R>0.65 and lc.R>lc.G*1.3 then
                    return true
                end
            end
        end
    end

    -- Some replicas omit/rename the indicator. Do not block the attempt.
    return true
end

local function spinSlot(entry,forceNow)
    local handle=entry and entry.handle
    local machine=entry and entry.machine
    local c,h,root=A.getCharacter()

    if not handle or not handle.Parent or not root then
        return false,"missing"
    end

    local now=os.clock()
    local nextTime=slotNext[handle] or 0

    if not forceNow and now<nextTime then
        return false,"cooldown"
    end

    if not forceNow and not isBrightRed(handle) then
        return false,"not ready"
    end

    local saved=root.CFrame
    local used=false

    -- Try prompt/click/touch executor APIs first.
    local ok=select(1,S.tryInteract(root,machine))
    used=ok

    if type(firetouchinterest)=="function" then
        local touchOk=pcall(function()
            firetouchinterest(root,handle,0)
            task.wait(0.05)
            firetouchinterest(root,handle,1)
        end)

        if touchOk then used=true end
    end

    -- Physical touch fallback; does not require manual mouse input.
    pcall(function()
        root.CFrame=handle.CFrame
        root.AssemblyLinearVelocity=Vector3.new(0,0,0)
    end)

    task.wait(0.12)

    pcall(function()
        root.CFrame=saved
    end)

    slotNext[handle]=os.clock()+slotCooldown
    return true,used and "API+touch" or "physical touch"
end

A.addSlider(page,"Slot per-machine cooldown sec",30,900,30,900,function(v)
    slotCooldown=v
end)

A.addSlider(page,"Delay between slot machines",0.10,2.00,0.05,0.35,function(v)
    slotGap=v
end)

A.addButton(page,"RUN Scan Slot Machines",function()
    local list=findSlotHandles()
    A.setStatus("Slot handles found="..tostring(#list))
end)

A.addButton(page,"RUN Spin every Slot once NOW",function()
    task.spawn(function()
        local list=findSlotHandles()
        local i,done=0,0

        for i=1,#list do
            local ok=spinSlot(list[i],true)
            if ok then done=done+1 end
            task.wait(slotGap)
        end

        A.setStatus("Forced slot cycle: "..tostring(done).."/"..tostring(#list))
    end)
end)

A.addToggle(page,"auto_slot","AUTO SLOT / CASINO SPIN",function()
    task.spawn(function()
        while A.toggleState["auto_slot"] do
            local list=findSlotHandles()
            local i

            for i=1,#list do
                if not A.toggleState["auto_slot"] then break end

                local ok,why=spinSlot(list[i],false)

                if ok then
                    task.wait(slotGap)
                end
            end

            -- Scan frequently; per-machine cooldown prevents spam.
            task.wait(1)
        end
    end)

    return true
end,function() end)

-- ============================================================
-- MOVEMENT (kept)
-- ============================================================

A.addSection(page,"Movement",nil)

local speed=50
local jump=70

A.addSlider(page,"WalkSpeed",16,120,1,50,function(v)
    speed=v
end)

A.addToggle(page,"speed","Speed force",function()
    task.spawn(function()
        while A.toggleState["speed"] do
            local c,h,r=A.getCharacter()
            if h then h.WalkSpeed=speed end
            RunService.Heartbeat:Wait()
        end
    end)

    return true
end,function()
    local c,h,r=A.getCharacter()
    if h then h.WalkSpeed=16 end
end)

A.addSlider(page,"JumpPower",50,150,5,70,function(v)
    jump=v
end)

A.addToggle(page,"jump","JumpPower force",function()
    task.spawn(function()
        while A.toggleState["jump"] do
            local c,h,r=A.getCharacter()

            if h then
                h.UseJumpPower=true
                h.JumpPower=jump
            end

            RunService.Heartbeat:Wait()
        end
    end)

    return true
end,function()
    local c,h,r=A.getCharacter()
    if h then h.JumpPower=50 end
end)

A.addToggle(page,"noclip","Noclip",function()
    task.spawn(function()
        while A.toggleState["noclip"] do
            local c=LP.Character

            if c then
                local d=c:GetDescendants()
                local i

                for i=1,#d do
                    if d[i]:IsA("BasePart") then
                        d[i].CanCollide=false
                    end
                end
            end

            RunService.Stepped:Wait()
        end
    end)

    return true
end,function() end)

A.addToggle(page,"inf_jump","Infinite Jump",function()
    local conn=UserInputService.JumpRequest:Connect(function()
        if A.toggleState["inf_jump"] then
            local c,h,r=A.getCharacter()

            if h then
                pcall(function()
                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end
    end)

    A.toggleStops["inf_jump"]=function()
        conn:Disconnect()
    end

    return true
end,function()
    if A.toggleStops["inf_jump"] then
        A.toggleStops["inf_jump"]()
        A.toggleStops["inf_jump"]=nil
    end
end)

A.addButton(page,"RUN Teleport behind target",function()
    local p,tr=A.currentTarget()
    local c,h,r=A.getCharacter()

    if p and tr and r then
        r.CFrame=tr.CFrame*CFrame.new(0,0,4)
    end
end)

A.setStatus("V13 MOVE loaded. AUTO SPIN now means SLOT/CASINO SPIN.")
print("[FTAP V14 MOVE] READY")
