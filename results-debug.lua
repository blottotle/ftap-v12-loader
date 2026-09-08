-- FTAP V14R2 RESULTS / DEBUG2
-- Observational diagnostics only: does not mutate remote arguments, cadence, or feature intensity.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local LP=Players.LocalPlayer

local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V14R2 DEBUG2] core+shared first"); return end
if A.packs["DEBUG"] then return end
A.registerPack("DEBUG")
local S=A.shared

local D=A.debug2 or {}
A.debug2=D
D.enabled=D.enabled==true
D.lifecycleEnabled=false
D.runSeq=D.runSeq or 0
D.runs=D.runs or {}
D.events=D.events or {}
D.remoteStats=D.remoteStats or {}
D.currentRun=nil
D.lastRun=nil
D.maxEvents=1500
D.maxRuns=200
D.localGen=D.localGen or 0
D.targetGen=D.targetGen or 0
D.blobGen=D.blobGen or 0
D.localChar=nil
D.targetPlayer=nil
D.targetChar=nil
D.blob=nil
D.lifecycle={created=0,removed=0,toysAdded=0,toysRemoved=0,blobsAdded=0,blobsRemoved=0,grabPartsAdded=0,grabPartsRemoved=0,weldsAdded=0,weldsRemoved=0}
D.lifecycleConnections={}

local function now() return os.clock() end

local function clip(s,n)
    s=tostring(s or "")
    if #s<=n then return s end
    return string.sub(s,1,n).."…"
end

local function instancePath(x)
    if not x then return "nil" end
    local ok,v=pcall(function() return x:GetFullName() end)
    if ok then return v end
    return tostring(x)
end

local function approxBytes(v,seen,depth)
    local tv=typeof(v)
    if tv=="string" then return #v end
    if tv=="number" then return 8 end
    if tv=="boolean" then return 1 end
    if tv=="Vector3" then return 24 end
    if tv=="CFrame" then return 96 end
    if tv=="Color3" then return 24 end
    if tv=="Instance" then return 16 end
    if tv~="table" then return 8 end
    if depth>=2 then return 16 end
    if seen[v] then return 0 end
    seen[v]=true
    local total=16
    local n=0
    for k,x in pairs(v) do
        n=n+1
        if n>64 then total=total+64; break end
        total=total+approxBytes(k,seen,depth+1)+approxBytes(x,seen,depth+1)
    end
    return total
end

