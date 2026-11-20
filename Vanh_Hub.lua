-- =====================================================
--  Vanh Hub - Blox Fruits
--  Dùng cho: Delta / Solara / Fluxus / KRNL
--  PC: RightShift để ẩn/hiện menu. Mobile: chạm nút 🍇
-- =====================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer

-- Gỡ bản cũ (kể cả BF Hack / BF Hub) nếu chạy lại script
local env = (getgenv and getgenv()) or _G
if env.BF_Unload then pcall(env.BF_Unload) end
for _, parent in ipairs({ CoreGui, LP:FindFirstChildOfClass("PlayerGui") }) do
    pcall(function()
        for _, name in ipairs({ "BF_Hack", "BF_Hub", "Vanh_Hub" }) do
            local old = parent:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
end

-- =====================================================
--  CẤU HÌNH
-- =====================================================
local config = {
    -- Cày
    autoFarm = false,
    farmAttack = true,       -- tự đánh khi đang cày
    autoClick = false,       -- bấm đánh liên tục
    autoEquip = true,
    weaponType = "Melee",    -- Melee / Sword / Gun / Blox Fruit (theo ToolTip)
    farmRange = 200,
    farmDist = 3,
    farmHeight = 0,
    clickRate = 8,
    levelFilter = false,     -- chỉ đánh quái hợp cấp
    levelBelow = 50,
    levelAbove = 20,
    huntOnly = false,        -- chỉ đánh quái/boss theo tên đã chọn
    huntName = nil,
    autoFruit = false,
    fruitAlert = false,

    -- Chỉ số
    autoStats = false,
    statType = "Melee",      -- Melee / Defense / Sword / Gun / Demon Fruit
    statStep = 5,

    -- Nhân vật
    speedBoost = false,
    walkSpeed = 50,
    jumpPower = 100,
    noclip = false,
    infJump = false,
    fly = false,
    flySpeed = 60,
    antiAfk = true,

    -- Hiển thị
    espFruits = false,
    espChest = false,
    espPlayers = false,
    espRange = 500,
    fullbright = false,

    -- Dịch chuyển
    smoothTp = true,
    tpSpeed = 250,

    -- Cài đặt
    notify = true,
}

-- =====================================================
--  TRẠNG THÁI
-- =====================================================
local running = true
local connections = {}
local target = nil
local lastScan = 0
local busyUntil = 0
local orig = { walk = 16, jump = 50 }
local noclipped = {}
local spawnCF = nil
local currentTween = nil
local flyBV, flyBG = nil, nil
local lightOrig = nil
local activeDrag = nil
local levelWarned = false
local waypoints, wpCounter = {}, 0
local unload -- định nghĩa ở cuối file

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Vanh Hub] " .. tostring(err)) end
end

local function getChar()
    local char = LP.Character
    if not char then return end
    return char,
        char:FindFirstChildOfClass("Humanoid"),
        char:FindFirstChild("HumanoidRootPart")
end

local function isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

-- Đọc số liệu người chơi (LP.Data.<tên>.Value); trả về nil nếu game không có
local function playerNumber(name)
    local ok, v = pcall(function() return LP.Data[name].Value end)
    return ok and tonumber(v) or nil
end

-- =====================================================
--  BẢNG MÀU: nền xanh đêm biển, nhấn màu hổ phách
-- =====================================================
local T = {
    bg1 = Color3.fromRGB(20, 30, 44),
    bg2 = Color3.fromRGB(11, 17, 27),
    surface = Color3.fromRGB(28, 41, 58),
    surface2 = Color3.fromRGB(40, 58, 80),
    stroke = Color3.fromRGB(70, 95, 125),
    off = Color3.fromRGB(58, 76, 98),
    text = Color3.fromRGB(232, 238, 245),
    muted = Color3.fromRGB(141, 160, 182),
    accent = Color3.fromRGB(255, 176, 58),
    accent2 = Color3.fromRGB(255, 122, 89),
    good = Color3.fromRGB(61, 219, 165),
    bad = Color3.fromRGB(255, 107, 107),
    ink = Color3.fromRGB(30, 22, 8), -- chữ trên nền hổ phách
}

-- =====================================================
--  HÀM TIỆN ÍCH UI
-- =====================================================
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(obj, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, obj) end

local function stroke(obj, color, thickness, transparency)
    return new("UIStroke", {
        Color = color, Thickness = thickness or 1, Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

local function grad(obj, c1, c2, rotation)
    obj.BackgroundColor3 = Color3.new(1, 1, 1)
    return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 0 }, obj)
end

