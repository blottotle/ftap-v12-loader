-- FTAP V12 BLOB/GUCCI PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V12 BLOB] core+shared first"); return end
if A.packs["BLOB"] then return end
A.registerPack("BLOB")
local S=A.shared
local page=A.makePage("BLOB")
local force=true
local retry=0.03

local function seatOwner(blob)
    local seat=blob and blob:FindFirstChild("VehicleSeat")
    local sw=seat and seat:FindFirstChild("SeatWeld")
    local part=sw and sw.Part1
    if not part then return nil end
    local ps=Players:GetPlayers(); local i
    for i=1,#ps do if ps[i].Character and A.isDescendantOf(part,ps[i].Character) then return ps[i] end end
    return nil
end

local function bestForeign()
    local c,h,root=A.getCharacter()
    if not c or not root then return nil,nil,nil end
    local d=Workspace:GetDescendants()
    local bo,boo,bod,bf,bfd=nil,nil,nil,nil,nil
    local i
    for i=1,#d do
        local b=d[i]
        if b:IsA("Model") and b.Name=="CreatureBlobman" then
            local seat=b:FindFirstChild("VehicleSeat"); local br=S.blobRoot(b)
            if seat and br then
                local sw=seat:FindFirstChild("SeatWeld")
                local mine=sw and sw.Part1 and A.isDescendantOf(sw.Part1,c)
                if not mine then
                    local dist=(br.Position-root.Position).Magnitude
                    local owner=seatOwner(b)
                    if owner and owner~=LP then
                        if not bod or dist<bod then bo=b; boo=owner; bod=dist end
                    elseif not sw then
                        if not bfd or dist<bfd then bf=b; bfd=dist end
                    end
                end
            end
        end
    end
    if bo then return bo,boo,bod end
    return bf,nil,bfd
end

local function trySeat(blob,forceTake)
    local c,h,root=A.getCharacter()
    local seat=blob and blob:FindFirstChild("VehicleSeat")
    if not c or not h or not root or not seat then return false,"missing" end
    local sw=seat:FindFirstChild("SeatWeld")
    if sw and sw.Part1 and not A.isDescendantOf(sw.Part1,c) then
        if forceTake then pcall(function() sw:Destroy() end); task.wait()
        else return false,"occupied" end
    end
    pcall(function()
        root.CFrame=seat.CFrame*CFrame.new(0,2.2,0)
        root.AssemblyLinearVelocity=Vector3.new(0,0,0)
        seat:Sit(h)
    end)
    task.wait(0.05)
    local nw=seat:FindFirstChild("SeatWeld")
    if nw and nw.Part1 and A.isDescendantOf(nw.Part1,c) then return true,"mounted" end
    if h.SeatPart==seat then return true,"seated" end
    return false,"failed"
end

A.addSection(page,"AUTO FOREIGN BLOB","Prefers another player's occupied Blobman; free Blobman fallback; instant reacquire if deleted.")
A.addToggle(page,"foreign_force","Force foreign SeatWeld takeover",function() force=true return true end,function() force=false end)
A.toggleState["foreign_force"]=true; A.renderToggle("foreign_force")
A.addSlider(page,"Reacquire seconds",0.01,0.30,0.01,0.03,function(v) retry=v end)

A.addButton(page,"SCAN foreign Blobmen",function()
    local b,o,d=bestForeign()
    if not b then return A.setStatus("No foreign/free Blobman.") end
    A.setStatus("best="..tostring(b).." owner="..tostring(o and o.Name or "free").." dist="..tostring(math.floor((d or 0)+0.5)))
end)

A.addButton(page,"Borrow foreign Blob once",function()
    local b,o,d=bestForeign()
    if not b then return A.setStatus("No Blobman.") end
    local ok,why=trySeat(b,force)
    A.setStatus("borrow="..tostring(ok).." owner="..tostring(o and o.Name or "free").." "..tostring(why))
end,true)

