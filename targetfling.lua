local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Mouse = player:GetMouse()

-- ════════════════════════════════════════════════
-- TARGET LIST
-- ════════════════════════════════════════════════

local TARGET_USERNAMES = {
    "8trundrr"}

-- ════════════════════════════════════════════════
-- CONFIG
-- ════════════════════════════════════════════════

local CONFIG = {
    FLING_FORCE = 9999,
    FLING_SPIN = 100,
    FLING_DURATION = 1.2,
    AUTO_FLING_ON_JOIN = true,
    AUTO_FLING_DELAY = 3,
    RE_FLING_ON_RESPAWN = true,
    RESPAWN_DELAY = 2,
    HIGHLIGHT_TARGETS = true,
    ALERT_SOUND = true,
    ALERT_SOUND_ID = "rbxassetid://9125402735",
    NOTIFICATION_DURATION = 6,
}

-- ════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════

local targetLookup = {}
local activeTarget = nil
local highlights = {}
local trackedPlayers = {}
local flinging = false

for _, name in ipairs(TARGET_USERNAMES) do
    targetLookup[name:lower()] = name
end

-- ════════════════════════════════════════════════
-- UTILITY
-- ════════════════════════════════════════════════

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = CONFIG.NOTIFICATION_DURATION,
        })
    end)
end

local function alertSound()
    if not CONFIG.ALERT_SOUND then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = CONFIG.ALERT_SOUND_ID
        s.Volume = 0.8
        s.Parent = workspace
        s:Play()
        task.delay(3, function() pcall(function() s:Destroy() end) end)
    end)
end

local function isTarget(p)
    if not p or p == player then return false end
    return targetLookup[p.Name:lower()] ~= nil or targetLookup[p.DisplayName:lower()] ~= nil
end

local function getMatchedName(p)
    return targetLookup[p.Name:lower()] or targetLookup[p.DisplayName:lower()] or p.Name
end

local function applyHighlight(p, char)
    if not CONFIG.HIGHLIGHT_TARGETS or not char then return end
    pcall(function()
        if highlights[p] then highlights[p]:Destroy() end
        local h = Instance.new("Highlight")
        h.Adornee = char
        h.FillColor = Color3.fromRGB(255, 0, 0)
        h.FillTransparency = 0.7
        h.OutlineColor = Color3.fromRGB(255, 40, 40)
        h.OutlineTransparency = 0
        h.Parent = char
        highlights[p] = h
    end)
end

local function removeHighlight(p)
    pcall(function()
        if highlights[p] then highlights[p]:Destroy() highlights[p] = nil end
    end)
end

-- ════════════════════════════════════════════════
-- FLING ENGINE — TAKES OVER YOUR CHARACTER PHYSICS
-- ════════════════════════════════════════════════

local function flingTarget(targetPlayer)
    if flinging then return end
    if not targetPlayer or not targetPlayer.Character then return end

    local targetChar = targetPlayer.Character
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local myChar = player.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar:FindFirstChildOfClass("Humanoid")
    if not myHRP or not myHum then return end

    flinging = true
    local matchedName = getMatchedName(targetPlayer)
    notify("FLINGING", matchedName)

    -- save original state
    local originalWalkSpeed = myHum.WalkSpeed
    local originalJumpPower = myHum.JumpPower

    -- disable humanoid control so physics takes over
    myHum.WalkSpeed = 0
    myHum.JumpPower = 0

    -- make character parts massless for faster acceleration
    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
        end
    end

    -- spin body — angular velocity creates the fling force on contact
    local angVel = Instance.new("BodyAngularVelocity")
    angVel.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    angVel.AngularVelocity = Vector3.new(
        math.random(-CONFIG.FLING_SPIN, CONFIG.FLING_SPIN),
        math.random(-CONFIG.FLING_SPIN, CONFIG.FLING_SPIN),
        math.random(-CONFIG.FLING_SPIN, CONFIG.FLING_SPIN)
    )
    angVel.Parent = myHRP

    -- velocity — drives your character into the target
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVel.Velocity = Vector3.new(0, 0, 0)
    bodyVel.Parent = myHRP

    -- tracking loop — chase the target's position
    local conn
    local elapsed = 0

    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt

        if elapsed >= CONFIG.FLING_DURATION then
            conn:Disconnect()

            -- cleanup physics
            pcall(function() angVel:Destroy() end)
            pcall(function() bodyVel:Destroy() end)

            -- restore character
            pcall(function()
                myHum.WalkSpeed = originalWalkSpeed
                myHum.JumpPower = originalJumpPower
                for _, part in ipairs(myChar:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
                    end
                end
            end)

            flinging = false
            notify("FLING COMPLETE", matchedName)
            return
        end

        -- update target position
        pcall(function()
            if targetHRP and targetHRP.Parent then
                local dir = (targetHRP.Position - myHRP.Position).Unit
                bodyVel.Velocity = dir * CONFIG.FLING_FORCE
                myHRP.CFrame = CFrame.new(targetHRP.Position) * CFrame.new(0, 0, -2)
            end
        end)
    end)