local function tween(obj, props, t)
    TweenService:Create(obj,
        TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function text(parent, str, size, color, font, props)
    local l = new("TextLabel", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = str, TextSize = size or 13,
        TextColor3 = color or T.text, Font = font or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    for k, v in pairs(props or {}) do l[k] = v end
    l.Parent = parent
    return l
end

local function beginDrag(d)
    if activeDrag and activeDrag.finish then activeDrag.finish() end
    activeDrag = d
end

connect(UIS.InputChanged, function(input)
    if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        activeDrag.move(input)
    end
end)
connect(UIS.InputEnded, function(input)
    if activeDrag and isPointer(input) then
        local d = activeDrag
        activeDrag = nil
        if d.finish then d.finish() end
    end
end)

-- =====================================================
--  GUI GỐC
-- =====================================================
local gui = new("ScreenGui", {
    Name = "Vanh_Hub", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local okParent = pcall(function()
    gui.Parent = (gethui and gethui()) or CoreGui
end)
if not okParent or not gui.Parent then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

-- ----- Thông báo (toast) -----
local toastHolder = new("Frame", {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12),
    Size = UDim2.new(0, 230, 1, -24), BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, toastHolder)
local toastN = 0

-- force = true: vẫn hiện dù đã tắt thông báo (dùng cho cảnh báo lỗi / báo trái)
local function notify(title, msg, dur, color, force)
    if not config.notify and not force then return end
    toastN = toastN + 1
    local t = new("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.surface, BorderSizePixel = 0,
        GroupTransparency = 1, LayoutOrder = toastN,
    }, toastHolder)
    corner(t, 10)
    stroke(t, T.stroke, 1, 0.5)
    corner(new("Frame", {
        Size = UDim2.new(0, 3, 1, -14), Position = UDim2.new(0, 7, 0, 7),
        BackgroundColor3 = color or T.accent, BorderSizePixel = 0,
    }, t), 2)
    text(t, title, 13, T.text, Enum.Font.GothamBold, { Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 18, 0, 5) })
    text(t, msg or "", 12, T.muted, nil, { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 18, 0, 22) })
    tween(t, { GroupTransparency = 0 }, 0.2)
    task.delay(dur or 2, function()
        if t.Parent then
            tween(t, { GroupTransparency = 1 }, 0.25)
            task.wait(0.3)
            t:Destroy()
        end
    end)
end

-- ----- Cửa sổ chính -----
local vp = workspace.CurrentCamera.ViewportSize
local W = math.clamp(vp.X * 0.85, 360, 580)
local H = math.clamp(vp.Y * 0.8, 250, 350)

local main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, W, 0, H), BorderSizePixel = 0, Active = true,
}, gui)
corner(main, 14)
stroke(main, T.stroke, 1, 0.35)
grad(main, T.bg1, T.bg2, 90)

local topbar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Active = true,
}, main)
text(topbar, "🍇 Vanh Hub", 17, T.text, Enum.Font.GothamBold, { Size = UDim2.new(0, 112, 1, 0), Position = UDim2.new(0, 14, 0, 0) })
text(topbar, "Blox Fruits", 11, T.muted, nil, { Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(0, 128, 0, 2) })

local function topButton(label, xOff, color, cb)
    local b = new("TextButton", {
        Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, xOff, 0.5, -14),
        BackgroundColor3 = T.surface, Text = label, TextColor3 = color,
        Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false, BorderSizePixel = 0,
    }, topbar)
    corner(b, 8)
    b.MouseButton1Click:Connect(cb)
    return b
end
topButton("–", -76, T.muted, function() main.Visible = false end)
topButton("✕", -42, T.bad, function() unload() end)

local accentLine = new("Frame", {
    Position = UDim2.new(0, 14, 0, 42), Size = UDim2.new(1, -28, 0, 2), BorderSizePixel = 0,
}, main)
corner(accentLine, 1)
grad(accentLine, T.accent, T.accent2, 0)

-- Thanh tab bên trái (cuộn được nếu màn hình thấp)
local sidebar = new("ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(0, 116, 1, -46),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, sidebar)

local content = new("Frame", {
    Position = UDim2.new(0, 116, 0, 46), Size = UDim2.new(1, -116, 1, -46),
    BackgroundTransparency = 1, ClipsDescendants = true,
}, main)

-- Kéo cửa sổ / nút nổi (chạm không kéo = bấm)
local function makeDraggable(handle, dragTarget, onTap)
    handle.InputBegan:Connect(function(input)
        if not isPointer(input) then return end
        local startPointer = input.Position
        local startPos = dragTarget.Position
        local moved = false
        beginDrag({
            move = function(i)
                local d = i.Position - startPointer
                if not moved and d.Magnitude > 5 then moved = true end
                if moved then
                    dragTarget.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + d.X,
                        startPos.Y.Scale, startPos.Y.Offset + d.Y)
                end
            end,
            finish = function()
                if not moved and onTap then onTap() end
            end,
        })
    end)
end
makeDraggable(topbar, main)

local float = new("TextButton", {
    Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(0, 12, 0.4, 0),
    Text = "🍇", TextSize = 22, Font = Enum.Font.GothamBold,
    AutoButtonColor = false, BorderSizePixel = 0,
}, gui)
corner(float, 23)
stroke(float, T.accent, 2, 0.1)
grad(float, T.bg1, T.surface2, 90)
makeDraggable(float, float, function() main.Visible = not main.Visible end)

connect(UIS.InputBegan, function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

-- =====================================================
--  TAB + THÀNH PHẦN UI
-- =====================================================
local tabs = {}

local function selectTab(name)
    for n, t in pairs(tabs) do
        local on = (n == name)
        t.page.Visible = on
        t.bar.Visible = on
        t.btn.TextColor3 = on and T.text or T.muted
        tween(t.btn, { BackgroundTransparency = on and 0 or 1 }, 0.15)
    end
end

local function addTab(name, icon, order)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.surface, BackgroundTransparency = 1,
        Text = "   " .. icon .. "  " .. name, TextColor3 = T.muted, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
        BorderSizePixel = 0, LayoutOrder = order,
    }, sidebar)
    corner(btn, 9)
    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = T.accent, BorderSizePixel = 0, Visible = false,
    }, btn)
    corner(bar, 2)

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
    }, content)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12),
    }, page)

    tabs[name] = { btn = btn, bar = bar, page = page }
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

local orderCount = setmetatable({}, { __mode = "k" })
local function nextOrder(page)
    orderCount[page] = (orderCount[page] or 0) + 1
    return orderCount[page]
end

local function newRow(page, height, class, props)
    local row = new(class or "Frame", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = T.surface,
        BorderSizePixel = 0, LayoutOrder = nextOrder(page),
    })
    for k, v in pairs(props or {}) do row[k] = v end
    row.Parent = page
    corner(row, 10)
    return row
end

