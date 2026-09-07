-- FTAP V13 RESULTS/DEBUG PACK
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V13 DEBUG] core+shared first"); return end
if A.packs["DEBUG"] then return end
A.registerPack("DEBUG")
local S=A.shared
local page=A.makePage("RESULTS")
A.addSection(page,"Result tracker","After testing a feature, mark it WORKS/PARTIAL/FAIL.")
A.addButton(page,"Mark last = WORKS",function() A.markFeature("WORKS") end)
A.addButton(page,"Mark last = PARTIAL",function() A.markFeature("PARTIAL") end)
A.addButton(page,"Mark last = FAIL",function() A.markFeature("FAIL") end)
A.addButton(page,"PRINT result matrix",function()
    print("===== FTAP V13 RESULTS =====")
    local k
    for k,v in pairs(A.featureResults) do print(k.." = "..v) end
    print("===== END FTAP V13 RESULTS =====")
end)

local dbg=A.makePage("DEBUG")
A.addSection(dbg,"Diagnostics",nil)
A.addButton(dbg,"Remote map",function()
    local r=S.getRefs()
    A.setStatus("CreateGrab="..S.pathOf(r.CreateGrabEvent).." | Extend="..S.pathOf(r.ExtendLineEvent).." | CreateLine="..S.pathOf(r.CreateGrabLine).." | SetOwner="..S.pathOf(r.SetNetworkOwner).." | Sticky="..S.pathOf(r.StickyPartEvent))
end)
A.addButton(dbg,"Anti map",function()
    local r=S.getRefs()
    A.setStatus("Struggle="..S.pathOf(r.Struggle).." | StopVel="..S.pathOf(r.StopAllVelocity).." | Ragdoll="..S.pathOf(r.RagdollRemote).." | SpawnToy="..S.pathOf(r.SpawnToy))
end)
A.addButton(dbg,"Print all remotes",function()
    print("===== FTAP V13 REMOTES =====")
    local d=ReplicatedStorage:GetDescendants(); local i,n=0,0
    for i=1,#d do if d[i]:IsA("RemoteEvent") or d[i]:IsA("RemoteFunction") then n=n+1; print(d[i].ClassName,d[i]:GetFullName()) end end
    print("===== END REMOTES ====="); A.setStatus("Printed "..tostring(n).." remotes.")
end)
A.addButton(dbg,"Loaded packs",function()
    local names={}; local k
    for k in pairs(A.packs) do names[#names+1]=k end
    table.sort(names); A.setStatus(table.concat(names,", "))
end)

A.setStatus("RESULTS + DEBUG packs loaded.")
print("[FTAP V13 DEBUG] READY")