end

-- ════════════════════════════════════════════════
-- TARGET ENGAGEMENT
-- ════════════════════════════════════════════════

local function engageTarget(p)
    local matchedName = getMatchedName(p)
    activeTarget = p

    if p.Character then
        applyHighlight(p, p.Character)
    end

    alertSound()
    notify("TARGET DETECTED", matchedName .. " joined")
    print("[Target] DETECTED: " .. matchedName)

    -- auto fling on join
    if CONFIG.AUTO_FLING_ON_JOIN then
        task.spawn(function()
            task.wait(CONFIG.AUTO_FLING_DELAY)
            if p and p.Parent and p.Character then
                flingTarget(p)
            end
        end)
    end

    -- re-engage on respawn
    if CONFIG.RE_FLING_ON_RESPAWN and not trackedPlayers[p] then
        trackedPlayers[p] = true
        pcall(function()
            p.CharacterAdded:Connect(function(char)
                task.wait(CONFIG.RESPAWN_DELAY)
                if p and p.Parent then
                    applyHighlight(p, char)
                    if CONFIG.AUTO_FLING_ON_JOIN then
                        task.wait(1.5)
                        if p and p.Parent and p.Character and not flinging then
                            flingTarget(p)
                            notify("RE-FLING", matchedName .. " respawned")
                        end
                    end
                end
            end)
        end)
    end
end

local function onTargetLeft(p)
    if isTarget(p) then
        notify("TARGET LEFT", getMatchedName(p) .. " left")
        removeHighlight(p)
        trackedPlayers[p] = nil
        if activeTarget == p then activeTarget = nil end
    end
end

-- ════════════════════════════════════════════════
-- SCAN + LISTEN
-- ════════════════════════════════════════════════

for _, p in ipairs(Players:GetPlayers()) do
    if isTarget(p) then engageTarget(p) end
end

Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    if isTarget(p) then engageTarget(p) end
end)

Players.PlayerRemoving:Connect(onTargetLeft)

-- ════════════════════════════════════════════════
-- MANUAL CONTROLS
-- ════════════════════════════════════════════════

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- right click = manual lock
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        local target = Mouse.Target
        if target then
            local char = target:FindFirstAncestorWhichIsA("Model")
            if char then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == char and p ~= player then
                        activeTarget = p
                        applyHighlight(p, char)
                        notify("LOCKED", p.Name)
                        break
                    end
                end
            end
        end
    end

    -- F = manual fling on locked target
    if input.KeyCode == Enum.KeyCode.F then
        if activeTarget and activeTarget.Character and not flinging then
            flingTarget(activeTarget)
        else
            if flinging then
                notify("BUSY", "Already flinging")
            else
                notify("NO TARGET", "Right click someone first")
            end
        end
    end
end)

-- ════════════════════════════════════════════════
-- RUNTIME COMMANDS
-- ════════════════════════════════════════════════

getgenv().addTarget = function(name)
    table.insert(TARGET_USERNAMES, name)
    targetLookup[name:lower()] = name
    print("[Target] Added: " .. name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == name:lower() or p.DisplayName:lower() == name:lower() then
            engageTarget(p)
        end
    end
end

getgenv().removeTarget = function(name)
    targetLookup[name:lower()] = nil
    for i, v in ipairs(TARGET_USERNAMES) do
        if v:lower() == name:lower() then table.remove(TARGET_USERNAMES, i) break end
    end
    print("[Target] Removed: " .. name)
end

getgenv().targets = function()
    for i, name in ipairs(TARGET_USERNAMES) do
        local status = "offline"
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == name:lower() then status = "IN SERVER" break end
        end
        print(i .. ". " .. name .. " [" .. status .. "]")
    end
end

getgenv().toggleAutoFling = function()
    CONFIG.AUTO_FLING_ON_JOIN = not CONFIG.AUTO_FLING_ON_JOIN
    print("[Target] Auto-fling: " .. (CONFIG.AUTO_FLING_ON_JOIN and "ON" or "OFF"))
end

notify("TARGET FLING", #TARGET_USERNAMES .. " targets | Auto-fling ON")
print("[Target Fling] " .. #TARGET_USERNAMES .. " targets loaded")
print("[Target Fling] F = manual fling | Right Click = lock | Auto-fling ON")
print("[Target Fling] Commands: addTarget('name') | removeTarget('name') | targets() | toggleAutoFling()")