local function argsMeta(args)
    local sig={}
    local bytes=0
    local seen={}
    for i=1,#args do
        sig[#sig+1]=typeof(args[i])
        bytes=bytes+approxBytes(args[i],seen,0)
    end
    return table.concat(sig,","),bytes
end

local function refreshGenerations()
    local c=LP.Character
    if c~=D.localChar then
        D.localChar=c
        D.localGen=D.localGen+1
    end

    local tp=A.currentTarget and select(1,A.currentTarget()) or nil
    local tc=tp and tp.Character or nil
    if tp~=D.targetPlayer or tc~=D.targetChar then
        D.targetPlayer=tp
        D.targetChar=tc
        D.targetGen=D.targetGen+1
    end

    local b=S.mountedBlob()
    if b~=D.blob then
        D.blob=b
        D.blobGen=D.blobGen+1
    end

    return {
        localGen=D.localGen,
        targetGen=D.targetGen,
        blobGen=D.blobGen,
        localChar=c,
        target=tp,
        targetChar=tc,
        blob=b
    }
end

local function toggleKeyForLabel(label)
    for k,v in pairs(A.toggleLabels or {}) do
        if tostring(v)==tostring(label) then return k end
    end
    return nil
end

local function finishRun(reason,result)
    local r=D.currentRun
    if not r then return end
    r.stop=now()
    r.duration=r.stop-r.start
    r.stopReason=reason or r.stopReason or "STOPPED"
    if result~=nil then r.result=tostring(result) end
    D.lastRun=r
    D.currentRun=nil
end

local function startRun(label,kind)
    finishRun("NEXT_TEST")
    local g=refreshGenerations()
    D.runSeq=D.runSeq+1
    local r={
        runId=D.runSeq,
        testId=tostring(label or "unknown"),
        kind=kind or "unknown",
        start=now(),
        calls=0,
        bytes=0,
        errors=0,
        created=0,
        removed=0,
        localGen=g.localGen,
        targetGen=g.targetGen,
        blobGen=g.blobGen,
        targetName=g.target and g.target.Name or "none",
        stopReason="RUNNING",
        result="UNMARKED"
    }
    D.currentRun=r
    D.runs[#D.runs+1]=r
    if #D.runs>D.maxRuns then table.remove(D.runs,1) end
    return r
end

local oldTouch=A.touchFeature
A.touchFeature=function(label)
    if oldTouch then oldTouch(label) end
    if not D.enabled then return end
    local key=toggleKeyForLabel(label)
    if key and A.toggleState[key]==true then
        if D.currentRun and D.currentRun.testId==tostring(label) then
            finishRun("TOGGLE_OFF")
        else
            finishRun("TOGGLE_OFF_OTHER")
        end
        return
    end
    local r=startRun(label,key and "toggle" or "button")
    if not key then
        local id=r.runId
        task.delay(1.0,function()
            if D.currentRun and D.currentRun.runId==id then finishRun("BUTTON_COMPLETE") end
        end)
    end
end

local oldMark=A.markFeature
A.markFeature=function(result)
    if oldMark then oldMark(result) end
    local r=D.currentRun or D.lastRun
    if r then r.result=tostring(result) end
end

function A.debug2Ack(status)
    if not D.enabled then return end
    local r=D.currentRun
    if r then r.ack=tostring(status or "ACKED") end
end

function A.debug2ObserveRemote(remote,args,ok,err,elapsed,kind)
    if not D.enabled then return end
    local g=refreshGenerations()
    local path=instancePath(remote)
    local sig,bytes=argsMeta(args or {})
    local t=now()
    local st=D.remoteStats[path]
    if not st then
        st={calls=0,bytes=0,errors=0,last=0,lastInterval=0,lastSig="",lastBytes=0,lastElapsed=0,kind=kind or "Remote"}
        D.remoteStats[path]=st
    end
    st.calls=st.calls+1
    st.bytes=st.bytes+bytes
    if not ok then st.errors=st.errors+1 end
    if st.last>0 then st.lastInterval=t-st.last end
    st.last=t
    st.lastSig=sig
    st.lastBytes=bytes
    st.lastElapsed=elapsed or 0
    st.kind=kind or st.kind

    local ev={t=t,path=path,bytes=bytes,ok=ok==true,sig=sig,elapsed=elapsed or 0,runId=D.currentRun and D.currentRun.runId or 0,testId=D.currentRun and D.currentRun.testId or tostring(A.lastFeature or "none"),targetGen=g.targetGen,blobGen=g.blobGen}
    D.events[#D.events+1]=ev
    if #D.events>D.maxEvents then table.remove(D.events,1) end

    local r=D.currentRun
    if r then
        r.calls=r.calls+1
        r.bytes=r.bytes+bytes
        if not ok then r.errors=r.errors+1; r.lastError=clip(err,180) end
        r.targetGen=g.targetGen
        r.blobGen=g.blobGen
    end
end

local function stopLifecycle()
    for i=1,#D.lifecycleConnections do
        local c=D.lifecycleConnections[i]
        if c then pcall(function() c:Disconnect() end) end
    end
    D.lifecycleConnections={}
    D.lifecycleEnabled=false
end

local function classifyLifecycle(x,added)
    if not x then return end
    local L=D.lifecycle
    if added then L.created=L.created+1 else L.removed=L.removed+1 end
    if x:IsA("Model") and x.Name=="CreatureBlobman" then
        if added then L.blobsAdded=L.blobsAdded+1 else L.blobsRemoved=L.blobsRemoved+1 end
    end
    if x.Name=="GrabParts" then
        if added then L.grabPartsAdded=L.grabPartsAdded+1 else L.grabPartsRemoved=L.grabPartsRemoved+1 end
    end
    if x:IsA("WeldConstraint") or x:IsA("Weld") or x:IsA("Motor6D") then
        if added then L.weldsAdded=L.weldsAdded+1 else L.weldsRemoved=L.weldsRemoved+1 end
    end
    local r=D.currentRun
    if r then
        if added then r.created=r.created+1 else r.removed=r.removed+1 end
    end
end

local function startLifecycle()
    stopLifecycle()
    D.lifecycleEnabled=true
    local function watchFolder(f)
        if not f then return end
        D.lifecycleConnections[#D.lifecycleConnections+1]=f.ChildAdded:Connect(function(x)
            D.lifecycle.toysAdded=D.lifecycle.toysAdded+1
            classifyLifecycle(x,true)
        end)
        D.lifecycleConnections[#D.lifecycleConnections+1]=f.ChildRemoved:Connect(function(x)
            D.lifecycle.toysRemoved=D.lifecycle.toysRemoved+1
            classifyLifecycle(x,false)
        end)
    end
    local fs=S.ownToyFolders()
    for i=1,#fs do watchFolder(fs[i]) end
    D.lifecycleConnections[#D.lifecycleConnections+1]=Workspace.ChildAdded:Connect(function(x) classifyLifecycle(x,true) end)
    D.lifecycleConnections[#D.lifecycleConnections+1]=Workspace.ChildRemoved:Connect(function(x) classifyLifecycle(x,false) end)
end

local function rollingRates(window)
    window=window or 5
    local cutoff=now()-window
    local calls,bytes=0,0
    for i=#D.events,1,-1 do
        local e=D.events[i]
        if e.t<cutoff then break end
        calls=calls+1
        bytes=bytes+(e.bytes or 0)
    end
    return calls/window,bytes/window,calls,bytes
end

local function fmtBytes(n)
    if n>=1024*1024 then return string.format("%.2f MiB",n/(1024*1024)) end
    if n>=1024 then return string.format("%.1f KiB",n/1024) end
    return tostring(math.floor(n)).." B"
end

local function printRun(r)
    if not r then return end
    print(string.format("run=%s test=%s kind=%s result=%s stop=%s dur=%.3fs calls=%d bytes=%d errors=%d created=%d removed=%d targetGen=%d blobGen=%d ack=%s",
        tostring(r.runId),tostring(r.testId),tostring(r.kind),tostring(r.result),tostring(r.stopReason),tonumber(r.duration or (now()-r.start)) or 0,
        tonumber(r.calls or 0),tonumber(r.bytes or 0),tonumber(r.errors or 0),tonumber(r.created or 0),tonumber(r.removed or 0),tonumber(r.targetGen or 0),tonumber(r.blobGen or 0),tostring(r.ack or "none")))
end

local function runLogText()
    local out={"===== FTAP V14R2 DEBUG2 RUN LOG ====="}
    for i=1,#D.runs do
        local r=D.runs[i]
        out[#out+1]=string.format("%s | %s | %s | %s | calls=%d | bytes=%d | errors=%d | created=%d | removed=%d | targetGen=%d | blobGen=%d | %s",
            tostring(r.runId),tostring(r.testId),tostring(r.result),tostring(r.stopReason),tonumber(r.calls or 0),tonumber(r.bytes or 0),tonumber(r.errors or 0),tonumber(r.created or 0),tonumber(r.removed or 0),tonumber(r.targetGen or 0),tonumber(r.blobGen or 0),tostring(r.lastError or ""))
    end
    out[#out+1]="===== END FTAP V14R2 DEBUG2 RUN LOG ====="
    return table.concat(out,"\n")
end

local page=A.makePage("RESULTS")
A.addSection(page,"Result tracker","Mark the last exact source family WORKS/PARTIAL/FAIL. DEBUG2 keeps the detailed run row underneath it.")
A.addButton(page,"Mark last = WORKS",function() A.markFeature("WORKS") end)
A.addButton(page,"Mark last = PARTIAL",function() A.markFeature("PARTIAL") end)
A.addButton(page,"Mark last = FAIL",function() A.markFeature("FAIL") end)
A.addButton(page,"PRINT result matrix",function()
    print("===== FTAP V14 RESULTS =====")
    local keys={}
    for k in pairs(A.featureResults) do keys[#keys+1]=k end
    table.sort(keys)
    for i=1,#keys do print(keys[i].." = "..tostring(A.featureResults[keys[i]])) end
    print("===== END FTAP V14 RESULTS =====")
end)
A.addButton(page,"PRINT DEBUG2 run matrix",function()
    print(runLogText())
    A.setStatus("Printed DEBUG2 runs="..tostring(#D.runs))
end)

local dbg=A.makePage("DEBUG")
A.addSection(dbg,"Deep source preflight","Capability checks correspond to the exact objects/remotes used by the V14 families.")

A.addButton(dbg,"BLOB KICK PREFLIGHT",function()
    local refs=S.getRefs()
    local b=S.mountedBlob()
    local rd,rw=S.blobRight(b)
    local ld,lw=S.blobLeft(b)
    local holder=b and b:FindFirstChild("BlobmanSeatAndOwnerScript")
    local cg=holder and holder:FindFirstChild("CreatureGrab")
    local cd=holder and holder:FindFirstChild("CreatureDrop")
    local cr=holder and holder:FindFirstChild("CreatureRelease")
    local g=refreshGenerations()
    A.setStatus(
        "blobGen="..tostring(g.blobGen)..
        " targetGen="..tostring(g.targetGen)..
        " RDet="..tostring(rd~=nil).." RWeld="..tostring(rw~=nil)..
        " LDet="..tostring(ld~=nil).." LWeld="..tostring(lw~=nil)..
        " CG="..tostring(cg~=nil).." CD="..tostring(cd~=nil).." CR="..tostring(cr~=nil)..
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
        " DestroyGrabLine="..tostring(refs.DestroyGrabLine~=nil)..
        " ExtendGrabLine="..tostring(refs.ExtendGrabLine~=nil)..
        " SetOwner="..tostring(refs.SetNetworkOwner~=nil)..
        " SpawnLocation="..tostring(spawn~=nil)..
        " folders="..table.concat(fs," | ")
    )
end)

A.addButton(dbg,"ANTI PREFLIGHT",function()
    local refs=S.getRefs()
    local ps=LP:FindFirstChild("PlayerScripts")
    A.setStatus(
        "Struggle="..tostring(refs.Struggle~=nil)..
        " Ragdoll="..tostring(refs.RagdollRemote~=nil)..
        " StickyEvent="..tostring(refs.StickyPartEvent~=nil)..
        " CharacterAndBeamMove="..tostring(ps and ps:FindFirstChild("CharacterAndBeamMove")~=nil)..
        " StickyDetect="..tostring(ps and ps:FindFirstChild("StickyPartsTouchDetection")~=nil)
    )
end)

A.addButton(dbg,"PRINT all ReplicatedStorage remotes",function()
    print("===== FTAP V14 REMOTES =====")
    local d=ReplicatedStorage:GetDescendants()
    local n=0
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
    print("Line Lag C = research lifecycle create/destroy variant")
    print("Line Lag D = bounded transform-argument research probe")
    print("Packet A/B/C = Vovange / Defiant / Polar ExtendGrabLine families")
    print("Packet D = bounded size sweep diagnostic")
    print("FPS lag = defiant_source Shuriken + NpcRobloxianMascot")
    print("DEBUG2 = argument/cadence/byte/generation/lifecycle observer")
    print("===== END SOURCE MAP =====")
end)

local dpage=A.makePage("DEBUG2")
A.addSection(dpage,"Telemetry","Observes the existing V14 calls. It does not rewrite payloads, cadence, or intensity.")
A.addToggle(dpage,"debug2_telemetry","DEBUG2 telemetry capture",function()
    D.enabled=true
    refreshGenerations()
    A.setStatus("DEBUG2 telemetry ON")
    return true
end,function()
    finishRun("DEBUG2_OFF")
    D.enabled=false
    A.setStatus("DEBUG2 telemetry OFF")
end)

A.addToggle(dpage,"debug2_lifecycle","DEBUG2 lifecycle counters",function()
    startLifecycle()
    A.setStatus("Lifecycle capture ON; watching own toy folders + Workspace top-level")
    return true
end,function()
    stopLifecycle()
    A.setStatus("Lifecycle capture OFF")
end)

A.toggleStops["debug2_lifecycle"]=stopLifecycle

A.addButton(dpage,"CURRENT CONTEXT SNAPSHOT",function()
    local g=refreshGenerations()
    A.setStatus(
        "localGen="..tostring(g.localGen)..
        " target="..tostring(g.target and g.target.Name or "none")..
        " targetGen="..tostring(g.targetGen)..
        " blobGen="..tostring(g.blobGen)..
        " blob="..clip(instancePath(g.blob),70)
    )
end)

A.addButton(dpage,"BLOB COMPATIBILITY MATRIX",function()
    local g=refreshGenerations()
    local b=g.blob
    local ld,lw=S.blobLeft(b)
    local rd,rw=S.blobRight(b)
    local holder=b and b:FindFirstChild("BlobmanSeatAndOwnerScript")
    local cg=holder and holder:FindFirstChild("CreatureGrab")
    local cd=holder and holder:FindFirstChild("CreatureDrop")
    local cr=holder and holder:FindFirstChild("CreatureRelease")
    print("===== FTAP DEBUG2 BLOB MATRIX =====")
    print("blobGen",g.blobGen,"blob",instancePath(b))
    print("LeftDetector",instancePath(ld),"LeftWeld",instancePath(lw))
    print("RightDetector",instancePath(rd),"RightWeld",instancePath(rw))
    print("CreatureGrab",instancePath(cg),"CreatureDrop",instancePath(cd),"CreatureRelease",instancePath(cr))
    print("targetGen",g.targetGen,"target",g.target and g.target.Name or "none","char",instancePath(g.targetChar))
    print("===== END BLOB MATRIX =====")
    A.setStatus("Printed Blob compatibility matrix")
end)

A.addButton(dpage,"PRINT rolling rates (5s)",function()
    local cps,bps,calls,bytes=rollingRates(5)
    print(string.format("[FTAP DEBUG2] last5s calls=%d bytes=%d calls/s=%.1f bytes/s=%.1f",calls,bytes,cps,bps))
    A.setStatus(string.format("5s: %.1f calls/s | %s/s",cps,fmtBytes(bps)))
end)

A.addButton(dpage,"PRINT remote telemetry",function()
    print("===== FTAP DEBUG2 REMOTE STATS =====")
    local keys={}
    for k in pairs(D.remoteStats) do keys[#keys+1]=k end
    table.sort(keys)
    for i=1,#keys do
        local k=keys[i]
        local st=D.remoteStats[k]
        print(k,"calls="..st.calls,"bytes="..st.bytes,"errors="..st.errors,"lastBytes="..st.lastBytes,"lastSig="..st.lastSig,"lastInterval="..string.format("%.6f",st.lastInterval or 0),"lastElapsed="..string.format("%.6f",st.lastElapsed or 0))
    end
    print("===== END FTAP DEBUG2 REMOTE STATS =====")
    A.setStatus("Printed remote stats="..tostring(#keys))
end)

A.addButton(dpage,"PRINT lifecycle counters",function()
    local L=D.lifecycle
    print("[FTAP DEBUG2 LIFECYCLE] created",L.created,"removed",L.removed,"toys+",L.toysAdded,"toys-",L.toysRemoved,"blobs+",L.blobsAdded,"blobs-",L.blobsRemoved,"grab+",L.grabPartsAdded,"grab-",L.grabPartsRemoved,"weld+",L.weldsAdded,"weld-",L.weldsRemoved)
    A.setStatus("Lifecycle created="..tostring(L.created).." removed="..tostring(L.removed))
end)

A.addButton(dpage,"COPY DEBUG2 run log",function()
    local text=runLogText()
    if type(setclipboard)=="function" then
        local ok=pcall(function() setclipboard(text) end)
        if ok then A.setStatus("DEBUG2 run log copied") return end
    end
    print(text)
    A.setStatus("Clipboard unavailable; printed DEBUG2 run log")
end)

A.addButton(dpage,"CLEAR DEBUG2 telemetry",function()
    finishRun("CLEARED")
    D.events={}
    D.remoteStats={}
    D.runs={}
    D.runSeq=0
    D.lifecycle={created=0,removed=0,toysAdded=0,toysRemoved=0,blobsAdded=0,blobsRemoved=0,grabPartsAdded=0,grabPartsRemoved=0,weldsAdded=0,weldsRemoved=0}
    A.setStatus("DEBUG2 telemetry cleared")
end)

local oldShutdown=A.shutdown
A.shutdown=function()
    finishRun("GUI_SHUTDOWN")
    stopLifecycle()
    if oldShutdown then oldShutdown() end
end

A.setStatus("V14R2 DEBUG2 loaded. Existing V14 call behavior unchanged; telemetry is opt-in.")
print("[FTAP V14R2 DEBUG2] READY")
