-- FTAP V14 RESULTS / DEBUG
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14 DEBUG] core+shared first"); return end
if A.packs["DEBUG"] then return end
A.registerPack("DEBUG")
local S=A.shared

local page=A.makePage("RESULTS")
A.addSection(page,"Result tracker","Mark each exact source family WORKS/PARTIAL/FAIL.")
A.addButton(page,"Mark last = WORKS",function() A.markFeature("WORKS") end)
A.addButton(page,"Mark last = PARTIAL",function() A.markFeature("PARTIAL") end)
A.addButton(page,"Mark last = FAIL",function() A.markFeature("FAIL") end)
A.addButton(page,"PRINT result matrix",function()
    print("===== FTAP V14 RESULTS =====")
    local keys={}
    local k
    for k in pairs(A.featureResults) do keys[#keys+1]=k end
    table.sort(keys)
    local i
    for i=1,#keys do print(keys[i].." = "..tostring(A.featureResults[keys[i]])) end
    print("===== END FTAP V14 RESULTS =====")
end)

local dbg=A.makePage("DEBUG")
A.addSection(dbg,"Deep source preflight","These checks correspond to the remotes/objects the leaked source actually uses.")

A.addButton(dbg,"BLOB KICK PREFLIGHT",function()
    local refs=S.getRefs()
    local b=S.mountedBlob()
    local rd,rw=S.blobRight(b)
    local holder=b and b:FindFirstChild("BlobmanSeatAndOwnerScript")
    local cg=holder and holder:FindFirstChild("CreatureGrab")
    local cd=holder and holder:FindFirstChild("CreatureDrop")
    A.setStatus(
        "seatedBlob="..tostring(b~=nil)..
        " RightDetector="..tostring(rd~=nil)..
        " RightWeld="..tostring(rw~=nil)..
        " CG="..tostring(cg~=nil)..
        " CD="..tostring(cd~=nil)..
        " SNO="..tostring(refs.SetNetworkOwner~=nil)..
        " CreateLine="..tostring(refs.CreateGrabLine~=nil)..
        " DestroyLine="..tostring(refs.DestroyGrabLine~=nil)
    )
end)

A.addButton(dbg,"LAG PREFLIGHT",function()
    local refs=S.getRefs()
    local spawn=Workspace:FindFirstChild("SpawnLocation")
    local fs=S.describeToyFolders()
    A.setStatus(
        "CreateGrabLine="..tostring(refs.CreateGrabLine~=nil)..
        " ExtendGrabLine="..tostring(refs.ExtendGrabLine~=nil)..
        " SpawnLocation="..tostring(spawn~=nil)..
        " folders="..table.concat(fs," | ")
    )
end)

A.addButton(dbg,"ANTI PREFLIGHT",function()
    local refs=S.getRefs()
    local ps=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    A.setStatus(
        "Struggle="..tostring(refs.Struggle~=nil)..
        " Ragdoll="..tostring(refs.RagdollRemote~=nil)..
        " StickyEvent="..tostring(refs.StickyPartEvent~=nil)..
        " FirePlayerPart="..tostring(select(3,A.getCharacter()) and select(3,A.getCharacter()):FindFirstChild("FirePlayerPart")~=nil)..
        " CharacterAndBeamMove="..tostring(ps and ps:FindFirstChild("CharacterAndBeamMove")~=nil)..
        " StickyDetect="..tostring(ps and ps:FindFirstChild("StickyPartsTouchDetection")~=nil)
    )
end)

A.addButton(dbg,"PRINT all ReplicatedStorage remotes",function()
    print("===== FTAP V14 REMOTES =====")
    local d=ReplicatedStorage:GetDescendants()
    local i,n=0,0
    for i=1,#d do
        if d[i]:IsA("RemoteEvent") or d[i]:IsA("RemoteFunction") then
            n=n+1
            print(d[i].ClassName,d[i]:GetFullName())
        end
    end
    print("===== END REMOTES =====")
    A.setStatus("Printed "..tostring(n).." remotes.")
end)

A.addButton(dbg,"PRINT V14 source map",function()
    print("===== FTAP V14 SOURCE MAP =====")
    print("Blob Kick A = TheWorst Plugins/BlobKick.luau Aug-2026")
    print("Blob Kick B/C = The Vovange hard + SpinGrab")
    print("Critcl Blob loop = defiant_source two-arg CreatureDrop")
    print("Line Lag A = The Vovange CreateGrabLine(SpawnLocation, SpawnLocation.CFrame)")
    print("Line Lag B = defiant_source CreateGrabLine(Torso, Torso.CFrame)")
    print("Packet A = The Vovange ExtendGrabLine emoji payload")
    print("Packet B = defiant_source ExtendGrabLine Balls payload")
    print("Packet C = PolarHub ExtendGrabLine emoji family")
    print("FPS lag = defiant_source Shuriken + NpcRobloxianMascot")
    print("AntiGrab 1 = The Vovange")
    print("AntiGrab 2 = defiant_source")
    print("AntiKick 1 = SAHAR FirePlayerPart StickyPart")
    print("AntiKick 2 = WNCLY Kunai thigh")
    print("AntiLag/Sticky = defiant_source PlayerScripts disables")
    print("===== END SOURCE MAP =====")
end)

A.setStatus("V14 DEBUG loaded.")
print("[FTAP V14 DEBUG] READY")
