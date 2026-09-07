-- FTAP V12 SHARED PACK
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A then warn("[FTAP V12 SHARED] core first"); return end
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

function S.fire0(r)
    if r==nil or not r:IsA("RemoteEvent") then return false end
    return pcall(function() r:FireServer() end)
end
function S.fire1(r,a)
    if r==nil or not r:IsA("RemoteEvent") then return false end
    return pcall(function() r:FireServer(a) end)
end
function S.fire2(r,a,b)
    if r==nil or not r:IsA("RemoteEvent") then return false end
    return pcall(function() r:FireServer(a,b) end)
end
function S.fire3(r,a,b,c)
    if r==nil or not r:IsA("RemoteEvent") then return false end
    return pcall(function() r:FireServer(a,b,c) end)
end
function S.fire4(r,a,b,c,d)
    if r==nil or not r:IsA("RemoteEvent") then return false end
    return pcall(function() r:FireServer(a,b,c,d) end)
end

function S.findRemoteContains(words,excludes)
    local d=ReplicatedStorage:GetDescendants()
    local i,j
    for i=1,#d do
        local x=d[i]
        if x:IsA("RemoteEvent") or x:IsA("RemoteFunction") then
            local n=string.lower(x.Name)
            local ok=true
            for j=1,#words do
                if string.find(n,string.lower(words[j]),1,true)==nil then ok=false break end
            end
            if ok and excludes then
                for j=1,#excludes do
                    if string.find(n,string.lower(excludes[j]),1,true)~=nil then ok=false break end
                end
            end
            if ok then return x end
        end
    end
    return nil
end

function S.getRefs()
    local r=A.getRefs()
    if r.CreateGrabEvent==nil then
        r.CreateGrabEvent=S.findRemoteContains({"create","grab"},{"line"})
    end
    r.ExtendLineEvent=A.findRemote("ExtendLineEvent") or A.findRemote("ExtendLine") or S.findRemoteContains({"extend","line"},nil)
    r.StickyPartEvent=A.findRemote("StickyPartEvent") or S.findRemoteContains({"sticky","part"},nil)
    r.SetLineColorEvent=A.findRemote("SetLineColorEvent") or S.findRemoteContains({"line","color"},nil)
    local mt=ReplicatedStorage:FindFirstChild("MenuToys")
    if mt then
        r.SpawnToy=mt:FindFirstChild("SpawnToyRemoteFunction")
        r.DestroyToy=mt:FindFirstChild("DestroyToy") or mt:FindFirstChild("DestroyToyEvent")
    end
    if r.SpawnToy==nil then r.SpawnToy=A.findRemote("SpawnToyRemoteFunction") end
    if r.DestroyToy==nil then r.DestroyToy=A.findRemote("DestroyToy") end
    return r
end

function S.ownToyFolders()
    local out={}
    local d=Workspace:FindFirstChild(LP.Name.."SpawnedInToys")
    if d then out[#out+1]=d end
    local st=Workspace:FindFirstChild("st")
    if st then
        local f=st:FindFirstChild(LP.Name.."SpawnedInToys")
        if f then out[#out+1]=f end
    end
    return out
end

function S.findOwnToy(name)
    local fs=S.ownToyFolders()
    local i
    for i=1,#fs do
        local x=fs[i]:FindFirstChild(name)
        if x then return x end
    end
    return nil
end

function S.waitOwnToy(name,seconds)
    local st=os.clock()
    while os.clock()-st<seconds do
        local x=S.findOwnToy(name)
        if x then return x end
        task.wait(0.05)
    end
    return nil
end

function S.spawnToy(name,cf,rot)
    local r=S.getRefs()
    if r.SpawnToy==nil or not r.SpawnToy:IsA("RemoteFunction") then return false,nil end
    local ok=pcall(function() r.SpawnToy:InvokeServer(name,cf,rot or Vector3.new(0,0,0)) end)
    if not ok then return false,nil end
    return true,S.waitOwnToy(name,1.5)
end

function S.destroyToy(toy)
    if toy==nil then return false end
    local r=S.getRefs()
    if r.DestroyToy and r.DestroyToy:IsA("RemoteEvent") then return S.fire1(r.DestroyToy,toy) end
    return pcall(function() toy:Destroy() end)
end

function S.findAnyWeapon()
    local k=S.findOwnToy("NinjaKunai")
    if k then return k,"NinjaKunai" end
    local s=S.findOwnToy("NinjaShuriken")
    if s then return s,"NinjaShuriken" end
    return nil,nil
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
    local fs=S.ownToyFolders()
    local i
    for i=1,#fs do
        local x=fs[i]:FindFirstChild("Campfire")
        if x then return x end
    end
    return nil
end

function S.ensureCampfire()
    local x=S.findCampfire()
    if x then return x end
    local c,h,r=A.getCharacter()
    if not r then return nil end
    local ok,toy=S.spawnToy("Campfire",r.CFrame*CFrame.new(0,-3,-5),Vector3.new(0,0,0))
    if ok and toy then return toy end
    return S.findCampfire()
end

function S.mountedBlob()
    local c,h,r=A.getCharacter()
    if not c then return nil end
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
    if h and h.SeatPart then
        local n=h.SeatPart
        while n and n~=Workspace do
            if n:IsA("Model") and n.Name=="CreatureBlobman" then return n end
            n=n.Parent
        end
    end
    return nil
end

function S.blobRoot(blob)
    if not blob then return nil end
    return blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart or blob:FindFirstChildWhichIsA("BasePart")
end

function S.blobGrab(blob,target,side,silent)
    if not blob or not target then return false end
    local holder=blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    local grab=holder and holder:FindFirstChild("CreatureGrab")
    local det=blob:FindFirstChild(side.."Detector")
    if not grab or not det or not grab:IsA("RemoteEvent") then return false end
    local third
    if silent then third=det:FindFirstChild("AttachPlayer")
    else third=det:FindFirstChild(side.."Weld") or det:FindFirstChild("RigidConstraint") end
    if not third then return false end
    return S.fire3(grab,det,target,third)
end

function S.blobDrop(blob,target,side)
    if not blob or not target then return false end
    local holder=blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    local drop=holder and holder:FindFirstChild("CreatureDrop")
    local det=blob:FindFirstChild(side.."Detector")
    if not drop or not det or not drop:IsA("RemoteEvent") then return false end
    local weld=det:FindFirstChild(side.."Weld") or det:FindFirstChild("RigidConstraint")
    if not weld then return false end
    return S.fire2(drop,weld,target)
end

A.setStatus("SHARED pack loaded.")
print("[FTAP V12 SHARED] READY")
