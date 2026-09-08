-- FTAP V14R2 SHARED - ORIGINAL CALL SEMANTICS + DEBUG2 OBSERVER
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A then warn("[FTAP V14 SHARED] core first"); return end
if A.packs["SHARED"] then return end
A.registerPack("SHARED")

local S={}
A.shared=S

function S.pathOf(x)
    if x==nil then return "nil" end
    local ok,r=pcall(function() return x:GetFullName() end)
    if ok then return r end
    return x.Name
end

local function observedRemoteCall(r,args)
    if not r or not r:IsA("RemoteEvent") then return false end
    local started=os.clock()
    local ok,err=pcall(function() r:FireServer(unpack(args)) end)
    if type(A.debug2ObserveRemote)=="function" then
        pcall(A.debug2ObserveRemote,r,args,ok,err,os.clock()-started,"FireServer")
    end
    return ok,err
end

function S.fire0(r) return observedRemoteCall(r,{}) end
function S.fire1(r,a) return observedRemoteCall(r,{a}) end
function S.fire2(r,a,b) return observedRemoteCall(r,{a,b}) end
function S.fire3(r,a,b,c) return observedRemoteCall(r,{a,b,c}) end
function S.fire4(r,a,b,c,d) return observedRemoteCall(r,{a,b,c,d}) end

function S.findRemoteContains(words,excludes)
    local d=ReplicatedStorage:GetDescendants()
    local i,j
    for i=1,#d do
        local x=d[i]
        if x:IsA("RemoteEvent") or x:IsA("RemoteFunction") then
            local n=string.lower(x.Name)
            local ok=true
            for j=1,#words do
                if string.find(n,string.lower(words[j]),1,true)==nil then
                    ok=false
                    break
                end
            end
            if ok and excludes then
                for j=1,#excludes do
                    if string.find(n,string.lower(excludes[j]),1,true)~=nil then
                        ok=false
                        break
                    end
                end
            end
            if ok then return x end
        end
    end
    return nil
end

function S.getRefs()
    local r=A.getRefs()
    local ge=ReplicatedStorage:FindFirstChild("GrabEvents")
    local ce=ReplicatedStorage:FindFirstChild("CharacterEvents")
    local pe=ReplicatedStorage:FindFirstChild("PlayerEvents")
    local mt=ReplicatedStorage:FindFirstChild("MenuToys")
    local gc=ReplicatedStorage:FindFirstChild("GameCorrectionEvents")

    if ge then
        r.SetNetworkOwner=ge:FindFirstChild("SetNetworkOwner") or r.SetNetworkOwner
        r.CreateGrabLine=ge:FindFirstChild("CreateGrabLine") or r.CreateGrabLine
        r.DestroyGrabLine=ge:FindFirstChild("DestroyGrabLine") or r.DestroyGrabLine
        r.ExtendGrabLine=ge:FindFirstChild("ExtendGrabLine")
        r.CreateGrabEvent=ge:FindFirstChild("CreateGrabEvent") or ge:FindFirstChild("CreateGrab")
    end
    if ce then
        r.Struggle=ce:FindFirstChild("Struggle") or r.Struggle
        r.RagdollRemote=ce:FindFirstChild("RagdollRemote") or r.RagdollRemote
    end
    if pe then
        r.StickyPartEvent=pe:FindFirstChild("StickyPartEvent")
    end
    if mt then
        r.SpawnToy=mt:FindFirstChild("SpawnToyRemoteFunction")
        r.DestroyToy=mt:FindFirstChild("DestroyToy") or mt:FindFirstChild("DestroyToyEvent")
    end
    if gc then
        r.StopAllVelocity=gc:FindFirstChild("StopAllVelocity") or r.StopAllVelocity
    end

    if not r.ExtendGrabLine then r.ExtendGrabLine=A.findRemote("ExtendGrabLine") end
    if not r.CreateGrabLine then r.CreateGrabLine=A.findRemote("CreateGrabLine") end
    if not r.DestroyGrabLine then r.DestroyGrabLine=A.findRemote("DestroyGrabLine") end
    if not r.StickyPartEvent then r.StickyPartEvent=A.findRemote("StickyPartEvent") end
    if not r.SpawnToy then r.SpawnToy=A.findRemote("SpawnToyRemoteFunction") end
    if not r.DestroyToy then r.DestroyToy=A.findRemote("DestroyToy") end
    if not r.CreateGrabEvent then
        r.CreateGrabEvent=S.findRemoteContains({"create","grab"},{"line"})
    end
    return r
