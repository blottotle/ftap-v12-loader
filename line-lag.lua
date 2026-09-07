-- FTAP V13 LINE/LAG PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end

local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V13 LAG] core+shared first"); return end
if A.packs["LAG"] then return end
A.registerPack("LAG")

local S=A.shared
local page=A.makePage("LAG")

-- ============================================================
-- Cosmic Blob server lag/destroy-server source family
-- ============================================================

A.addSection(page,"COSMIC Blob Server Lag",
    "Source-grounded old Cosmic 'Destroy server' family: mounted Blobman repeatedly CreatureGrabs every other player.")

local cosmicBlobDelay=0.005

A.addSlider(page,"Cosmic Blob delay sec",0.001,0.10,0.001,0.005,function(v)
    cosmicBlobDelay=v
end)

A.addToggle(page,"cosmic_blob_lag","COSMIC Blob Server Lag",function()
    task.spawn(function()
        local side="Left"

        while A.toggleState["cosmic_blob_lag"] do
            local blob=S.mountedBlob()

            if not blob and A.blobAPI then
                blob=select(1,A.blobAPI.ensureBorrowed())
            end

            if blob then
                local ps=Players:GetPlayers()
                local i

                for i=1,#ps do
                    if not A.toggleState["cosmic_blob_lag"] then break end

                    local p=ps[i]

                    if p~=LP then
                        local tr=A.targetRoot(p)

                        if tr then
                            S.blobGrab(blob,tr,side,false)

                            if side=="Left" then
                                side="Right"
                            else
                                side="Left"
                            end

                            task.wait(cosmicBlobDelay)
                        end
                    end
                end
            else
                task.wait(0.05)
            end

            task.wait(0.001)
        end
    end)

    return true
end,function() end)

-- ============================================================
-- Critcl-style high-intensity server lag
-- ============================================================

A.addSection(page,"CRITCL Server Lag",
    "Public decompile defaults around 400 intensity. Remote expression is redacted, so these SetNetworkOwner mappings are labeled INFERRED.")

local serverIntensity=400

A.addSlider(page,"Server Lag intensity",1,1000,1,400,function(v)
    serverIntensity=v
end)

local function ownerBurst(mode)
    local refs=S.getRefs()

    if not refs.SetNetworkOwner then
        A.setStatus("SetNetworkOwner missing.")
        return false
    end

    local ps=Players:GetPlayers()
    local a,i

    for a=1,serverIntensity do
        for i=1,#ps do
            if ps[i]~=LP then
                local tr=A.targetRoot(ps[i])

                if tr then
                    if mode==1 then
                        S.fire2(refs.SetNetworkOwner,tr,tr.CFrame)
                    elseif mode==2 then
                        local fpp=tr:FindFirstChild("FirePlayerPart")
                        S.fire2(refs.SetNetworkOwner,tr,fpp and fpp.CFrame or tr.CFrame)
                    else
                        S.fire2(refs.SetNetworkOwner,tr,"player")
                    end
                end
            end
        end
    end

    return true
end

A.addToggle(page,"server_lag1","Server Lag 1 INFERRED CFrame",function()
    task.spawn(function()
        while A.toggleState["server_lag1"] do
            ownerBurst(1)
            task.wait(1)
        end
    end)

    return true
end,function() end)

A.addToggle(page,"server_lag2","Server Lag 2 INFERRED FirePlayerPart CFrame",function()
    task.spawn(function()
        while A.toggleState["server_lag2"] do
            ownerBurst(2)
            task.wait(1)
        end
    end)

    return true
end,function() end)

A.addToggle(page,"server_lag3","Server Lag 3 LEGACY 'player'",function()
    task.spawn(function()
        while A.toggleState["server_lag3"] do
            ownerBurst(3)
            task.wait(1)
        end
    end)

    return true
end,function() end)

-- ============================================================
-- FPS lag families
-- ============================================================

A.addSection(page,"FPS / Physics Lag",
    "Critcl source uses NinjaShuriken StickyParts + NpcRobloxianMascot decoys, BodyPosition P=10000 D=500, up to 8 shuriken per decoy, ±5000 jitter.")

local shurikenBodies={}
local fpsDecoys=2
local fpsShurikens=16

A.addSlider(page,"FPS setup decoys",1,4,1,2,function(v)
    fpsDecoys=v
end)

A.addSlider(page,"FPS setup shurikens",8,32,1,16,function(v)
    fpsShurikens=v
end)

A.addButton(page,"RUN Setup FPS-lag toys",function()
    local c,h,r=A.getCharacter()

    if not r then
        return A.setStatus("Character root missing.")
    end

    local i

    for i=1,fpsDecoys do
        if not S.findOwnToy("NpcRobloxianMascot") or i>1 then
            S.spawnToy(
                "NpcRobloxianMascot",
                r.CFrame*CFrame.new(i*3,0,-8),
                Vector3.new(0,0,0)
            )
        end
    end

    for i=1,fpsShurikens do
        S.spawnToy(
            "NinjaShuriken",
            r.CFrame*CFrame.new(0,4,-4),
            Vector3.new(0,0,0)
        )
        task.wait(0.03)
    end

    A.setStatus("FPS lag toy setup requested.")
end)

