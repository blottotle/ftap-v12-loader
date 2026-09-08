-- FTAP V14.1 BLOB / GUCCI - VOVANGE-ONLY CLEANUP
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14 BLOB] core+shared first"); return end
if A.packs["BLOB"] then return end
A.registerPack("BLOB")
local S=A.shared

local page=A.makePage("BLOB")
local foreignForce=true
local foreignRetry=0.03
local extraSpin=0

local function blobSeatOwner(blob)
    local seat=blob and blob:FindFirstChild("VehicleSeat")
    local sw=seat and seat:FindFirstChild("SeatWeld")
    local part=sw and sw.Part1
    if not part then return nil end
    local ps=Players:GetPlayers()
    local i
    for i=1,#ps do
        if ps[i].Character and A.isDescendantOf(part,ps[i].Character) then return ps[i] end
    end
    return nil
end

local function bestForeign(exclude)
    local c,h,root=A.getCharacter()
    if not c or not root then return nil,nil,nil end
    local d=Workspace:GetDescendants()
    local occ,occOwner,occDist=nil,nil,nil
    local free,freeDist=nil,nil
    local i
    for i=1,#d do
        local b=d[i]
        if b:IsA("Model") and b.Name=="CreatureBlobman" and b~=exclude then
            local seat=b:FindFirstChild("VehicleSeat")
            local br=S.blobRoot(b)
            if seat and br then
                local sw=seat:FindFirstChild("SeatWeld")
                local mine=sw and sw.Part1 and A.isDescendantOf(sw.Part1,c)
                if not mine then
                    local dist=(br.Position-root.Position).Magnitude
                    local owner=blobSeatOwner(b)
                    if owner and owner~=LP then
                        if not occDist or dist<occDist then occ=b; occOwner=owner; occDist=dist end
                    elseif not sw then
                        if not freeDist or dist<freeDist then free=b; freeDist=dist end
                    end
                end
            end
        end
    end
    if occ then return occ,occOwner,occDist end
    return free,nil,freeDist
end

local function borrow(blob,force)
    local c,h,root=A.getCharacter()
    local seat=blob and blob:FindFirstChild("VehicleSeat")
    if not c or not h or not root or not seat then return false,"missing" end

    pcall(function()
        root.CFrame=seat.CFrame*CFrame.new(0,1,0)
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end)
    S.tryInteract(root,blob)

    local sw=seat:FindFirstChild("SeatWeld")
    if sw and sw.Part1 and not A.isDescendantOf(sw.Part1,c) then
        if force then
            pcall(function() sw:Destroy() end)
            task.wait()
        else
            return false,"occupied"
        end
    end

    local start=os.clock()
    repeat
        pcall(function()
            root.CFrame=seat.CFrame*CFrame.new(0,1,0)
            seat:Sit(h)
        end)
        RunService.Heartbeat:Wait()
    until h.SeatPart==seat or os.clock()-start>1.5

    return h.SeatPart==seat,h.SeatPart==seat and "mounted" or "seat failed"
end

local function ensureBlob()
    local b=S.mountedBlob()
    if b and b.Parent then return b,true end
    local f=select(1,bestForeign())
    if not f then return nil,false end
    local ok=select(1,borrow(f,foreignForce))
    if ok then return S.mountedBlob() or f,true end
    return nil,false
end

A.blobAPI={bestForeign=bestForeign,borrow=borrow,ensureBorrowed=ensureBlob}

A.addSection(page,"FOREIGN BLOB AUTO",
    "Uses another player's Blob if possible. Exact kick sources still require you to be genuinely seated on the Blobman.")

A.addToggle(page,"foreign_force","Foreign Blob FORCE takeover",function() foreignForce=true return true end,function() foreignForce=false end)
A.forceToggle("foreign_force",true)
A.addSlider(page,"Foreign retry sec",0.01,0.30,0.01,0.03,function(v) foreignRetry=v end)

A.addButton(page,"RUN Borrow foreign Blob",function()
    local b,o,d=bestForeign()
    if not b then return A.setStatus("No foreign/free Blobman.") end
    local ok,why=borrow(b,foreignForce)
    A.setStatus("borrow="..tostring(ok).." owner="..tostring(o and o.Name or "free").." "..tostring(why))
end)

A.addToggle(page,"auto_foreign","AUTO FOREIGN BLOB",function()
    task.spawn(function()
        while A.toggleState["auto_foreign"] do
            if not S.mountedBlob() then ensureBlob() end
            task.wait(foreignRetry)
        end
    end)
    return true
end,function() end)

A.addSection(page,"BLOB KICK - VOVANGE ONLY",
    "Legacy TheWorst / SpinGrab / generic Critcl kick controls were removed. This retains the existing VOVange hard path you reported as working.")

A.addSlider(page,"Extra Blob angular spin",0,1200,25,0,function(v) extraSpin=v end)

