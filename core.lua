-- FTAP V13 REMOTE MODULAR CORE
-- Small compatibility-first GUI shell. Execute this FIRST.
-- No HTTP/loadstring/debug/getgc/hooks. No PlaceId lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
if LP == nil then
    warn("[FTAP V13 CORE] LocalPlayer missing")
    return
end

local ENV = _G
if type(getgenv) == "function" then
    pcall(function()
        ENV = getgenv()
    end)
end

if ENV.FTAPV10 ~= nil and ENV.FTAPV10.shutdown ~= nil then
    pcall(ENV.FTAPV10.shutdown)
end

local API = {}
ENV.FTAPV10 = API

API.version = "13.0-remote-modular"
API.packs = {}
API.toggleState = {}
API.toggleBusy = {}
API.toggleLabels = {}
API.toggleButtons = {}
API.toggleBadges = {}
API.toggleStops = {}
API.toggleLastTap = {}
API.toggleDebounceSeconds = 0.45

local function getCharacter()
    local c = LP.Character
    if c == nil then return nil, nil, nil end

    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if r == nil then r = c:FindFirstChild("Torso") end
    if r == nil then r = c:FindFirstChild("UpperTorso") end

    return c, h, r
end
API.getCharacter = getCharacter

local function isDescendantOf(inst, parent)
    local n = inst
    while n ~= nil do
        if n == parent then return true end
        n = n.Parent
    end
    return false
end
API.isDescendantOf = isDescendantOf

local function findPlayer(text)
    local q = string.lower(tostring(text or ""))
    q = string.gsub(q, "^%s+", "")
    q = string.gsub(q, "%s+$", "")
    if q == "" then return nil end

    local list = Players:GetPlayers()
    local i

    for i = 1, #list do
        local p = list[i]
        if p ~= LP and string.lower(p.Name) == q then return p end
    end

    for i = 1, #list do
        local p = list[i]
        if p ~= LP then
            local n = string.lower(p.Name)
            local d = string.lower(p.DisplayName)

            if string.sub(n, 1, #q) == q or string.sub(d, 1, #q) == q then
                return p
            end
        end
    end

    return nil
end
API.findPlayer = findPlayer

local function targetRoot(p)
    if p == nil or p.Character == nil then return nil end

    local r = p.Character:FindFirstChild("HumanoidRootPart")
    if r == nil then r = p.Character:FindFirstChild("Torso") end
    if r == nil then r = p.Character:FindFirstChild("UpperTorso") end

    return r
end
API.targetRoot = targetRoot

local function findRemote(name)
    local d = ReplicatedStorage:GetDescendants()
    local i

    for i = 1, #d do
        local x = d[i]
        if (x:IsA("RemoteEvent") or x:IsA("RemoteFunction")) and x.Name == name then
            return x
        end
    end

    return nil
end
API.findRemote = findRemote

local function getRefs()
    local r = {}
    local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
    local ce = ReplicatedStorage:FindFirstChild("CharacterEvents")
    local gc = ReplicatedStorage:FindFirstChild("GameCorrectionEvents")

    if ge ~= nil then
        r.SetNetworkOwner = ge:FindFirstChild("SetNetworkOwner")
        r.CreateGrabLine = ge:FindFirstChild("CreateGrabLine")
        r.DestroyGrabLine = ge:FindFirstChild("DestroyGrabLine")
    end

    if ce ~= nil then
        r.Struggle = ce:FindFirstChild("Struggle")
        r.RagdollRemote = ce:FindFirstChild("RagdollRemote")
    end

    if gc ~= nil then
        r.StopAllVelocity = gc:FindFirstChild("StopAllVelocity")
    end

    if r.SetNetworkOwner == nil then r.SetNetworkOwner = findRemote("SetNetworkOwner") end
    if r.Struggle == nil then r.Struggle = findRemote("Struggle") end
    if r.RagdollRemote == nil then r.RagdollRemote = findRemote("RagdollRemote") end
    if r.StopAllVelocity == nil then r.StopAllVelocity = findRemote("StopAllVelocity") end

    r.CreateGrabEvent = findRemote("CreateGrabEvent")
    if r.CreateGrabEvent == nil then r.CreateGrabEvent = findRemote("CreateGrab") end

    return r
end
API.getRefs = getRefs

local COLORS = {
    BG = Color3.fromRGB(17, 19, 24),
    PANEL = Color3.fromRGB(25, 28, 34),
    CARD = Color3.fromRGB(34, 38, 46),
    ON = Color3.fromRGB(39, 92, 69),
    TEXT = Color3.fromRGB(240, 242, 246),
    MUTED = Color3.fromRGB(150, 158, 174),
    ACCENT = Color3.fromRGB(104, 119, 226),
    RED = Color3.fromRGB(98, 42, 51)
}
API.COLORS = COLORS

local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 8)
if pg == nil then
    warn("[FTAP V13 CORE] PlayerGui missing")
    return
