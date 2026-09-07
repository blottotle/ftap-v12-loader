-- FTAP V12 LINE/LAG PACK
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer
local ENV=_G
if type(getgenv)=="function" then pcall(function() ENV=getgenv() end) end
local A=ENV.FTAPV10
if not A or not A.shared then warn("[FTAP V12 LAG] core+shared first"); return end
if A.packs["LAG"] then return end
A.registerPack("LAG")
local S=A.shared
local page=A.makePage("LINE/LAG")
local amount=10; local ownerIntensity=5; local ownerRate=30; local extendDist=40

A.addSection(page,"Line variants",nil)
A.addSlider(page,"Line amount",1,25,1,10,function(v) amount=v end)

A.addToggle(page,"line1","Line 1 CreateGrabEvent",function()
    local r=S.getRefs()
    if not r.CreateGrabEvent or not r.CreateGrabEvent:IsA("RemoteEvent") then A.setStatus("CreateGrabEvent missing."); return false end
    task.spawn(function()
        while A.toggleState["line1"] do
            local p,tr=A.currentTarget()
            if p and tr then
                local target=p.Character and (p.Character:FindFirstChild("Head") or tr)
                local i; for i=1,amount do if not A.toggleState["line1"] then break end; S.fire2(r.CreateGrabEvent,target,Vector3.new(0,0,0)) end
            end
            RunService.Heartbeat:Wait()
        end
    end)
    return true
end,function() end)

A.addSlider(page,"Line 2 local extend distance",11,250,1,40,function(v) extendDist=v end)
A.addToggle(page,"line2","Line 2 local GrabParts extend",function()
    local conn
    local function handle(m)
        if not A.toggleState["line2"] or not m or m.Name~="GrabParts" then return end
        task.spawn(function()
            local gp=m:WaitForChild("GrabPart",2); local dp=m:WaitForChild("DragPart",2); if not gp or not dp then return end
            local clone; pcall(function() clone=dp:Clone(); clone.Name="DragPart1"; clone.Parent=m end)
            while A.toggleState["line2"] and m.Parent do
                local cam=Workspace.CurrentCamera
                if gp and gp.Parent and cam and gp:IsA("BasePart") then pcall(function() gp.Position=cam.CFrame.Position+cam.CFrame.LookVector*extendDist end) end
                RunService.RenderStepped:Wait()
            end
            if clone then pcall(function() clone:Destroy() end) end
        end)
    end
    conn=Workspace.ChildAdded:Connect(handle); A.toggleStops["line2"]=function() conn:Disconnect() end
    local e=Workspace:FindFirstChild("GrabParts"); if e then handle(e) end
    return true
end,function() if A.toggleStops["line2"] then A.toggleStops["line2"](); A.toggleStops["line2"]=nil end end)

A.addToggle(page,"line2b","Line 2B ExtendLineEvent legacy",function()
    local r=S.getRefs()
    if not r.ExtendLineEvent or not r.ExtendLineEvent:IsA("RemoteEvent") then A.setStatus("ExtendLineEvent missing."); return false end
    task.spawn(function()
        while A.toggleState["line2b"] do local i; for i=1,amount do S.fire1(r.ExtendLineEvent,1000000) end; RunService.Heartbeat:Wait() end
    end)
    return true
end,function() end)

A.addToggle(page,"line3","Line 3 CreateGrabLine fan",function()
    local r=S.getRefs()
    if not r.CreateGrabLine then A.setStatus("CreateGrabLine missing."); return false end
    task.spawn(function()
        local phase=0
        while A.toggleState["line3"] do
            local p,tr=A.currentTarget()
            if p and tr then
                local i
                for i=1,amount do
                    phase=phase+1
                    local a=(phase%16)/16*math.pi*2
                    local off=Vector3.new(math.cos(a)*5,(phase%5)-2,math.sin(a)*5)
                    S.fire4(r.CreateGrabLine,tr,off,tr.Position+off,false)
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
    return true
end,function() end)

A.addSection(page,"Owner variants",nil)
A.addSlider(page,"Owner intensity",1,100,1,5,function(v) ownerIntensity=v end)
A.addSlider(page,"Owner rate",1,100,1,30,function(v) ownerRate=v end)

A.addToggle(page,"owner1","Owner 1 all-player burst",function()
    local r=S.getRefs(); if not r.SetNetworkOwner then return false end
    task.spawn(function()
        while A.toggleState["owner1"] do
            local ps=Players:GetPlayers(); local a,i
            for a=1,ownerIntensity do
                for i=1,#ps do
                    if ps[i]~=LP then local tr=A.targetRoot(ps[i]); if tr then S.fire2(r.SetNetworkOwner,tr,tr.CFrame) end end
                end
            end
            task.wait(1)
        end
    end)
    return true
end,function() end)

A.addToggle(page,"owner2","Owner 2 selected rapid",function()
    local r=S.getRefs(); if not r.SetNetworkOwner then return false end
    task.spawn(function()
        while A.toggleState["owner2"] do
            local p,tr=A.currentTarget()
            if p and tr then local i; for i=1,math.max(1,math.floor(ownerRate/10)) do S.fire2(r.SetNetworkOwner,tr,tr.CFrame) end end
            task.wait(0.1)
        end
    end)
    return true
end,function() end)

A.addToggle(page,"owner3","Owner 3 legacy 'player'",function()
    local r=S.getRefs(); if not r.SetNetworkOwner then return false end
    task.spawn(function()
        while A.toggleState["owner3"] do
            local p,tr=A.currentTarget()
            if p and tr then local i; for i=1,math.max(1,math.floor(ownerRate/10)) do S.fire2(r.SetNetworkOwner,tr,"player") end end
            task.wait(0.1)
        end
    end)
    return true
end,function() end)

A.addSection(page,"Ping experimental","Public payload known; remote name must be entered exactly.")
local pingBox=A.addInput(page,"Ping RemoteEvent exact name","")
local packets=1000
A.addSlider(page,"Ping packet repetitions",100,3000,100,1000,function(v) packets=v end)
A.addToggle(page,"ping1","Ping 1 huge-string payload",function()
    local r=A.findRemote(pingBox.Text)
    if not r or not r:IsA("RemoteEvent") then A.setStatus("Enter valid RemoteEvent name."); return false end
    task.spawn(function()
        while A.toggleState["ping1"] do S.fire1(r,string.rep("Balls Balls Balls Balls",packets)); RunService.Heartbeat:Wait() end
    end)
    return true
end,function() end)

A.setStatus("LINE/LAG pack loaded.")
print("[FTAP V12 LAG] READY")
