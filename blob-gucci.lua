-- FTAP V13 BLOB/GUCCI PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end

local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V13 BLOB] core+shared first"); return end
if A.packs["BLOB"] then return end
A.registerPack("BLOB")

local S=A.shared
local page=A.makePage("BLOB")

local force=true
local retry=0.03
local blobSpinSpeed=220
local kickLoopDelay=0.25

local function seatOwner(blob)
    local seat=blob and blob:FindFirstChild("VehicleSeat")
    local sw=seat and seat:FindFirstChild("SeatWeld")
    local part=sw and sw.Part1

    if not part then return nil end

    local ps=Players:GetPlayers()
    local i

    for i=1,#ps do
        if ps[i].Character and A.isDescendantOf(part,ps[i].Character) then
            return ps[i]
        end
    end

    return nil
end

local function bestForeign(exclude)
    local c,h,root=A.getCharacter()
    if not c or not root then return nil,nil,nil end

    local d=Workspace:GetDescendants()
    local bo,boo,bod=nil,nil,nil
    local bf,bfd=nil,nil
    local i

    for i=1,#d do
        local b=d[i]

        if b:IsA("Model") and
           b.Name=="CreatureBlobman" and
           b~=exclude then

            local seat=b:FindFirstChild("VehicleSeat")
            local br=S.blobRoot(b)

            if seat and br then
                local sw=seat:FindFirstChild("SeatWeld")
                local mine=sw and sw.Part1 and A.isDescendantOf(sw.Part1,c)

                if not mine then
                    local dist=(br.Position-root.Position).Magnitude
                    local owner=seatOwner(b)

                    if owner and owner~=LP then
                        if not bod or dist<bod then
                            bo=b
                            boo=owner
                            bod=dist
                        end
                    elseif not sw then
                        if not bfd or dist<bfd then
                            bf=b
                            bfd=dist
                        end
                    end
                end
            end
        end
    end

    if bo then return bo,boo,bod end
    return bf,nil,bfd
end

local function interactAndSeat(blob,forceTake)
    local c,h,root=A.getCharacter()
    local seat=blob and blob:FindFirstChild("VehicleSeat")

    if not c or not h or not root or not seat then
        return false,"missing"
    end

    if blob.Parent==nil then
        return false,"deleted"
    end

    pcall(function()
        root.CFrame=seat.CFrame*CFrame.new(0,2.2,0)
        root.AssemblyLinearVelocity=Vector3.new(0,0,0)
        root.AssemblyAngularVelocity=Vector3.new(0,0,0)
    end)

    -- User requested "teleport to the blob, click it, then do its thing".
    -- Try ClickDetector/Prompt/Touch helpers before Seat:Sit.
    S.tryInteract(root,blob)

    local sw=seat:FindFirstChild("SeatWeld")

    if sw and sw.Part1 and not A.isDescendantOf(sw.Part1,c) then
        if forceTake then
            pcall(function() sw:Destroy() end)
            task.wait()
        else
            return false,"occupied"
        end
    end

    pcall(function()
        seat:Sit(h)
    end)

    task.wait(0.05)

    local nw=seat:FindFirstChild("SeatWeld")

    if nw and nw.Part1 and A.isDescendantOf(nw.Part1,c) then
        return true,"mounted"
    end

    if h.SeatPart==seat then
        return true,"seated"
    end

    -- One more physical overlap fallback.
    pcall(function()
        root.CFrame=seat.CFrame
    end)

    task.wait(0.08)

    pcall(function()
        seat:Sit(h)
    end)

    return h.SeatPart==seat,"fallback"
end

local function ensureBorrowed(exclude)
    local mine=S.mountedBlob()

    if mine and mine.Parent then
        return mine,true,"already mounted"
    end

    local blob,owner,dist=bestForeign(exclude)

    if not blob then
        return nil,false,"no foreign/free Blobman"
    end

    local ok,why=interactAndSeat(blob,force)

    if ok then
        return blob,true,why
    end

    return nil,false,why
end

A.blobAPI={
    bestForeign=bestForeign,
    interactAndSeat=interactAndSeat,
    ensureBorrowed=ensureBorrowed,
    seatOwner=seatOwner
}

A.addSection(page,"AUTO FOREIGN BLOB",
    "Teleports to another player's Blobman, attempts click/prompt/touch interaction, seats you, and immediately reacquires if it disappears.")

A.addToggle(page,"foreign_force","Foreign Blob FORCE takeover",function()
    force=true
    return true
end,function()
    force=false
end)
A.forceToggle("foreign_force",true)