end

local old = pg:FindFirstChild("FTAPV10Core")
if old ~= nil then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "FTAPV10Core"
gui.ResetOnSpawn = false
gui.DisplayOrder = 99999
gui.Parent = pg
API.gui = gui

local shell = Instance.new("Frame")
shell.Parent = gui
shell.Size = UDim2.new(0, 680, 0, 520)
shell.Position = UDim2.new(0.5, -340, 0.5, -260)
shell.BackgroundColor3 = COLORS.BG
shell.BorderSizePixel = 0
shell.Active = true
API.shell = shell

local top = Instance.new("Frame")
top.Parent = shell
top.Size = UDim2.new(1, 0, 0, 46)
top.BackgroundColor3 = COLORS.PANEL
top.BorderSizePixel = 0
top.Active = true

local title = Instance.new("TextLabel")
title.Parent = top
title.Position = UDim2.new(0, 12, 0, 5)
title.Size = UDim2.new(1, -160, 0, 20)
title.BackgroundTransparency = 1
title.TextColor3 = COLORS.TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Text = "FTAP V13 REMOTE MODULAR CORE"

local subtitle = Instance.new("TextLabel")
subtitle.Parent = top
subtitle.Position = UDim2.new(0, 12, 0, 24)
subtitle.Size = UDim2.new(1, -160, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = COLORS.MUTED
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 9
subtitle.Text = "small core + automatically fetched feature packs"

local hide = Instance.new("TextButton")
hide.Parent = top
hide.Size = UDim2.new(0, 52, 0, 28)
hide.Position = UDim2.new(1, -120, 0, 9)
hide.BackgroundColor3 = COLORS.CARD
hide.TextColor3 = COLORS.TEXT
hide.Text = "HIDE"
hide.Font = Enum.Font.GothamSemibold
hide.TextSize = 9

local close = Instance.new("TextButton")
close.Parent = top
close.Size = UDim2.new(0, 52, 0, 28)
close.Position = UDim2.new(1, -62, 0, 9)
close.BackgroundColor3 = COLORS.RED
close.TextColor3 = COLORS.TEXT
close.Text = "CLOSE"
close.Font = Enum.Font.GothamSemibold
close.TextSize = 9

local side = Instance.new("ScrollingFrame")
side.Parent = shell
side.Position = UDim2.new(0, 0, 0, 46)
side.Size = UDim2.new(0, 132, 1, -46)
side.BackgroundColor3 = COLORS.PANEL
side.BorderSizePixel = 0
side.ScrollBarThickness = 2
side.AutomaticCanvasSize = Enum.AutomaticSize.Y
side.CanvasSize = UDim2.new(0, 0, 0, 0)

local sideList = Instance.new("UIListLayout")
sideList.Parent = side
sideList.Padding = UDim.new(0, 4)

local sidePad = Instance.new("UIPadding")
sidePad.Parent = side
sidePad.PaddingTop = UDim.new(0, 8)
sidePad.PaddingLeft = UDim.new(0, 6)
sidePad.PaddingRight = UDim.new(0, 6)

local content = Instance.new("Frame")
content.Parent = shell
content.Position = UDim2.new(0, 132, 0, 46)
content.Size = UDim2.new(1, -132, 1, -46)
content.BackgroundColor3 = COLORS.BG
content.BorderSizePixel = 0

local target = Instance.new("TextBox")
target.Parent = content
target.Position = UDim2.new(0, 10, 0, 9)
target.Size = UDim2.new(1, -20, 0, 32)
target.BackgroundColor3 = COLORS.CARD
target.TextColor3 = COLORS.TEXT
target.PlaceholderColor3 = COLORS.MUTED
target.PlaceholderText = "Target username/display name"
target.Text = ""
target.ClearTextOnFocus = false
target.Font = Enum.Font.Gotham
target.TextSize = 10
API.targetBox = target

local status = Instance.new("TextLabel")
status.Parent = content
status.Position = UDim2.new(0, 10, 0, 47)
status.Size = UDim2.new(1, -20, 0, 42)
status.BackgroundColor3 = COLORS.PANEL
status.TextColor3 = COLORS.MUTED
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Center
status.Font = Enum.Font.Code
status.TextSize = 9
status.Text = "CORE loaded."
API.statusLabel = status

local host = Instance.new("Frame")
host.Parent = content
host.Position = UDim2.new(0, 10, 0, 96)
host.Size = UDim2.new(1, -20, 1, -106)
host.BackgroundTransparency = 1
API.pageHost = host

local function setStatus(text)
    status.Text = tostring(text)
    print("[FTAP V13] " .. tostring(text))
end
API.setStatus = setStatus

function API.currentTarget()
    local p = findPlayer(target.Text)
    return p, targetRoot(p)
end

local pages = {}
local navs = {}
API.pages = pages

function API.makePage(name)
    if pages[name] ~= nil then return pages[name] end

    local p = Instance.new("ScrollingFrame")
    p.Name = name
    p.Parent = host
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.Visible = false

    local l = Instance.new("UIListLayout")
    l.Parent = p
    l.Padding = UDim.new(0, 6)

    pages[name] = p

    local n = Instance.new("TextButton")
    n.Parent = side
    n.Size = UDim2.new(1, 0, 0, 29)
    n.BackgroundColor3 = COLORS.CARD
    n.TextColor3 = COLORS.MUTED
    n.TextXAlignment = Enum.TextXAlignment.Left
    n.Text = "  " .. name
    n.Font = Enum.Font.GothamSemibold
    n.TextSize = 9
    navs[name] = n

    n.Activated:Connect(function()
        API.showPage(name)
    end)

    return p
end

function API.showPage(name)
    local k
    local p
    local b

    for k, p in pairs(pages) do
        p.Visible = (k == name)
    end

    for k, b in pairs(navs) do
        if k == name then
            b.BackgroundColor3 = COLORS.ACCENT
            b.TextColor3 = COLORS.TEXT
        else
            b.BackgroundColor3 = COLORS.CARD
            b.TextColor3 = COLORS.MUTED
        end
    end
end

function API.addSection(page, titleText, desc)
    local h = Instance.new("TextLabel")
    h.Parent = page
    h.Size = UDim2.new(1, -2, 0, desc and 42 or 26)
    h.BackgroundTransparency = 1
    h.TextColor3 = COLORS.TEXT
    h.TextXAlignment = Enum.TextXAlignment.Left
    h.TextYAlignment = Enum.TextYAlignment.Top
    h.TextWrapped = true
    h.Font = Enum.Font.GothamSemibold
    h.TextSize = 10

    if desc ~= nil then
        h.Text = titleText .. "\n" .. desc
    else
        h.Text = titleText
    end

    return h
end

function API.addButton(page, label, callback, danger)
    local b = Instance.new("TextButton")
    b.Parent = page
    b.Size = UDim2.new(1, -2, 0, 34)
    b.BackgroundColor3 = danger and COLORS.RED or COLORS.CARD
    b.TextColor3 = COLORS.TEXT
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "   " .. label
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 9

    b.Activated:Connect(function()
        API.touchFeature(label)

        local ok, err = pcall(function()
            callback(b)
        end)

        if not ok then setStatus("ERROR " .. label .. ": " .. tostring(err)) end
    end)

    return b
end

local function renderToggle(key)
    local b = API.toggleButtons[key]
    local label = API.toggleLabels[key]
    local badge = API.toggleBadges[key]

    if b == nil or label == nil then return end

    if API.toggleState[key] then
        b.Text = "   DISABLE  " .. label
        b.BackgroundColor3 = COLORS.ON

        if badge ~= nil then
            badge.Text = "ENABLED"
            badge.TextColor3 = Color3.fromRGB(145, 255, 180)
        end
    else
        b.Text = "   ENABLE   " .. label
        b.BackgroundColor3 = COLORS.CARD

        if badge ~= nil then
            badge.Text = "DISABLED"
            badge.TextColor3 = COLORS.MUTED
        end
    end
end
API.renderToggle = renderToggle

function API.addToggle(page, key, label, onEnable, onDisable)
    API.toggleState[key] = false
    API.toggleBusy[key] = false
    API.toggleLabels[key] = label
    API.toggleLastTap[key] = 0

    local b = Instance.new("TextButton")
    b.Parent = page
    b.Size = UDim2.new(1, -2, 0, 40)
    b.BackgroundColor3 = COLORS.CARD
    b.TextColor3 = COLORS.TEXT
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 9
    b.AutoButtonColor = true

    local badge = Instance.new("TextLabel")
    badge.Parent = b
    badge.AnchorPoint = Vector2.new(1, 0.5)
    badge.Position = UDim2.new(1, -8, 0.5, 0)
    badge.Size = UDim2.new(0, 76, 0, 20)
    badge.BackgroundTransparency = 1
    badge.TextXAlignment = Enum.TextXAlignment.Right
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 8

    API.toggleButtons[key] = b
    API.toggleBadges[key] = badge
    renderToggle(key)

    b.Activated:Connect(function()
        local now = os.clock()
        local last = API.toggleLastTap[key] or 0

        -- Waydroid/fake-touch can generate two Activated events for one tap.
        -- Ignore the duplicate so a toggle cannot instantly go ON -> OFF.
        if now - last < API.toggleDebounceSeconds then
            return
        end

        API.toggleLastTap[key] = now
        API.touchFeature(label)

        if API.toggleBusy[key] then return end
        API.toggleBusy[key] = true

        local nextValue = not API.toggleState[key]
        API.toggleState[key] = nextValue
        renderToggle(key)

        if nextValue then
            local ok, result = pcall(function()
                if onEnable ~= nil then return onEnable() end
                return true
            end)

            if not ok or result == false then
                API.toggleState[key] = false
                renderToggle(key)

                if not ok then
                    setStatus(label .. " failed: " .. tostring(result))
                elseif result == false then
                    setStatus(label .. " could not enable.")
                end
            end
        else
            if onDisable ~= nil then
                pcall(onDisable)
            end
        end

        renderToggle(key)
        API.toggleBusy[key] = false
    end)

    return b
end

function API.forceToggle(key, value)
    if API.toggleState[key] == nil then return end
    API.toggleState[key] = value and true or false
    renderToggle(key)
end

function API.addSlider(page, label, minValue, maxValue, step, initial, callback)
    local box = Instance.new("Frame")
    box.Parent = page
    box.Size = UDim2.new(1, -2, 0, 48)
    box.BackgroundColor3 = COLORS.CARD
    box.BorderSizePixel = 0

    local txt = Instance.new("TextLabel")
    txt.Parent = box
    txt.Position = UDim2.new(0, 8, 0, 2)
    txt.Size = UDim2.new(1, -16, 0, 18)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = COLORS.TEXT
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 9

    local bar = Instance.new("Frame")
    bar.Parent = box
    bar.Position = UDim2.new(0, 8, 0, 30)
    bar.Size = UDim2.new(1, -16, 0, 7)
    bar.BackgroundColor3 = Color3.fromRGB(58, 63, 74)
    bar.BorderSizePixel = 0

    local fill = Instance.new("Frame")
    fill.Parent = bar
    fill.BackgroundColor3 = COLORS.ACCENT
    fill.BorderSizePixel = 0

    local current = initial
    local dragging = false

    local function apply(v)
        if v < minValue then v = minValue end
        if v > maxValue then v = maxValue end
        v = math.floor(((v - minValue) / step) + 0.5) * step + minValue
        current = v

        local a = (current - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(a, 0, 1, 0)
        txt.Text = label .. ": " .. tostring(current)

        if callback ~= nil then callback(current) end
    end

    local function fromX(x)
        if bar.AbsoluteSize.X <= 0 then return end
        local a = (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
        if a < 0 then a = 0 end
        if a > 1 then a = 1 end
        apply(minValue + (maxValue - minValue) * a)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and
           (input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    apply(initial)
    return function() return current end
end


function API.addInput(page, label, defaultText)
    local box = Instance.new("Frame")
    box.Parent = page
    box.Size = UDim2.new(1, -2, 0, 48)
    box.BackgroundColor3 = COLORS.CARD
    box.BorderSizePixel = 0

    local lab = Instance.new("TextLabel")
    lab.Parent = box
    lab.Position = UDim2.new(0, 8, 0, 2)
    lab.Size = UDim2.new(1, -16, 0, 17)
    lab.BackgroundTransparency = 1
    lab.TextColor3 = COLORS.MUTED
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.Font = Enum.Font.Gotham
    lab.TextSize = 9
    lab.Text = label

    local input = Instance.new("TextBox")
    input.Parent = box
    input.Position = UDim2.new(0, 8, 0, 21)
    input.Size = UDim2.new(1, -16, 0, 23)
    input.BackgroundColor3 = COLORS.PANEL
    input.TextColor3 = COLORS.TEXT
    input.PlaceholderColor3 = COLORS.MUTED
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.Code
    input.TextSize = 9
    input.Text = defaultText or ""

    return input
end

API.lastFeature = "none"
API.featureResults = {}

function API.touchFeature(label)
    API.lastFeature = tostring(label or "unknown")
end

function API.markFeature(result)
    if API.lastFeature == nil or API.lastFeature == "none" then
        setStatus("No feature used yet.")
        return
    end

    API.featureResults[API.lastFeature] = tostring(result)
    setStatus("RESULT: " .. API.lastFeature .. " = " .. tostring(result))
end

function API.registerPack(name)
    API.packs[name] = true
    setStatus("Pack loaded: " .. name)
end

local originalMouseIcon = UserInputService.MouseIconEnabled
local originalMouseBehavior = UserInputService.MouseBehavior
local cursorConn = RunService.RenderStepped:Connect(function()
    if shell.Visible then
        pcall(function()
            UserInputService.MouseIconEnabled = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end)
    end
end)

hide.Activated:Connect(function()
    shell.Visible = false
    pcall(function()
        UserInputService.MouseIconEnabled = originalMouseIcon
        UserInputService.MouseBehavior = originalMouseBehavior
    end)
end)

local show = Instance.new("TextButton")
show.Parent = gui
show.Size = UDim2.new(0, 90, 0, 30)
show.Position = UDim2.new(0, 10, 0.5, -15)
show.BackgroundColor3 = COLORS.ACCENT
show.TextColor3 = COLORS.TEXT
show.Text = "SHOW FTAP"
show.Font = Enum.Font.GothamSemibold
show.TextSize = 9
show.Visible = false

hide.Activated:Connect(function()
    show.Visible = true
end)

show.Activated:Connect(function()
    show.Visible = false
    shell.Visible = true
end)

local CORE = API.makePage("CORE")

API.addSection(CORE, "V12 remote modular core",
    "If this executes, run feature-pack files afterward. Splitting avoids the giant-file failure from V9.1.")

API.addButton(CORE, "EXECUTION TEST", function()
    setStatus("V10 CORE EXECUTION TEST PASSED")
    print("FTAP_V13_CORE_EXECUTION_TEST_PASSED")
end)

API.addButton(CORE, "RECON", function()
    local r = getRefs()
    setStatus(
        "Struggle=" .. tostring(r.Struggle ~= nil) ..
        " StopVel=" .. tostring(r.StopAllVelocity ~= nil) ..
        " SetOwner=" .. tostring(r.SetNetworkOwner ~= nil) ..
        " CreateGrab=" .. tostring(r.CreateGrabEvent ~= nil)
    )
end)

API.addButton(CORE, "Loaded packs", function()
    local names = {}
    local k

    for k in pairs(API.packs) do names[#names + 1] = k end
    table.sort(names)

    if #names == 0 then
        setStatus("No feature packs loaded yet.")
    else
        setStatus("Packs: " .. table.concat(names, ", "))
    end
end)

local dragging = false
local dragStart = nil
local startPos = nil

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = shell.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and dragStart ~= nil and startPos ~= nil and
       (input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch) then

        local d = input.Position - dragStart
        shell.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + d.X,
            startPos.Y.Scale,
            startPos.Y.Offset + d.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

function API.shutdown()
    local key

    for key in pairs(API.toggleState) do
        API.toggleState[key] = false
    end

    for key, stop in pairs(API.toggleStops) do
        pcall(stop)
    end

    if cursorConn ~= nil then pcall(function() cursorConn:Disconnect() end) end

    pcall(function()
        UserInputService.MouseIconEnabled = originalMouseIcon
        UserInputService.MouseBehavior = originalMouseBehavior
    end)

    pcall(function() gui:Destroy() end)

    if ENV.FTAPV10 == API then ENV.FTAPV10 = nil end
end

close.Activated:Connect(API.shutdown)

API.showPage("CORE")
setStatus("V10 CORE loaded. Run EXECUTION TEST, then execute feature pack files.")
print("[FTAP V13 CORE] READY")