end

local function addUnique(out,seen,x)
    if x and x.Parent and not seen[x] then
        seen[x]=true
        out[#out+1]=x
    end
end

function S.ownToyFolders()
    local out={}
    local seen={}

    addUnique(out,seen,Workspace:FindFirstChild(LP.Name.."SpawnedInToys"))

    local st=Workspace:FindFirstChild("st")
    if st then
        addUnique(out,seen,st:FindFirstChild(LP.Name.."SpawnedInToys"))
    end

    local plots=Workspace:FindFirstChild("Plots")
    local plotItems=Workspace:FindFirstChild("PlotItems")
    if plots and plotItems then
        local pk=plots:GetChildren()
        local i,j
        for i=1,#pk do
            local plot=pk[i]
            local sign=plot:FindFirstChild("PlotSign")
            local owners=sign and sign:FindFirstChild("ThisPlotsOwners")
            local mine=false

            if owners then
                local kids=owners:GetChildren()
                for j=1,#kids do
                    local v=kids[j]
                    local ok,val=pcall(function() return v.Value end)
                    if ok and tostring(val)==LP.Name then
                        mine=true
                        break
                    end
                end

                if not mine then
                    local ok,val=pcall(function() return owners.Value end)
                    if ok and tostring(val)==LP.Name then mine=true end
                end
            end

            if mine then
                addUnique(out,seen,plotItems:FindFirstChild(plot.Name))
            end
        end
    end

    return out
end

function S.describeToyFolders()
    local fs=S.ownToyFolders()
    local names={}
    local i
    for i=1,#fs do names[#names+1]=S.pathOf(fs[i]) end
    return names
end

function S.findOwnToys(name)
    local out={}
    local fs=S.ownToyFolders()
    local i,j
    for i=1,#fs do
        local kids=fs[i]:GetChildren()
        for j=1,#kids do
            if kids[j].Name==name then out[#out+1]=kids[j] end
        end
    end
    return out
end

function S.findOwnToy(name)
    local xs=S.findOwnToys(name)
    return xs[1]
end

function S.waitNewToy(name,before,seconds)
    local old={}
    local i
    for i=1,#before do old[before[i]]=true end
    local start=os.clock()
    while os.clock()-start<seconds do
        local now=S.findOwnToys(name)
        for i=1,#now do
            if not old[now[i]] then return now[i] end
        end
        if #now>0 and #before==0 then return now[1] end
        task.wait(0.05)
    end
    return S.findOwnToy(name)
end

function S.spawnToy(name,cf,rot)
    local r=S.getRefs()
    if not r.SpawnToy or not r.SpawnToy:IsA("RemoteFunction") then return false,nil end
    local before=S.findOwnToys(name)
    local args={name,cf,rot or Vector3.new(0,0,0)}
    local started=os.clock()
    local ok,err=pcall(function()
        r.SpawnToy:InvokeServer(unpack(args))
    end)
    if type(A.debug2ObserveRemote)=="function" then
        pcall(A.debug2ObserveRemote,r.SpawnToy,args,ok,err,os.clock()-started,"InvokeServer")
    end
    if not ok then return false,nil end
    local toy=S.waitNewToy(name,before,2)
    return toy~=nil,toy
end

function S.destroyToy(toy)
    if not toy then return false end
    local r=S.getRefs()
    if r.DestroyToy and r.DestroyToy:IsA("RemoteEvent") then
        return S.fire1(r.DestroyToy,toy)
    end
    return pcall(function() toy:Destroy() end)
end

function S.currentGrabbedPart()
    local gp=Workspace:FindFirstChild("GrabParts")
    local g=gp and gp:FindFirstChild("GrabPart")
    local w=g and g:FindFirstChild("WeldConstraint")
    return w and w.Part1 or nil,gp
end

function S.ancestorHumanoidModel(part)
    local n=part
    while n and n~=Workspace do
        if n:IsA("Model") and n:FindFirstChildOfClass("Humanoid") then return n end
        n=n.Parent
    end
    return nil
end

function S.allPartsNamed(name)
    local out={}
    local d=Workspace:GetDescendants()
    local i
    for i=1,#d do
        if d[i]:IsA("BasePart") and d[i].Name==name then out[#out+1]=d[i] end
    end
    return out
end

function S.parkParts(parts)
    local i
    for i=1,#parts do
        if parts[i] and parts[i].Parent then
            pcall(function() parts[i].CFrame=CFrame.new(0,-200,0) end)
        end
    end
end

function S.findCampfire()
    return S.findOwnToy("Campfire")
end

function S.ensureCampfire()
    local x=S.findCampfire()
    if x then return x end
    local c,h,r=A.getCharacter()
    if not r then return nil end
    local ok,toy=S.spawnToy("Campfire",r.CFrame*CFrame.new(0,-3,-5),Vector3.new(0,0,0))
    if ok then return toy end
    return S.findCampfire()
end

function S.mountedBlob()
    local c,h,r=A.getCharacter()
    if not c then return nil end

    if h and h.SeatPart and h.SeatPart.Parent and h.SeatPart.Parent.Name=="CreatureBlobman" then
        return h.SeatPart.Parent
    end

    local d=Workspace:GetDescendants()
    local i
    for i=1,#d do
        local b=d[i]
        if b:IsA("Model") and b.Name=="CreatureBlobman" then
            local seat=b:FindFirstChild("VehicleSeat")
            local sw=seat and seat:FindFirstChild("SeatWeld")
            if sw and sw.Part1 and A.isDescendantOf(sw.Part1,c) then return b end
        end
    end
    return nil
end

function S.blobRoot(blob)
    if not blob then return nil end
    return blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart or blob:FindFirstChildWhichIsA("BasePart")
end

function S.blobRight(blob)
    if not blob then return nil,nil end
    local det=blob:FindFirstChild("RightDetector")
    local weld=det and (det:FindFirstChild("RightWeld") or det:FindFirstChildWhichIsA("Weld"))
    return det,weld
end

function S.blobLeft(blob)
    if not blob then return nil,nil end
    local det=blob:FindFirstChild("LeftDetector")
    local weld=det and (det:FindFirstChild("LeftWeld") or det:FindFirstChildWhichIsA("Weld"))
    return det,weld
end

function S.blobGrab(blob,target,side,silent)
    if not blob or not target then return false end
    local holder=blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    local grab=holder and holder:FindFirstChild("CreatureGrab")
    local det=blob:FindFirstChild(side.."Detector")
    if not grab or not det or not grab:IsA("RemoteEvent") then return false end
    local third=nil
    if silent then
        third=det:FindFirstChild("AttachPlayer")
    else
        third=det:FindFirstChild(side.."Weld") or det:FindFirstChildWhichIsA("Weld")
    end
    if not third then return false end
    return S.fire3(grab,det,target,third)
end

-- IMPORTANT: public kick sources use CreatureDrop(weld) ONE ARG.
function S.blobDropOne(blob,side)
    if not blob then return false end
    local holder=blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    local drop=holder and holder:FindFirstChild("CreatureDrop")
    local det=blob:FindFirstChild(side.."Detector")
    local weld=det and (det:FindFirstChild(side.."Weld") or det:FindFirstChildWhichIsA("Weld"))
    if not drop or not weld then return false end
    return S.fire1(drop,weld)
end

-- Generic Critcl/Defiant loop source uses CreatureDrop(weld,target) TWO ARGS.
function S.blobDropTwo(blob,target,side)
    if not blob or not target then return false end
    local holder=blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    local drop=holder and holder:FindFirstChild("CreatureDrop")
    local det=blob:FindFirstChild(side.."Detector")
    local weld=det and (det:FindFirstChild(side.."Weld") or det:FindFirstChildWhichIsA("Weld"))
    if not drop or not weld then return false end
    return S.fire2(drop,weld,target)
end

function S.tryInteract(root,container)
    if not root or not container then return false end
    local used=false
    local d=container:GetDescendants()
    local i
    if type(fireproximityprompt)=="function" then
        for i=1,#d do
            if d[i]:IsA("ProximityPrompt") then
                if pcall(function() fireproximityprompt(d[i]) end) then used=true end
            end
        end
    end
    if type(fireclickdetector)=="function" then
        for i=1,#d do
            if d[i]:IsA("ClickDetector") then
                if pcall(function() fireclickdetector(d[i]) end) then used=true end
            end
        end
    end
    return used
end

A.setStatus("V14 SHARED loaded: exact 1-arg/2-arg Blob drop helpers + plot toy discovery.")
print("[FTAP V14 SHARED] READY")