A.addToggle(page,"auto_foreign","AUTO FOREIGN BLOB + instant reacquire",function()
    task.spawn(function()
        while A.toggleState["auto_foreign"] do
            if not S.mountedBlob() then
                local b=select(1,bestForeign())
                if b then trySeat(b,force) end
            end
            task.wait(retry)
        end
    end)
    return true
end,function() end)

A.addSection(page,"Blob Loops",nil)
local delay=0.01
A.addSlider(page,"Loop delay",0.001,0.10,0.001,0.01,function(v) delay=v end)

A.addToggle(page,"blob_loop1","Blob Loop 1 alternating",function()
    task.spawn(function()
        local side="Left"
        while A.toggleState["blob_loop1"] do
            local b=S.mountedBlob(); local p,tr=A.currentTarget()
            if b and p and tr then
                S.blobGrab(b,tr,side,false)
                if side=="Left" then side="Right" else side="Left" end
            end
            task.wait(delay)
        end
    end)
    return true
end,function() end)

A.addToggle(page,"blob_loop2","Blob Loop 2 dual grab/drop",function()
    task.spawn(function()
        while A.toggleState["blob_loop2"] do
            local b=S.mountedBlob(); local p,tr=A.currentTarget()
            if b and p and tr then
                S.blobGrab(b,tr,"Left",false); S.blobGrab(b,tr,"Right",false)
                S.blobDrop(b,tr,"Left"); S.blobDrop(b,tr,"Right")
            end
            task.wait(delay)
        end
    end)
    return true
end,function() end)

A.addToggle(page,"blob_loop3","Blob Loop 3 grab/drop/silent",function()
    task.spawn(function()
        while A.toggleState["blob_loop3"] do
            local b=S.mountedBlob(); local p,tr=A.currentTarget()
            if b and p and tr then
                S.blobGrab(b,tr,"Left",false); task.wait(0.05)
                S.blobDrop(b,tr,"Left"); task.wait(0.05)
                S.blobGrab(b,tr,"Left",true)
            else task.wait(0.05) end
        end
    end)
    return true
end,function() end)

A.addSection(page,"Blob Kick variants",nil)
A.addButton(page,"Blob Kick 1 both-hand x4",function()
    local b=S.mountedBlob(); local p,tr=A.currentTarget()
    if not b or not p or not tr then return A.setStatus("Need mounted Blob + target.") end
    task.spawn(function()
        local i
        for i=1,4 do
            tr=A.targetRoot(p); if not tr then break end
            S.blobGrab(b,tr,"Left",false); S.blobDrop(b,tr,"Left")
            S.blobGrab(b,tr,"Right",false); S.blobDrop(b,tr,"Right")
            task.wait(0.03)
        end
    end)
end,true)

A.addButton(page,"Blob Kick 2 Cosmic upward drop/regrab",function()
    local b=S.mountedBlob(); local p,tr=A.currentTarget(); local br=S.blobRoot(b)
    if not b or not br or not p or not tr then return A.setStatus("Need mounted Blob + target.") end
    local origin=br.CFrame
    task.spawn(function()
        local i
        for i=1,4 do
            tr=A.targetRoot(p); if not tr then break end
            pcall(function() br.CFrame=CFrame.new(origin.Position+Vector3.new(0,10*i,0)); br.AssemblyLinearVelocity=Vector3.new(0,0,0) end)
            task.wait(0.1)
            S.blobDrop(b,tr,"Left"); S.blobDrop(b,tr,"Right"); task.wait(0.1)
            S.blobGrab(b,tr,"Left",false); S.blobGrab(b,tr,"Right",false); task.wait(0.1)
        end
        pcall(function() br.CFrame=origin; br.AssemblyLinearVelocity=Vector3.new(0,0,0) end)
    end)
end,true)