A.addSlider(page,"Foreign Blob reacquire sec",0.01,0.30,0.01,0.03,function(v)
    retry=v
end)

A.addButton(page,"RUN Scan foreign Blobmen",function()
    local b,o,d=bestForeign()

    if not b then
        return A.setStatus("No foreign/free Blobman.")
    end

    A.setStatus(
        "best="..tostring(b)..
        " owner="..tostring(o and o.Name or "free")..
        " dist="..tostring(math.floor((d or 0)+0.5))
    )
end)

A.addButton(page,"RUN Borrow foreign Blob once",function()
    local b,o,d=bestForeign()

    if not b then
        return A.setStatus("No Blobman.")
    end

    local ok,why=interactAndSeat(b,force)

    A.setStatus(
        "borrow="..tostring(ok)..
        " previousOwner="..tostring(o and o.Name or "free")..
        " "..tostring(why)
    )
end,true)

A.addToggle(page,"auto_foreign","AUTO FOREIGN BLOB + instant reacquire",function()
    task.spawn(function()
        while A.toggleState["auto_foreign"] do
            local mine=S.mountedBlob()

            if not mine or mine.Parent==nil then
                ensureBorrowed()
            end

            task.wait(retry)
        end
    end)

    return true
end,function() end)

A.addSection(page,"Blob Loop legacy tests",
    "You reported these do not work well. They remain labeled LEGACY; Kick 3 below is now the primary path.")

local loopDelay=0.01
A.addSlider(page,"Legacy loop delay",0.001,0.10,0.001,0.01,function(v)
    loopDelay=v
end)

A.addToggle(page,"blob_loop1","LEGACY Blob Loop 1 alternating",function()
    task.spawn(function()
        local side="Left"

        while A.toggleState["blob_loop1"] do
            local b=S.mountedBlob()
            local p,tr=A.currentTarget()

            if b and p and tr then
                S.blobGrab(b,tr,side,false)
                if side=="Left" then side="Right" else side="Left" end
            end

            task.wait(loopDelay)
        end
    end)

    return true
end,function() end)

A.addSection(page,"PRIMARY BLOB KICK 3",
    "This is the one you reported working. V13 spins the Blobman during every kick cycle and can loop it until DISABLE.")

A.addSlider(page,"Kick Blob spin speed",0,1500,25,220,function(v)
    blobSpinSpeed=v
end)

A.addSlider(page,"Kick 3 loop delay",0.05,2.00,0.05,0.25,function(v)
    kickLoopDelay=v
end)

local function setBlobSpin(blob,value)
    local br=S.blobRoot(blob)

    if br then
        pcall(function()
            br.AssemblyAngularVelocity=Vector3.new(0,value,0)
        end)
    end
end

local function kick3Cycle()
    local b=S.mountedBlob()

    if not b then
        b=select(1,ensureBorrowed())
    end

    local p,tr=A.currentTarget()
    local br=S.blobRoot(b)

    if not b or not br or not p or not tr then
        return false,"need Blob + target"
    end

    local origin=br.CFrame
    setBlobSpin(b,blobSpinSpeed)

    local i

    for i=1,4 do
        if b.Parent==nil then
            setBlobSpin(b,0)
            return false,"Blob deleted"
        end

        tr=A.targetRoot(p)
        if not tr then
            setBlobSpin(b,0)
            return false,"target gone"
        end

        pcall(function()
            br.CFrame=CFrame.new(origin.Position+Vector3.new(0,10*i,0))
            br.AssemblyLinearVelocity=Vector3.new(0,0,0)
            br.AssemblyAngularVelocity=Vector3.new(0,blobSpinSpeed,0)
        end)

        task.wait(0.1)
        S.blobDrop(b,tr,"Left")
        S.blobDrop(b,tr,"Right")
        task.wait(0.1)
        S.blobGrab(b,tr,"Left",false)
        S.blobGrab(b,tr,"Right",false)
        task.wait(0.1)
    end

    pcall(function()
        br.CFrame=origin
        br.AssemblyLinearVelocity=Vector3.new(0,0,0)
    end)

    setBlobSpin(b,0)
    return true,"cycle complete"
end

A.addButton(page,"RUN Blob Kick 3 ONCE + Blob spin",function()
    task.spawn(function()
        local ok,why=kick3Cycle()
        A.setStatus("Kick3 once="..tostring(ok).." "..tostring(why))
    end)
end,true)