local function section(page, title)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = nextOrder(page),
    }, page)
    corner(new("Frame", {
        Size = UDim2.new(0, 3, 0, 12), Position = UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = T.accent, BorderSizePixel = 0,
    }, f), 2)
    text(f, title, 12, T.muted, Enum.Font.GothamBold, { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
end

local function toggle(page, label, key, cb)
    local row = newRow(page, 38, "TextButton", { Text = "", AutoButtonColor = false })
    text(row, label, 13, T.text, nil, { Size = UDim2.new(1, -64, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
    local sw = new("Frame", {
        Size = UDim2.new(0, 38, 0, 20), Position = UDim2.new(1, -50, 0.5, -10),
        BackgroundColor3 = T.off, BorderSizePixel = 0,
    }, row)
    corner(sw, 10)
    local knob = new("Frame", {
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, sw)
    corner(knob, 8)

    local function render()
        local on = config[key]
        tween(sw, { BackgroundColor3 = on and T.accent or T.off })
        tween(knob, { Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) })
    end
    row.MouseButton1Click:Connect(function()
        config[key] = not config[key]
        render()
        if cb then safe(cb, config[key]) end
        notify(label, config[key] and "Đã bật" or "Đã tắt", 1.2, config[key] and T.good or T.muted)
    end)
    render()
end

local function slider(page, label, key, min, max, step, cb, unit)
    local row = newRow(page, 54)
    text(row, label, 13, T.text, nil, { Size = UDim2.new(0.65, 0, 0, 24), Position = UDim2.new(0, 12, 0, 4) })
    local valueLbl = text(row, "", 12, T.accent, Enum.Font.GothamBold, {
        Size = UDim2.new(0.35, -12, 0, 24), Position = UDim2.new(0.65, 0, 0, 4),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = new("Frame", {
        Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 36),
        BackgroundColor3 = T.off, BorderSizePixel = 0,
    }, row)
    corner(track, 3)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, track)
    corner(fill, 3)
    grad(fill, T.accent, T.accent2, 0)
    local knob = new("Frame", {
        Size = UDim2.new(0, 14, 0, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, track)
    corner(knob, 7)
    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1, Text = "", BorderSizePixel = 0,
    }, row)

    local function render()
        local frac = (config[key] - min) / (max - min)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, 0, 0.5, 0)
        valueLbl.Text = tostring(config[key]) .. (unit or "")
    end
    local function setFromX(x)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local frac = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        local v = math.clamp(math.floor((min + frac * (max - min)) / step + 0.5) * step, min, max)
        if v ~= config[key] then
            config[key] = v
            render()
            if cb then safe(cb, v) end
        end
    end
    hit.InputBegan:Connect(function(input)
        if not isPointer(input) then return end
        page.ScrollingEnabled = false -- để kéo thanh trượt không bị cuộn trang
        setFromX(input.Position.X)
        beginDrag({
            move = function(i) setFromX(i.Position.X) end,
            finish = function() page.ScrollingEnabled = true end,
        })
    end)
    render()
end

local function button(page, label, cb, secondary)
    local row = newRow(page, 36, "TextButton", {
        Text = label, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false,
        TextColor3 = secondary and T.text or T.ink,
    })
    if secondary then
        row.BackgroundColor3 = T.surface2
    else
        grad(row, T.accent, T.accent2, 0)
    end
    row.MouseButton1Click:Connect(function()
        tween(row, { BackgroundTransparency = 0.4 }, 0.07)
        task.delay(0.12, function() tween(row, { BackgroundTransparency = 0 }, 0.15) end)
        safe(cb)
    end)
end

-- options = { {"Nhãn tiếng Việt", "giá trị trong game"}, ... }
local function choice(page, label, key, options, cb)
    local row = newRow(page, 62)
    text(row, label, 13, T.text, nil, { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.new(0, 12, 0, 4) })
    local holder = new("Frame", {
        Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 30), BackgroundTransparency = 1,
    }, row)
    local btns, n = {}, #options
    local function render()
        for i, b in ipairs(btns) do
            local on = (options[i][2] == config[key])
            tween(b, { BackgroundColor3 = on and T.accent or T.surface2 }, 0.12)
            b.TextColor3 = on and T.ink or T.muted
        end
    end
    for i, opt in ipairs(options) do
        local b = new("TextButton", {
            Size = UDim2.new(1 / n, -4, 1, 0), Position = UDim2.new((i - 1) / n, 2, 0, 0),
            Text = opt[1], Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
            BorderSizePixel = 0, BackgroundColor3 = T.surface2, TextColor3 = T.muted,
        }, holder)
        corner(b, 7)
        b.MouseButton1Click:Connect(function()
            config[key] = opt[2]
            render()
            if cb then safe(cb, opt[2]) end
        end)
        btns[i] = b
    end
    render()
end

local function infoRow(page, label)
    local row = newRow(page, 30)
    text(row, label, 12, T.muted, nil, { Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
    return text(row, "—", 12, T.text, Enum.Font.GothamBold, {
        Size = UDim2.new(0.45, -12, 1, 0), Position = UDim2.new(0.55, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
end

-- Bộ chọn danh sách bằng nút ◀ ▶. getItems() trả về { {label=..., value=...}, ... }
local function listPicker(page, getItems, emptyText, onPick)
    local row = newRow(page, 38)
    local nameLbl = text(row, "", 13, T.text, Enum.Font.GothamBold, {
        Size = UDim2.new(1, -96, 1, 0), Position = UDim2.new(0, 48, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local picker = { index = 1 }
    function picker.current()
        local items = getItems()
        if #items == 0 then return nil end
        picker.index = ((picker.index - 1) % #items) + 1
        return items[picker.index]
    end
    function picker.refresh()
        local item = picker.current()
        nameLbl.Text = item and item.label or emptyText
        if onPick then onPick(item) end
    end
    local function arrow(label, pos, delta)
        local b = new("TextButton", {
            Size = UDim2.new(0, 34, 0, 26), Position = pos, BackgroundColor3 = T.surface2,
            Text = label, TextColor3 = T.text, Font = Enum.Font.GothamBold, TextSize = 13,
            AutoButtonColor = false, BorderSizePixel = 0,
        }, row)
        corner(b, 7)
        b.MouseButton1Click:Connect(function()
            picker.index = picker.index + delta
            picker.refresh()
        end)
    end
    arrow("◀", UDim2.new(0, 8, 0.5, -13), -1)
    arrow("▶", UDim2.new(1, -42, 0.5, -13), 1)
    picker.refresh()
    return picker
end

-- =====================================================
--  LOGIC: DI CHUYỂN / DỊCH CHUYỂN
-- =====================================================
local function recordSpawn(char)
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if root then spawnCF = root.CFrame end
end
if LP.Character then task.spawn(recordSpawn, LP.Character) end
connect(LP.CharacterAdded, function(char) task.spawn(recordSpawn, char) end)

local function getSpawnCF()
    local loc = LP.RespawnLocation
    if loc and loc.Parent then return loc.CFrame + Vector3.new(0, 5, 0) end
    return spawnCF
end

-- Trả về thời gian di chuyển (giây); 0 nếu dịch tức thời
local function teleportTo(cf)
    local _, _, root = getChar()
    if not root then return 0 end
    if currentTween then currentTween:Cancel() currentTween = nil end
    if not config.smoothTp then
        root.CFrame = cf
        return 0
    end
    local dist = (root.Position - cf.Position).Magnitude
    local dur = math.max(dist / config.tpSpeed, 0.05)
    currentTween = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = cf })
    currentTween:Play()
    return dur
end

-- =====================================================
--  LOGIC: TRÁI ÁC QUỶ / RƯƠNG / NGƯỜI CHƠI / ĐẢO
-- =====================================================
local function isFruit(obj)
    if not obj.Name:find("Fruit") then return false end
    if not (obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    if Players:GetPlayerFromCharacter(obj) then return false end
    if obj:FindFirstChildOfClass("Humanoid") then return false end
    return true
end

local function findPart(obj)
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)
end

local function getFruits()
    local list = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if isFruit(obj) then
            local part = findPart(obj)
            if part then list[#list + 1] = { obj = obj, part = part, name = obj.Name } end
        end
    end
    return list
end

local function getChests()
    local list = {}
    local function scan(container)
        for _, obj in ipairs(container:GetChildren()) do
            if obj.Name:find("Chest") and not obj:FindFirstChildOfClass("Humanoid") then
                local part = findPart(obj)
                if part then list[#list + 1] = { obj = obj, part = part, name = obj.Name } end
            end
        end
    end
    scan(workspace)
    local folder = workspace:FindFirstChild("ChestModels")
    if folder then scan(folder) end
    return list
end

local function getOtherPlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then list[#list + 1] = { obj = p.Character, part = hrp, name = p.DisplayName } end
        end
    end
    return list
end

local function nearestFruit(root)
    local best, bestD
    for _, f in ipairs(getFruits()) do
        local d = (f.part.Position - root.Position).Magnitude
        if not bestD or d < bestD then best, bestD = f, d end
    end
    return best
end

-- Danh sách đảo lấy từ workspace._WorldOrigin.Locations (nếu game có)
local function getIslands()
    local list = {}
    local wo = workspace:FindFirstChild("_WorldOrigin")
    local folder = wo and wo:FindFirstChild("Locations")
    if folder then
        for _, p in ipairs(folder:GetChildren()) do
            if p:IsA("BasePart") then list[#list + 1] = { label = p.Name, value = p } end
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

-- =====================================================
--  LOGIC: HIỆN VỊ TRÍ (ESP)
-- =====================================================
local espFolder = new("Folder", { Name = "ESP" }, gui)
local espGroups = {
    { key = "espFruits", color = Color3.fromRGB(255, 214, 80), collect = getFruits },
    { key = "espChest", color = Color3.fromRGB(90, 200, 255), collect = getChests },
    { key = "espPlayers", color = Color3.fromRGB(255, 107, 107), collect = getOtherPlayers, highlight = true },
}
for _, g in ipairs(espGroups) do g.tags = {} end

local function clearGroup(g)
    for obj, tag in pairs(g.tags) do
        tag.destroy()
        g.tags[obj] = nil
    end
end

local function createTag(part, color, model)
    local bill = new("BillboardGui", {
        Size = UDim2.new(0, 130, 0, 26), StudsOffset = Vector3.new(0, 2, 0),
        AlwaysOnTop = true, Adornee = part,
    }, espFolder)
    local txt = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = color,
        TextStrokeTransparency = 0.3, TextScaled = true, Font = Enum.Font.GothamBold,
    }, bill)
    local hl
    if model then
        hl = new("Highlight", {
            Adornee = model, FillColor = color, OutlineColor = color, FillTransparency = 0.75,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        }, espFolder)
    end
    return {
        txt = txt,
        destroy = function()
            bill:Destroy()
            if hl then hl:Destroy() end
        end,
    }
end

-- Quét mỗi 0.5s, chỉ tạo nhãn 1 lần cho mỗi đối tượng, tự dọn khi biến mất / ra khỏi tầm
task.spawn(function()
    while running do
        local _, _, root = getChar()
        for _, g in ipairs(espGroups) do
            if config[g.key] and root then
                local seen = {}
                for _, item in ipairs(g.collect()) do
                    local dist = (item.part.Position - root.Position).Magnitude
                    if dist <= config.espRange then
                        seen[item.obj] = true
                        local tag = g.tags[item.obj]
                        if not tag then
                            tag = createTag(item.part, g.color, g.highlight and item.obj)
                            g.tags[item.obj] = tag
                        end
                        tag.txt.Text = string.format("%s [%d]", item.name, math.floor(dist))
                    end
                end
                for obj, tag in pairs(g.tags) do
                    if not seen[obj] then
                        tag.destroy()
                        g.tags[obj] = nil
                    end
                end
            elseif not config[g.key] then
                clearGroup(g)
            end
        end
        task.wait(0.5)
    end
end)

-- =====================================================
--  LOGIC: CÀY QUÁI / SĂN BOSS / ĐÁNH
-- =====================================================
local function isAlive(m)
    if not (m and m.Parent) then return false end
    local hum = m:FindFirstChildOfClass("Humanoid")
    return hum ~= nil
        and hum.Health > 0
        and m:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Đọc cấp quái từ tên dạng "Bandit [Lv. 5]" (nếu game đặt tên như vậy)
local function mobLevel(m)
    local hum = m:FindFirstChildOfClass("Humanoid")
    local s = ((hum and hum.DisplayName) or "") .. " " .. m.Name
    local lv = s:match("%[Lv%.?%s*(%d+)%]")
    return lv and tonumber(lv) or nil
end

local function findNearestEnemy(root)
    -- Quái của Blox Fruits nằm trong workspace.Enemies
    local folder = workspace:FindFirstChild("Enemies")
    if not folder then return nil end

    local hunting = config.huntOnly and config.huntName
    local plv = config.levelFilter and playerNumber("Level") or nil
    local best = nil
    local bestDist = hunting and math.huge or config.farmRange -- săn theo tên thì bỏ giới hạn tầm
    local sawLevel = false

    for _, m in ipairs(folder:GetChildren()) do
        if isAlive(m) and (not hunting or m.Name == hunting) then
            local levelOk = true
            if plv then
                local lv = mobLevel(m)
                if lv then
                    sawLevel = true
                    levelOk = lv >= plv - config.levelBelow and lv <= plv + config.levelAbove
                end
            end
            if levelOk then
                local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
                if d < bestDist then best, bestDist = m, d end
            end
        end
    end

    if config.levelFilter and not levelWarned and (not plv or not sawLevel) then
        levelWarned = true
        notify("Cày hợp cấp",
            plv and "Không đọc được cấp của quái, đang đánh quái gần nhất"
                or "Không đọc được cấp của bạn, đang đánh quái gần nhất",
            5, T.bad, true)
    end
    return best
end

local function equipWeapon(char, hum)
    local held = char:FindFirstChildOfClass("Tool")
    if held and held.ToolTip == config.weaponType then return end
    for _, tool in ipairs(LP.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.ToolTip == config.weaponType then
            hum:EquipTool(tool)
            return
        end
    end
end

connect(RunService.Heartbeat, function()
    if not config.autoFarm then
        target = nil
        return
    end
    if os.clock() < busyUntil then return end -- đang bay tới nơi / đi nhặt trái
    local char, hum, root = getChar()
    if not (char and hum and root) or hum.Health <= 0 then return end

    if not isAlive(target) then
        local now = os.clock()
        if now - lastScan < 0.2 then return end -- không quét mỗi frame
        lastScan = now
        target = findNearestEnemy(root)
        if not target then return end
    end

    local mobCF = target.HumanoidRootPart.CFrame
    local pos = (mobCF * CFrame.new(0, config.farmHeight, config.farmDist)).Position
    local goal = CFrame.lookAt(pos, mobCF.Position)
    if (root.Position - pos).Magnitude > 150 then
        busyUntil = os.clock() + teleportTo(goal) -- ở xa thì bay mượt tới gần
        return
    end
    root.CFrame = goal
    root.AssemblyLinearVelocity = Vector3.zero
end)

task.spawn(function()
    while running do
        local char, hum = getChar()
        if char and hum and hum.Health > 0 then
            local shouldClick = config.autoClick
                or (config.autoFarm and config.farmAttack and isAlive(target))
            if config.autoEquip and (config.autoClick or config.autoFarm) then
                equipWeapon(char, hum)
            end
            if shouldClick then
                pcall(function()
                    VirtualUser:ClickButton1(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end)
            end
        end
        task.wait(1 / math.max(config.clickRate, 1))
    end
end)

-- Tự đi nhặt trái rơi
task.spawn(function()
    while running do
        if config.autoFruit and os.clock() >= busyUntil then
            local _, hum, root = getChar()
            if root and hum and hum.Health > 0 then
                local best = nearestFruit(root)
                if best then
                    local dur = teleportTo(best.part.CFrame)
                    busyUntil = os.clock() + dur + 1.5
                    if firetouchinterest then
                        pcall(function()
                            firetouchinterest(root, best.part, 0)
                            firetouchinterest(root, best.part, 1)
                        end)
                    end
                    notify("Nhặt trái", best.name, 2, T.accent)
                end
            end
        end
        task.wait(1)
    end
end)

-- Báo khi có trái ác quỷ xuất hiện
local knownFruits = {}
task.spawn(function()
    while running do
        if config.fruitAlert then
            local _, _, root = getChar()
            local current = {}
            for _, f in ipairs(getFruits()) do
                current[f.obj] = true
                if not knownFruits[f.obj] then
                    knownFruits[f.obj] = true
                    local detail = f.name
                    if root then
                        detail = detail .. " - cách " .. tostring(math.floor((f.part.Position - root.Position).Magnitude)) .. " đv"
                    end
                    notify("Có trái ác quỷ!", detail, 6, T.accent, true)
                end
            end
            for obj in pairs(knownFruits) do
                if not current[obj] then knownFruits[obj] = nil end
            end
        else
            table.clear(knownFruits)
        end
        task.wait(2)
    end
end)

-- =====================================================
--  LOGIC: TỰ CỘNG ĐIỂM CHỈ SỐ (thử nghiệm)
-- =====================================================
local statWarned = false
task.spawn(function()
    local lastPts, stuck = nil, 0
    while running do
        if config.autoStats then
            local pts = playerNumber("Points")
            if not pts then
                if not statWarned then
                    statWarned = true
                    notify("Cộng điểm", "Không đọc được số điểm còn lại", 5, T.bad, true)
                end
            elseif pts > 0 then
                -- điểm không giảm sau nhiều lần cộng => lệnh có thể đã sai / game đã đổi
                if pts == lastPts then stuck = stuck + 1 else stuck = 0 end
                lastPts = pts
                if stuck >= 3 and not statWarned then
                    statWarned = true
                    notify("Cộng điểm", "Điểm không giảm sau 3 lần thử, game có thể đã đổi lệnh", 6, T.bad, true)
                end
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local remote = remotes and remotes:FindFirstChild("CommF_")
                if remote then
                    pcall(function()
                        remote:InvokeServer("AddPoint", config.statType, math.min(pts, config.statStep))
                    end)
                elseif not statWarned then
                    statWarned = true
                    notify("Cộng điểm", "Không tìm thấy lệnh cộng điểm của game", 5, T.bad, true)
                end
            end
        else
            lastPts, stuck = nil, 0
        end
        task.wait(2)
    end
end)

-- =====================================================
--  LOGIC: NHÂN VẬT (chạy nhanh, xuyên tường, bay, nhảy vô hạn, chống AFK)
-- =====================================================
connect(RunService.Heartbeat, function()
    if not config.speedBoost then return end
    local _, hum = getChar()
    if not hum then return end
    if not hum.UseJumpPower then hum.UseJumpPower = true end
    if hum.WalkSpeed ~= config.walkSpeed then hum.WalkSpeed = config.walkSpeed end
    if hum.JumpPower ~= config.jumpPower then hum.JumpPower = config.jumpPower end
end)

connect(RunService.Stepped, function()
    if not config.noclip then return end
    local char = LP.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            noclipped[part] = true
            part.CanCollide = false
        end
    end
end)

connect(UIS.JumpRequest, function()
    if not config.infJump then return end
    local _, hum = getChar()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local function stopFly()
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local _, hum = getChar()
    if hum then hum.PlatformStand = false end
end

connect(RunService.RenderStepped, function()
    if not config.fly then return end
    local _, hum, root = getChar()
    if not (hum and root) then return end
    if not flyBV or flyBV.Parent ~= root then -- tạo lại sau khi hồi sinh
        if flyBV then flyBV:Destroy() end
        if flyBG then flyBG:Destroy() end
        flyBV = new("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero }, root)
        flyBG = new("BodyGyro", { MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 9e4 }, root)
    end
    hum.PlatformStand = true
    local cam = workspace.CurrentCamera.CFrame
    local move = cam:VectorToObjectSpace(hum.MoveDirection)
    flyBV.Velocity = (cam.LookVector * -move.Z + cam.RightVector * move.X) * config.flySpeed
    flyBG.CFrame = cam
end)

connect(LP.Idled, function()
    if not config.antiAfk then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

local function applyFullbright(on)
    if on then
        lightOrig = lightOrig or {
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
    elseif lightOrig then
        for k, v in pairs(lightOrig) do Lighting[k] = v end
        lightOrig = nil
    end
end

connect(RunService.Heartbeat, function()
    if not config.fullbright then return end
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1e9
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
end)

-- =====================================================
--  LOGIC: MÁY CHỦ
-- =====================================================
local function serverHop()
    notify("Đổi server", "Đang tìm server còn chỗ...", 3)
    task.spawn(function()
        local ok, found = pcall(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
            local data = HttpService:JSONDecode(game:HttpGet(url))
            for _, s in ipairs(data.data or {}) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers - 1 then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                    return true
                end
            end
            return false
        end)
        if not ok or not found then
            notify("Đổi server", "Không tìm được server phù hợp", 4, T.bad)
        end
    end)
end

local function rejoin()
    notify("Vào lại server", "Đang vào lại server này...", 3)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
    if not ok then TeleportService:Teleport(game.PlaceId, LP) end
end

-- =====================================================
--  TAB: CÀY
-- =====================================================
local pFarm = addTab("Cày", "⚔️", 1)
section(pFarm, "Cày quái tự động")
toggle(pFarm, "Tự cày quái gần nhất", "autoFarm", function(on) if not on then target = nil end end)
toggle(pFarm, "Tự đánh khi đang cày", "farmAttack")
toggle(pFarm, "Tự bấm đánh liên tục", "autoClick")

section(pFarm, "Cày theo cấp (thử nghiệm)")
toggle(pFarm, "Chỉ đánh quái hợp cấp", "levelFilter", function() levelWarned = false end)
slider(pFarm, "Thấp hơn cấp mình tối đa", "levelBelow", 0, 300, 5, nil, " cấp")
slider(pFarm, "Cao hơn cấp mình tối đa", "levelAbove", 0, 100, 5, nil, " cấp")

section(pFarm, "Săn boss / quái theo tên")
local function getEnemyNames()
    local list, seen = {}, {}
    local folder = workspace:FindFirstChild("Enemies")
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if isAlive(m) and not seen[m.Name] then
                seen[m.Name] = true
                list[#list + 1] = { label = m.Name, value = m.Name }
            end
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end
local enemyPicker = listPicker(pFarm, getEnemyNames, "Chưa có quái nào xuất hiện", function(item)
    config.huntName = item and item.value or nil
end)
button(pFarm, "Làm mới danh sách quái", function() enemyPicker.refresh() end, true)
toggle(pFarm, "Chỉ đánh mục tiêu đã chọn", "huntOnly", function() target = nil end)

section(pFarm, "Vũ khí")
toggle(pFarm, "Tự cầm vũ khí", "autoEquip")
choice(pFarm, "Loại vũ khí", "weaponType", {
    { "Võ", "Melee" }, { "Kiếm", "Sword" }, { "Súng", "Gun" }, { "Trái", "Blox Fruit" },
})

section(pFarm, "Tuỳ chỉnh")
slider(pFarm, "Tầm tìm quái", "farmRange", 50, 1000, 10, nil, " đv")
slider(pFarm, "Khoảng cách tới quái", "farmDist", 1, 15, 1, nil, " đv")
slider(pFarm, "Độ cao so với quái", "farmHeight", 0, 25, 1, nil, " đv")
slider(pFarm, "Tốc độ bấm đánh", "clickRate", 1, 30, 1, nil, " lần/giây")

section(pFarm, "Trái ác quỷ")
toggle(pFarm, "Tự đi nhặt trái rơi", "autoFruit")
toggle(pFarm, "Báo khi có trái xuất hiện", "fruitAlert")

-- =====================================================
--  TAB: CHỈ SỐ
-- =====================================================
local pStats = addTab("Chỉ số", "📊", 2)
section(pStats, "Tự cộng điểm (thử nghiệm)")
toggle(pStats, "Tự cộng điểm chỉ số", "autoStats", function() statWarned = false end)
choice(pStats, "Cộng vào (Thủ = phòng thủ)", "statType", {
    { "Võ", "Melee" }, { "Thủ", "Defense" }, { "Kiếm", "Sword" },
    { "Súng", "Gun" }, { "Trái", "Demon Fruit" },
})
slider(pStats, "Số điểm cộng mỗi lần", "statStep", 1, 50, 1, nil, " điểm")
local infoPoints = infoRow(pStats, "Điểm còn lại")

-- =====================================================
--  TAB: NHÂN VẬT
-- =====================================================
local pPlayer = addTab("Nhân vật", "🧍", 3)
section(pPlayer, "Tốc độ")
toggle(pPlayer, "Bật chạy nhanh + nhảy cao", "speedBoost", function(on)
    local _, hum = getChar()
    if not hum then return end
    if on then
        orig.walk, orig.jump = hum.WalkSpeed, hum.JumpPower
    else
        hum.WalkSpeed = orig.walk
        hum.JumpPower = orig.jump
    end
end)
slider(pPlayer, "Tốc độ chạy", "walkSpeed", 16, 200, 2)
slider(pPlayer, "Sức nhảy", "jumpPower", 50, 300, 5)

section(pPlayer, "Di chuyển")
toggle(pPlayer, "Xuyên tường", "noclip", function(on)
    if not on then
        for part in pairs(noclipped) do
            if part and part.Parent then part.CanCollide = true end
        end
        table.clear(noclipped)
    end
end)
toggle(pPlayer, "Nhảy vô hạn", "infJump")
toggle(pPlayer, "Bay", "fly", function(on) if not on then stopFly() end end)
slider(pPlayer, "Tốc độ bay", "flySpeed", 20, 200, 5)

section(pPlayer, "Khác")
toggle(pPlayer, "Chống bị đá vì đứng yên", "antiAfk")
button(pPlayer, "Hồi sinh lại (reset nhân vật)", function()
    local _, hum = getChar()
    if hum then hum.Health = 0 end
end, true)

-- =====================================================
--  TAB: HIỂN THỊ
-- =====================================================
local pVisual = addTab("Hiển thị", "👁", 4)
section(pVisual, "Hiện vị trí trên màn hình")
for _, spec in ipairs({
    { "Hiện vị trí trái ác quỷ", 1 },
    { "Hiện vị trí rương", 2 },
    { "Hiện vị trí người chơi", 3 },
}) do
    local g = espGroups[spec[2]]
    toggle(pVisual, spec[1], g.key, function(on) if not on then clearGroup(g) end end)
end
slider(pVisual, "Tầm hiển thị", "espRange", 100, 2000, 50, nil, " đv")
section(pVisual, "Môi trường")
toggle(pVisual, "Sáng toàn map, bỏ sương mù", "fullbright", applyFullbright)

-- =====================================================
--  TAB: DỊCH CHUYỂN
-- =====================================================
local pTele = addTab("Dịch chuyển", "🧭", 5)

section(pTele, "Đến đảo (thử nghiệm)")
local islandPicker = listPicker(pTele, getIslands, "Chưa đọc được danh sách đảo")
button(pTele, "Đến đảo đã chọn", function()
    local item = islandPicker.current()
    if item and item.value.Parent then
        teleportTo(item.value.CFrame + Vector3.new(0, 25, 0))
        notify("Dịch chuyển", "Đang đến " .. item.label, 2, T.accent)
    else
        notify("Dịch chuyển", "Chưa có đảo nào để đến", 3, T.bad)
    end
end)
button(pTele, "Làm mới danh sách đảo", function() islandPicker.refresh() end, true)

section(pTele, "Điểm đã lưu")
local wpPicker = listPicker(pTele, function() return waypoints end, "Chưa lưu điểm nào")
button(pTele, "Lưu vị trí hiện tại", function()
    local _, _, root = getChar()
    if not root then return end
    wpCounter = wpCounter + 1
    waypoints[#waypoints + 1] = { label = "Điểm " .. tostring(wpCounter), value = root.CFrame }
    wpPicker.index = #waypoints
    wpPicker.refresh()
    notify("Đã lưu vị trí", waypoints[#waypoints].label, 2, T.good)
end)
button(pTele, "Đến điểm đã chọn", function()
    local item = wpPicker.current()
    if item then
        teleportTo(item.value)
        notify("Dịch chuyển", "Đang đến " .. item.label, 2, T.accent)
    else
        notify("Dịch chuyển", "Chưa lưu điểm nào", 3, T.bad)
    end
end, true)
button(pTele, "Xoá điểm đã chọn", function()
    local item = wpPicker.current()
    if item then
        table.remove(waypoints, wpPicker.index)
        wpPicker.refresh()
    end
end, true)

section(pTele, "Đến người chơi")
local playerPicker = listPicker(pTele, function()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then list[#list + 1] = { label = p.DisplayName, value = p } end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end, "Chưa có người chơi khác")
connect(Players.PlayerAdded, function() playerPicker.refresh() end)
connect(Players.PlayerRemoving, function() task.defer(playerPicker.refresh) end)
button(pTele, "Đến chỗ người này", function()
    local item = playerPicker.current()
    local p = item and item.value
    local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        teleportTo(hrp.CFrame * CFrame.new(0, 0, 4))
        notify("Dịch chuyển", "Đang đến " .. item.label, 2, T.accent)
    else
        notify("Dịch chuyển", "Người này chưa có nhân vật", 2, T.bad)
    end
end)

section(pTele, "Địa điểm khác")
button(pTele, "Đến trái ác quỷ gần nhất", function()
    local _, _, root = getChar()
    local f = root and nearestFruit(root)
    if f then
        teleportTo(f.part.CFrame)
        notify("Dịch chuyển", "Đang đến " .. f.name, 2, T.accent)
    else
        notify("Dịch chuyển", "Không có trái nào trên map", 2, T.bad)
    end
end, true)
button(pTele, "Về điểm hồi sinh", function()
    local cf = getSpawnCF()
    if cf then
        teleportTo(cf)
    else
        notify("Dịch chuyển", "Chưa biết điểm hồi sinh", 2, T.bad)
    end
end, true)

section(pTele, "Cách di chuyển")
toggle(pTele, "Dịch chuyển mượt (bay tới nơi)", "smoothTp")
slider(pTele, "Tốc độ dịch chuyển mượt", "tpSpeed", 50, 600, 10, nil, " đv/giây")

section(pTele, "Máy chủ")
button(pTele, "Đổi server", serverHop, true)
button(pTele, "Vào lại server này", rejoin, true)

-- =====================================================
--  TAB: THÔNG TIN
-- =====================================================
local pInfo = addTab("Thông tin", "ℹ️", 6)
section(pInfo, "Trạng thái")
local infoFPS = infoRow(pInfo, "Khung hình/giây (FPS)")
local infoPing = infoRow(pInfo, "Độ trễ (ping)")
local infoPlayers = infoRow(pInfo, "Người chơi trong server")
local infoUptime = infoRow(pInfo, "Thời gian server")
local infoLevel = infoRow(pInfo, "Cấp độ")
local infoBeli = infoRow(pInfo, "Beli")
local infoFrag = infoRow(pInfo, "Mảnh vỡ")
local infoTarget = infoRow(pInfo, "Mục tiêu đang đánh")
section(pInfo, "Cài đặt")
toggle(pInfo, "Hiện thông báo", "notify")
button(pInfo, "Ẩn menu (mở lại bằng nút 🍇)", function() main.Visible = false end, true)
button(pInfo, "Gỡ script", function() unload() end, true)

local function commas(v)
    local out = tostring(v):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return out
end

local function playerStat(name)
    local v = playerNumber(name)
    return v and commas(v) or "—"
end

local frames, lastT = 0, os.clock()
connect(RunService.RenderStepped, function() frames = frames + 1 end)
task.spawn(function()
    while running do
        local now = os.clock()
        infoFPS.Text = tostring(math.floor(frames / math.max(now - lastT, 0.001)))
        frames, lastT = 0, now

        local okP, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        infoPing.Text = okP and (tostring(math.floor(ping)) .. " ms") or "—"
        infoPlayers.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)

        local t = workspace.DistributedGameTime
        infoUptime.Text = string.format("%02d:%02d", math.floor(t / 60), math.floor(t % 60))
        infoLevel.Text = playerStat("Level")
        infoBeli.Text = playerStat("Beli")
        infoFrag.Text = playerStat("Fragments")
        infoPoints.Text = playerStat("Points")
        infoTarget.Text = (config.autoFarm and isAlive(target)) and target.Name or "—"
        task.wait(0.5)
    end
end)

selectTab("Cày")

-- =====================================================
--  GỠ SCRIPT
-- =====================================================
unload = function()
    running = false
    target = nil
    stopFly()

    local _, hum = getChar()
    if hum and config.speedBoost then
        hum.WalkSpeed = orig.walk
        hum.JumpPower = orig.jump
    end
    for part in pairs(noclipped) do
        if part and part.Parent then part.CanCollide = true end
    end
    table.clear(noclipped)
    applyFullbright(false)
    for _, g in ipairs(espGroups) do clearGroup(g) end
    if currentTween then currentTween:Cancel() end

    for _, c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
    gui:Destroy()
    if env.BF_Unload == unload then env.BF_Unload = nil end
end
env.BF_Unload = unload

notify("Vanh Hub", "Đã tải xong. Chạm 🍇 để ẩn/hiện menu.", 3, T.good)
print("✅ Vanh Hub loaded!")