local function ownedNamed(name)
    local out={}
    local fs=S.ownToyFolders()
    local i,j

    for i=1,#fs do
        local kids=fs[i]:GetChildren()

        for j=1,#kids do
            if kids[j]:IsA("Model") and kids[j].Name==name then
                out[#out+1]=kids[j]
            end
        end
    end

    return out
end

A.addToggle(page,"fps_shuriken","FPS Lag 1 - CRITCL Shuriken exact family",function()
    local decoys=ownedNamed("NpcRobloxianMascot")
    local shurikens=ownedNamed("NinjaShuriken")

    if #decoys==0 or #shurikens==0 then
        A.setStatus("Need owned NpcRobloxianMascot + NinjaShuriken. Press setup first.")
        return false
    end

    shurikenBodies={}

    local di

    for di=1,#decoys do
        local decoyRoot=decoys[di]:FindFirstChild("HumanoidRootPart") or
                        decoys[di]:FindFirstChild("Torso")

        if decoyRoot then
            local startIndex=(di-1)*8+1
            local endIndex=math.min(startIndex+7,#shurikens)
            local si

            for si=startIndex,endIndex do
                local sh=shurikens[si]
                local sticky=sh and sh:FindFirstChild("StickyPart",true)

                if sticky and sticky:IsA("BasePart") then
                    local bp=Instance.new("BodyPosition")
                    bp.Name="FTAPCritclLagBP"
                    bp.P=10000
                    bp.D=500
                    bp.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
                    bp.Position=sticky.Position
                    bp.Parent=sticky

                    local sd=sh:GetDescendants()
                    local k

                    for k=1,#sd do
                        if sd[k]:IsA("BasePart") then
                            pcall(function()
                                sd[k].CanCollide=false
                                sd[k].CanTouch=false
                            end)

                            local ti=sd[k]:FindFirstChildOfClass("TouchTransmitter")
                            if ti then pcall(function() ti:Destroy() end) end
                        end
                    end

                    shurikenBodies[#shurikenBodies+1]={
                        body=bp,
                        origin=decoyRoot
                    }
                end
            end
        end
    end

    if #shurikenBodies==0 then
        A.setStatus("No usable Shuriken StickyParts.")
        return false
    end

    task.spawn(function()
        while A.toggleState["fps_shuriken"] do
            local i

            for i=1,#shurikenBodies do
                local x=shurikenBodies[i]

                if x.body and x.body.Parent and x.origin and x.origin.Parent then
                    local base=x.origin.Position

                    x.body.Position=base+Vector3.new(
                        math.random(-100,100)*50,
                        math.random(-100,100)*50,
                        math.random(-100,100)*50
                    )

                    x.body.Position=x.body.Position+Vector3.new(0,-4,0)
                end
            end

            task.wait(0.0001)

            for i=1,#shurikenBodies do
                local x=shurikenBodies[i]

                if x.body and x.body.Parent then
                    x.body.Position=x.body.Position+Vector3.new(0,3,0)
                end
            end

            task.wait(0.0001)
        end
    end)

    A.setStatus("CRITCL Shuriken FPS Lag enabled. pairs="..tostring(#shurikenBodies))
    return true
end,function()
    local i

    for i=1,#shurikenBodies do
        if shurikenBodies[i].body then
            pcall(function() shurikenBodies[i].body:Destroy() end)
        end
    end

    shurikenBodies={}
end)

local lineStorm=100

A.addSlider(page,"FPS Line Storm calls/heartbeat",10,500,10,100,function(v)
    lineStorm=v
end)

A.addToggle(page,"fps_line","FPS Lag 2 - CreateGrabEvent line storm",function()
    local refs=S.getRefs()

    if not refs.CreateGrabEvent or
       not refs.CreateGrabEvent:IsA("RemoteEvent") then
        A.setStatus("CreateGrabEvent missing.")
        return false
    end

    task.spawn(function()
        while A.toggleState["fps_line"] do
            local ps=Players:GetPlayers()
            local i

            for i=1,lineStorm do
                local p=ps[((i-1)%#ps)+1]

                if p and p~=LP then
                    local tr=A.targetRoot(p)

                    if tr then
                        S.fire2(refs.CreateGrabEvent,tr,Vector3.new(0,0,0))
                    end
                end
            end

            RunService.Heartbeat:Wait()
        end
    end)

    return true
end,function() end)

-- ============================================================
-- Ping source family
-- ============================================================

A.addSection(page,"PING Lag",
    "Critcl payload is known but its RemoteEvent name is redacted. Enter an exact remote name; V13 will not fake one.")

local pingBox=A.addInput(page,"Ping RemoteEvent exact name","")
local packets=3000

A.addSlider(page,"Ping string repetitions",100,5000,100,3000,function(v)
    packets=v
end)

A.addToggle(page,"ping1","Ping Lag - CRITCL huge-string payload",function()
    local r=A.findRemote(pingBox.Text)

    if not r or not r:IsA("RemoteEvent") then
        A.setStatus("Ping remote missing/invalid.")
        return false
    end

    task.spawn(function()
        local payload=string.rep("Balls Balls Balls Balls",packets)

        while A.toggleState["ping1"] do
            S.fire1(r,payload)
            RunService.Heartbeat:Wait()
        end
    end)

    return true
end,function() end)

A.addButton(page,"RUN Print likely one-arg remotes",function()
    print("===== FTAP V13 PING CANDIDATES =====")

    local d=game:GetService("ReplicatedStorage"):GetDescendants()
    local i,count=0,0

    for i=1,#d do
        local x=d[i]

        if x:IsA("RemoteEvent") then
            count=count+1
            print(x:GetFullName())
        end
    end

    print("===== END PING CANDIDATES =====")
    A.setStatus("Printed "..tostring(count).." RemoteEvents. Ping name still requires testing.")
end)

A.setStatus("V13 LAG loaded: Cosmic Blob lag + 400-intensity server lag + Critcl shuriken FPS lag.")
print("[FTAP V13 LAG] READY")