A.addToggle(page,"blob_kick3_loop","LOOP Blob Kick 3 + Blob spin",function()
    task.spawn(function()
        while A.toggleState["blob_kick3_loop"] do
            local ok,why=kick3Cycle()

            if not ok then
                -- Reacquire a replacement Blobman aggressively.
                ensureBorrowed()
            end

            task.wait(kickLoopDelay)
        end

        local b=S.mountedBlob()
        if b then setBlobSpin(b,0) end
    end)

    return true
end,function()
    local b=S.mountedBlob()
    if b then setBlobSpin(b,0) end
end)

A.addSection(page,"Godman",nil)

local gs,gh,gr=35,3,8
A.addSlider(page,"Godman speed",10,100,5,35,function(v) gs=v end)
A.addSlider(page,"Godman HipHeight",0,15,1,3,function(v) gh=v end)
A.addSlider(page,"Detector radius",2,30,1,8,function(v) gr=v end)

A.addButton(page,"RUN Apply Godman",function()
    local b=S.mountedBlob()

    if not b then
        b=select(1,ensureBorrowed())
    end

    if not b then
        return A.setStatus("No Blobman.")
    end

    local h=b:FindFirstChildOfClass("Humanoid")

    if h then
        pcall(function()
            h.WalkSpeed=gs
            h.HipHeight=gh
        end)
    end

    local names={"LeftDetector","RightDetector"}
    local i

    for i=1,2 do
        local x=b:FindFirstChild(names[i])

        if x and x:IsA("BasePart") then
            pcall(function()
                x.Size=Vector3.new(gr,gr,gr)
            end)
        end
    end
end)

-- ============================================================
-- GUCCI: all three use OTHER PLAYERS' Blobmen
-- ============================================================

local gucci=A.makePage("GUCCI")

A.addSection(gucci,"Foreign-Blob Gucci",
    "Every Gucci variant now borrows another player's/free Blobman first instead of spawning its own.")

local function getGucciBlob(exclude)
    local current=S.mountedBlob()

    if current and current.Parent and current~=exclude then
        return current
    end

    return select(1,ensureBorrowed(exclude))
end

A.addToggle(gucci,"gucci1","Gucci 1 foreign high-altitude guard",function()
    task.spawn(function()
        local saved=nil

        while A.toggleState["gucci1"] do
            local b=getGucciBlob()
            local br=S.blobRoot(b)
            local c,h,r=A.getCharacter()
            local refs=S.getRefs()

            if b and br and r then
                if not saved then saved=br.CFrame end

                pcall(function()
                    br.CFrame=CFrame.new(0,50000,0)
                    br.AssemblyLinearVelocity=Vector3.new(0,0,0)
                end)

                S.fire2(refs.RagdollRemote,r,0)
            else
                ensureBorrowed()
            end

            RunService.Heartbeat:Wait()
        end

        local b=S.mountedBlob()
        local br=S.blobRoot(b)

        if br and saved then
            pcall(function() br.CFrame=saved end)
        end
    end)

    return true
end,function() end)

A.addToggle(gucci,"gucci2","Gucci 2 foreign AutoGucci loop",function()
    task.spawn(function()
        while A.toggleState["gucci2"] do
            local b=getGucciBlob()
            local seat=b and b:FindFirstChild("VehicleSeat")
            local c,h,r=A.getCharacter()
            local refs=S.getRefs()

            if b and seat and h and r then
                S.tryInteract(r,b)
                pcall(function() seat:Sit(h) end)
                S.fire2(refs.RagdollRemote,r,0)

                task.wait(0.1)

                pcall(function()
                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            else
                ensureBorrowed()
            end

            task.wait(0.1)
        end
    end)

    return true
end,function() end)

A.addToggle(gucci,"gucci3","Gucci 3 ROTATE foreign Blobmen",function()
    task.spawn(function()
        local last=nil

        while A.toggleState["gucci3"] do
            local b,o,d=bestForeign(last)

            if not b then
                b=select(1,bestForeign())
            end

            if b then
                interactAndSeat(b,true)
                last=b

                local c,h,r=A.getCharacter()
                local refs=S.getRefs()

                if r then
                    S.tryInteract(r,b)
                    S.fire2(refs.RagdollRemote,r,0)
                end

                if h then
                    pcall(function()
                        h.Jump=true
                        h:ChangeState(Enum.HumanoidStateType.Jumping)
                    end)
                end
            end

            task.wait(0.25)
        end
    end)

    return true
end,function() end)

A.setStatus("V13 BLOB/GUCCI loaded. Kick3 is primary + spins Blob + loops.")
print("[FTAP V13 BLOB] READY")