local function kickContext()
    local b,ok=ensureBlob()
    if not b then return nil,"no mounted Blob" end

    local c,h,root=A.getCharacter()
    local p,tr=A.currentTarget()
    if not p or not tr then return nil,"target missing" end

    local tChar=p.Character
    local tHum=tChar and tChar:FindFirstChildOfClass("Humanoid")
    local br=S.blobRoot(b)
    local holder=b:FindFirstChild("BlobmanSeatAndOwnerScript")
    local cg=holder and holder:FindFirstChild("CreatureGrab")
    local cd=holder and holder:FindFirstChild("CreatureDrop")
    local rd,rw=S.blobRight(b)
    local refs=S.getRefs()

    if not h or not h.SeatPart or h.SeatPart.Parent~=b then return nil,"not actually seated on Blob" end
    if not br or not cg or not cd or not rd or not rw then return nil,"Blob remotes/weld missing" end
    if not refs.SetNetworkOwner or not refs.CreateGrabLine or not refs.DestroyGrabLine then return nil,"GrabEvents kick remotes missing" end
    if not tHum then return nil,"target Humanoid missing" end

    return {
        blob=b,blobRoot=br,cg=cg,cd=cd,rd=rd,rw=rw,
        refs=refs,target=p,tChar=tChar,tRoot=tr,tHum=tHum
    },nil
end

local function applyExtraSpin(ctx)
    if extraSpin>0 and ctx and ctx.blobRoot then
        pcall(function() ctx.blobRoot.AssemblyAngularVelocity=Vector3.new(0,extraSpin,0) end)
    end
end

local function clearExtraSpin(ctx)
    if ctx and ctx.blobRoot then
        pcall(function() ctx.blobRoot.AssemblyAngularVelocity=Vector3.zero end)
    end
end

local function runVovangeHard(toggleKey)
    local ctx,why=kickContext()
    if not ctx then A.setStatus("VOVANGE preflight: "..tostring(why)); return false end
    local saved=ctx.blobRoot.CFrame
    local dragging=false
    local grabStart=0
    local lastRemote=0
    local lockPos=saved*CFrame.new(0,23,0)

    while A.toggleState[toggleKey] do
        local tr=ctx.target.Character and ctx.target.Character:FindFirstChild("HumanoidRootPart")
        local th=ctx.target.Character and ctx.target.Character:FindFirstChildOfClass("Humanoid")
        if not tr or not th or th.Health<=0 then RunService.Heartbeat:Wait() else
            tr.Velocity=Vector3.zero
            if not dragging then
                ctx.blobRoot.CFrame=tr.CFrame
                ctx.blobRoot.Velocity=Vector3.zero
                applyExtraSpin(ctx)
                if os.clock()-lastRemote>=0.002 then
                    lastRemote=os.clock()
                    th.PlatformStand=true
                    th.Sit=true
                    S.fire2(ctx.refs.SetNetworkOwner,tr,ctx.blobRoot.CFrame)
                    S.fire1(ctx.refs.DestroyGrabLine,tr)
                end
                if grabStart==0 then grabStart=os.clock() end
                if os.clock()-grabStart>0.35 then
                    dragging=true
                    grabStart=0
                    ctx.blobRoot.CFrame=saved
                    ctx.blobRoot.Velocity=Vector3.zero
                end
            else
                ctx.blobRoot.CFrame=saved
                ctx.blobRoot.Velocity=Vector3.zero
                applyExtraSpin(ctx)
                tr.CFrame=lockPos
                th.PlatformStand=true
                th.Sit=true
                if os.clock()-lastRemote>=0.002 then
                    lastRemote=os.clock()
                    S.fire2(ctx.refs.SetNetworkOwner,tr,lockPos)
                    S.fire1(ctx.refs.DestroyGrabLine,tr)
                    S.blobDropOne(ctx.blob,"Right")
                    S.fire3(ctx.cg,ctx.rd,tr,ctx.rw)
                end
            end
            RunService.Heartbeat:Wait()
        end
    end

    pcall(function() ctx.blobRoot.CFrame=saved; ctx.blobRoot.Velocity=Vector3.zero end)
    clearExtraSpin(ctx)
end

A.addToggle(page,"kick_b_loop","LOOP VOVANGE BLOB - HARD",function()
    task.spawn(function() runVovangeHard("kick_b_loop") end)
    return true
end,function() end)

A.addButton(page,"BLOB KICK PREFLIGHT",function()
    local ctx,why=kickContext()
    if not ctx then return A.setStatus("FAIL: "..tostring(why)) end
    A.setStatus("PASS: seated Blob + RightDetector/Weld + SNO/Create/DestroyGrabLine + target Humanoid")
end)

-- Foreign Blob Gucci remains experimental because public Gucci sources normally spawn/own their own Blob.
local gucci=A.makePage("GUCCI")
A.addSection(gucci,"FOREIGN BLOB GUCCI",
    "Experimental adaptation: public Anti-Gucci logic normally uses your own Blob. These variants borrow a foreign/free Blob first.")

A.addToggle(gucci,"gucci_foreign","Foreign Blob AutoGucci",function()
    task.spawn(function()
        local safe=nil
        while A.toggleState["gucci_foreign"] do
            local b=select(1,ensureBlob())
            local c,h,r=A.getCharacter()
            local refs=S.getRefs()
            if b and h and r then
                if not safe then safe=r.CFrame end
                local seat=b:FindFirstChild("VehicleSeat")
                if seat and h.SeatPart~=seat then borrow(b,true) end
                S.fire2(refs.RagdollRemote,r,0)
                if h.Jump and h.Sit then
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
                end
            end
            task.wait(0.1)
        end
        local c,h,r=A.getCharacter()
        if safe and r then pcall(function() r.CFrame=safe end) end
    end)
    return true
end,function() end)

A.setStatus("V14.1 BLOB loaded: Vovange-only kick cleanup + Gucci utilities.")
print("[FTAP V14.1 BLOB] READY")