A.addSection(page,"Godman",nil)
local gs,gh,gr=35,3,8
A.addSlider(page,"Godman speed",10,100,5,35,function(v) gs=v end)
A.addSlider(page,"Godman HipHeight",0,15,1,3,function(v) gh=v end)
A.addSlider(page,"Detector radius",2,30,1,8,function(v) gr=v end)
A.addButton(page,"Apply Godman",function()
    local b=S.mountedBlob()
    if not b then return A.setStatus("No mounted Blobman.") end
    local h=b:FindFirstChildOfClass("Humanoid")
    if h then pcall(function() h.WalkSpeed=gs; h.HipHeight=gh end) end
    local names={"LeftDetector","RightDetector"}; local i
    for i=1,2 do local x=b:FindFirstChild(names[i]); if x and x:IsA("BasePart") then pcall(function() x.Size=Vector3.new(gr,gr,gr) end) end end
end)

local gucci=A.makePage("GUCCI")
A.addSection(gucci,"Gucci variants",nil)
local g1blob=nil; local g1save=nil
A.addToggle(gucci,"gucci1","Gucci 1 high-altitude Blob",function()
    local c,h,r=A.getCharacter(); if not c or not h or not r then return false end
    g1save=r.CFrame
    local ok,b=S.spawnToy("CreatureBlobman",CFrame.new(0,50000,0),Vector3.new(0,59.667,0))
    if not b then A.setStatus("Gucci1 spawn failed."); return false end
    g1blob=b
    local seat=b:FindFirstChild("VehicleSeat"); if seat then pcall(function() seat:Sit(h) end) end
    task.spawn(function()
        while A.toggleState["gucci1"] do
            local cc,hh,rr=A.getCharacter(); local refs=S.getRefs()
            if rr then S.fire2(refs.RagdollRemote,rr,0) end
            local br=S.blobRoot(g1blob); if br then pcall(function() br.CFrame=CFrame.new(0,50000,0) end) end
            RunService.Heartbeat:Wait()
        end
    end)
    return true
end,function()
    local c,h,r=A.getCharacter(); if h then h.Sit=false; h.Jump=true end; if r and g1save then r.CFrame=g1save end
end)

A.addButton(gucci,"Gucci 2 local 6s AutoGucci",function()
    local c,h,r=A.getCharacter(); if not c or not h or not r then return end
    local ok,b=S.spawnToy("CreatureBlobman",r.CFrame*CFrame.new(0,0,-5),Vector3.new(0,-15.716,0))
    if not b then return A.setStatus("Gucci2 spawn failed.") end
    task.spawn(function()
        task.wait(1.1); local st=os.clock()
        while os.clock()-st<6 do
            local cc,hh,rr=A.getCharacter(); local refs=S.getRefs(); local seat=b:FindFirstChildWhichIsA("VehicleSeat")
            if seat and hh then pcall(function() seat:Sit(hh) end) end
            if rr then S.fire2(refs.RagdollRemote,rr,0) end
            task.wait(0.1); if hh then pcall(function() hh:ChangeState(Enum.HumanoidStateType.Jumping) end) end; task.wait(0.1)
        end
        S.destroyToy(b)
    end)
end)

A.addButton(gucci,"Gucci 3 seat/jump sweep",function()
    local c,h,r=A.getCharacter(); if not h then return end
    local d=Workspace:GetDescendants(); local i,count=0,0
    for i=1,#d do
        local b=d[i]
        if b:IsA("Model") and b.Name=="CreatureBlobman" then
            local seat=b:FindFirstChild("VehicleSeat")
            if seat then pcall(function() seat:Sit(h) end); task.wait(0.05); pcall(function() h.Jump=true; h:ChangeState(Enum.HumanoidStateType.Jumping) end); count=count+1 end
        end
    end
    A.setStatus("Gucci3 visited "..tostring(count).." seats.")
end)

A.setStatus("BLOB + GUCCI packs loaded.")
print("[FTAP V12 BLOB] READY")
