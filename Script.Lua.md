-- Dex++ Hub - Solara Compatible Version
-- NO _G dependence, NO require() on game modules, pure workspace scanning

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==================== LOAD OBSIDIAN UI ====================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- ==================== CREATE WINDOW ====================
local Window = Library:CreateWindow({
    Title = "Dex++ Hub [Solara]",
    Footer = "Fly + ESP + Kill Aura",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local MainTab = Window:AddTab("Main", "plane")
local ESPTab = Window:AddTab("Zombie ESP", "skull")
local KillAuraTab = Window:AddTab("Kill Aura", "swords")
local SettingsTab = Window:AddTab("UI Settings", "settings")

-- ==================== MAIN TAB - FLY ====================
local FlyBox = MainTab:AddLeftGroupbox("Fly Controls")

local Flying = false
local FlySpeed = 50
local FlyConnection = nil
local BodyGyro = nil
local BodyVelocity = nil
local NoclipConnection = nil

local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local ControlModule = PlayerModule:GetControls()

FlyBox:AddToggle("FlyToggle", {
    Text = "Enable Fly",
    Default = false,
    Callback = function(Value)
        Flying = Value
        if Flying then StartFly() else StopFly() end
    end,
})

FlyBox:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = 50, Min = 10, Max = 200, Rounding = 0,
    Callback = function(Value) FlySpeed = Value end,
})

FlyBox:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
    Callback = function(Value)
        if Value then
            NoclipConnection = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
        else
            if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end,
})

function StartFly()
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    
    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.P = 9e4
    BodyGyro.MaxTorque = Vector3.new(9e9, 0, 9e9)
    BodyGyro.CFrame = HumanoidRootPart.CFrame
    BodyGyro.Parent = HumanoidRootPart
    
    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BodyVelocity.Parent = HumanoidRootPart
    
    Humanoid.PlatformStand = true
    
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not Flying then return end
        local camCF = Camera.CFrame
        local camLook = camCF.LookVector
        local camRight = camCF.RightVector
        local moveVec = ControlModule:GetMoveVector()
        local moveDir = (camLook * -moveVec.Z) + (camRight * moveVec.X)
        if moveDir.Magnitude > 0.01 then moveDir = moveDir.Unit * FlySpeed else moveDir = Vector3.new(0,0,0) end
        if BodyVelocity then BodyVelocity.Velocity = moveDir end
        if BodyGyro then
            local yaw = math.atan2(camLook.X, camLook.Z)
            BodyGyro.CFrame = CFrame.Angles(0, yaw, 0)
        end
    end)
    Library:Notify("Fly Enabled!", 3)
end

function StopFly()
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end
    if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    Library:Notify("Fly Disabled", 2)
end

-- ==================== ESP TAB ====================
local ESPBox = ESPTab:AddLeftGroupbox("Zombie ESP")

local ZombieESP = {
    Enabled = false, ShowName = true, ShowHealth = true, ShowDistance = true,
    MaxDistance = 1000, TextSize = 14,
    Color = Color3.fromRGB(255, 0, 0),
    Zombies = {}, Folder = nil,
}

ZombieESP.Folder = Instance.new("Folder")
ZombieESP.Folder.Name = "ZombieESP"
ZombieESP.Folder.Parent = CoreGui

local function RemoveZombieESP(zombieModel)
    local esp = ZombieESP.Zombies[zombieModel]
    if not esp then return end
    if esp.Billboard then esp.Billboard:Destroy() end
    if esp.Highlight then esp.Highlight:Destroy() end
    ZombieESP.Zombies[zombieModel] = nil
end

local function CreateZombieESP(zombieModel)
    if ZombieESP.Zombies[zombieModel] then return end
    local head = zombieModel:FindFirstChild("Head") or zombieModel:FindFirstChildWhichIsA("BasePart")
    local humanoid = zombieModel:FindFirstChildOfClass("Humanoid")
    if not head then return end
    
    local esp = {}
    esp.Head = head  -- CRITICAL FIX: Store reference
    esp.Humanoid = humanoid
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ZESP"
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = head
    billboard.Parent = ZombieESP.Folder
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = ZombieESP.Color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0,0,0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = ZombieESP.TextSize
    nameLabel.Text = zombieModel.Name
    nameLabel.Parent = billboard
    
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Size = UDim2.new(1, 0, 0, 20)
    healthLabel.Position = UDim2.new(0, 0, 0, 20)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    healthLabel.TextStrokeTransparency = 0
    healthLabel.TextStrokeColor3 = Color3.new(0,0,0)
    healthLabel.Font = Enum.Font.GothamBold
    healthLabel.TextSize = ZombieESP.TextSize - 2
    healthLabel.Text = humanoid and tostring(math.floor(humanoid.Health)).."/"..tostring(math.floor(humanoid.MaxHealth)) or "???"
    healthLabel.Parent = billboard
    
    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0, 20)
    distLabel.Position = UDim2.new(0, 0, 0, 40)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0,0,0)
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextSize = ZombieESP.TextSize - 2
    distLabel.Text = "0m"
    distLabel.Parent = billboard
    
    esp.Billboard = billboard
    esp.NameLabel = nameLabel
    esp.HealthLabel = healthLabel
    esp.DistLabel = distLabel
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = ZombieESP.Color
    highlight.OutlineColor = Color3.new(1,1,1)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = zombieModel
    highlight.Parent = ZombieESP.Folder
    esp.Highlight = highlight
    
    ZombieESP.Zombies[zombieModel] = esp
    
    zombieModel.AncestryChanged:Connect(function(_, parent)
        if parent == nil then RemoveZombieESP(zombieModel) end
    end)
    
    if humanoid then
        humanoid.HealthChanged:Connect(function(health)
            if ZombieESP.Zombies[zombieModel] and ZombieESP.Zombies[zombieModel].HealthLabel then
                local pct = health / humanoid.MaxHealth
                ZombieESP.Zombies[zombieModel].HealthLabel.Text = tostring(math.floor(health)).."/"..tostring(math.floor(humanoid.MaxHealth))
                ZombieESP.Zombies[zombieModel].HealthLabel.TextColor3 = pct > 0.5 and Color3.fromRGB(0,255,0) or (pct > 0.25 and Color3.fromRGB(255,255,0) or Color3.fromRGB(255,0,0))
            end
        end)
        humanoid.Died:Connect(function() RemoveZombieESP(zombieModel) end)
    end
end

local function ScanZombies()
    local zombiesFolder = Workspace:FindFirstChild("Zombies_Local")
    if not zombiesFolder then return end
    for _, zombie in pairs(zombiesFolder:GetChildren()) do
        if zombie:IsA("Model") then CreateZombieESP(zombie) end
    end
end

local function UpdateESP()
    if not ZombieESP.Enabled then
        for _, esp in pairs(ZombieESP.Zombies) do
            if esp.Billboard then esp.Billboard.Enabled = false end
            if esp.Highlight then esp.Highlight.Enabled = false end
        end
        return
    end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    for zombieModel, esp in pairs(ZombieESP.Zombies) do
        if not zombieModel.Parent then RemoveZombieESP(zombieModel) continue end
        
        local head = esp.Head  -- Use stored reference, don't re-lookup
        if not head or not head.Parent then RemoveZombieESP(zombieModel) continue end
        
        local distance = hrp and (hrp.Position - head.Position).Magnitude or 0
        if distance > ZombieESP.MaxDistance then
            if esp.Billboard then esp.Billboard.Enabled = false end
            if esp.Highlight then esp.Highlight.Enabled = false end
            continue
        end
        
        if esp.Billboard then
            esp.Billboard.Enabled = true
            esp.NameLabel.Visible = ZombieESP.ShowName
            esp.NameLabel.Text = zombieModel.Name
            esp.HealthLabel.Visible = ZombieESP.ShowHealth and esp.Humanoid ~= nil
            if ZombieESP.ShowDistance then
                esp.DistLabel.Text = tostring(math.floor(distance)).."m"
                esp.DistLabel.Visible = true
            else
                esp.DistLabel.Visible = false
            end
        end
        if esp.Highlight then esp.Highlight.Enabled = true end
    end
end

ESPBox:AddToggle("ESPEnable", {
    Text = "Enable Zombie ESP", Default = false,
    Callback = function(Value)
        ZombieESP.Enabled = Value
        if Value then ScanZombies() end
    end,
})

ESPBox:AddToggle("ESPName", {Text = "Show Name", Default = true, Callback = function(v) ZombieESP.ShowName = v end})
ESPBox:AddToggle("ESPHealth", {Text = "Show Health", Default = true, Callback = function(v) ZombieESP.ShowHealth = v end})
ESPBox:AddToggle("ESPDistance", {Text = "Show Distance", Default = true, Callback = function(v) ZombieESP.ShowDistance = v end})

ESPBox:AddSlider("ESPMaxDist", {
    Text = "Max Distance", Default = 1000, Min = 100, Max = 5000, Rounding = 0,
    Callback = function(Value) ZombieESP.MaxDistance = Value end,
})

ESPBox:AddSlider("ESPTextSize", {
    Text = "Text Size", Default = 14, Min = 8, Max = 24, Rounding = 0,
    Callback = function(Value)
        ZombieESP.TextSize = Value
        for _, esp in pairs(ZombieESP.Zombies) do
            if esp.NameLabel then esp.NameLabel.TextSize = Value end
            if esp.HealthLabel then esp.HealthLabel.TextSize = Value - 2 end
            if esp.DistLabel then esp.DistLabel.TextSize = Value - 2 end
        end
    end,
})

ESPBox:AddLabel("ESP Color"):AddColorPicker("ESPColor", {
    Default = Color3.fromRGB(255, 0, 0), Title = "Color", Transparency = 0,
    Callback = function(Value) ZombieESP.Color = Value end,
})

-- ==================== KILL AURA TAB ====================
local KABox = KillAuraTab:AddLeftGroupbox("Kill Aura")

local KAConfig = {
    Enabled = false,
    Range = 50,
    FireRate = 0.05,  -- Faster for Solara
    MaxRemotesPerFire = 8,
    HighlightTarget = true,
    Keybind = Enum.KeyCode.K,
}

local KAState = {
    Connection = nil,
    LastFireTime = 0,
    CurrentTarget = nil,
    TargetHighlight = nil,
    GunRemotes = nil,
    EquippedGunName = nil,
    LastRemoteCount = 0,
    TotalDamageDealt = 0,
    DebugMode = true,
}

local KACachedZombies = {}
local KALastScan = 0
local KAScanInterval = 0.03  -- Faster updates

-- ==================== FIND REMOTES (Solara-safe) ====================
local function KAFindRemotes()
    -- Direct ReplicatedStorage lookup only - no _G, no require()
    local gunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
    if gunRemotes then
        KAState.GunRemotes = {
            Fire = gunRemotes:FindFirstChild("GunFire"),
            Hit = gunRemotes:FindFirstChild("GunHit"),
            Reload = gunRemotes:FindFirstChild("GunReload"),
        }
        if KAState.DebugMode then
            print("[KA] Found GunRemotes in ReplicatedStorage")
            print("  Fire:", KAState.GunRemotes.Fire ~= nil)
            print("  Hit:", KAState.GunRemotes.Hit ~= nil)
        end
        return true
    end
    
    -- Try alternative names
    local altNames = {"GunRemotes", "WeaponRemotes", "FirearmRemotes", "Remotes", "EventFolder"}
    for _, name in ipairs(altNames) do
        local folder = ReplicatedStorage:FindFirstChild(name)
        if folder then
            KAState.GunRemotes = {
                Fire = folder:FindFirstChild("GunFire") or folder:FindFirstChild("Fire"),
                Hit = folder:FindFirstChild("GunHit") or folder:FindFirstChild("Hit") or folder:FindFirstChild("Damage"),
            }
            if KAState.GunRemotes.Hit then
                if KAState.DebugMode then print("[KA] Found remotes in", name) end
                return true
            end
        end
    end
    
    -- Last resort: scan all descendants of ReplicatedStorage
    if KAState.DebugMode then print("[KA] Scanning ReplicatedStorage for remotes...") end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("hit") or name:find("damage") or name:find("fire") then
                if KAState.DebugMode then print("[KA] Found potential remote:", obj:GetFullName()) end
            end
        end
    end
    
    return false
end

-- ==================== FAST ZOMBIE SCANNING ====================
local function KAScanZombiesFast()
    local now = tick()
    if now - KALastScan < KAScanInterval then return KACachedZombies end
    KALastScan = now
    
    local zombies = {}
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position
    
    -- ONLY workspace scanning - no _G.ZombieClient dependency
    local folder = Workspace:FindFirstChild("Zombies_Local")
    if folder then
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") then
                local pos = nil
                local hrp = model:FindFirstChild("HumanoidRootPart")
                local head = model:FindFirstChild("Head")
                
                if hrp then pos = hrp.Position 
                elseif head then pos = head.Position
                else
                    local part = model:FindFirstChildWhichIsA("BasePart")
                    if part then pos = part.Position end
                end
                
                if pos then
                    local dist = myPos and (pos - myPos).Magnitude or math.huge
                    local id = tonumber(model.Name:match("%d+")) or model.Name
                    
                    table.insert(zombies, {
                        Id = id,
                        Model = model,
                        Position = pos,
                        Distance = dist,
                        Tier = "Unknown",
                        Source = "Workspace"
                    })
                end
            end
        end
    end
    
    -- Fallback: scan all workspace for models with Humanoid (broader)
    if #zombies == 0 then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= LocalPlayer.Character then
                local humanoid = model:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local hrp = model:FindFirstChild("HumanoidRootPart")
                    local head = model:FindFirstChild("Head")
                    local pos = nil
                    if hrp then pos = hrp.Position
                    elseif head then pos = head.Position
                    else
                        local part = model:FindFirstChildWhichIsA("BasePart")
                        if part then pos = part.Position end
                    end
                    
                    if pos then
                        local dist = myPos and (pos - myPos).Magnitude or math.huge
                        if dist <= KAConfig.Range * 2 then
                            table.insert(zombies, {
                                Id = model.Name,
                                Model = model,
                                Position = pos,
                                Distance = dist,
                                Tier = "Unknown",
                                Source = "WorkspaceDeep"
                            })
                        end
                    end
                end
            end
        end
    end
    
    KACachedZombies = zombies
    return zombies
end

-- ==================== SORTED CLOSEST ZOMBIES ====================
local function KAGetClosestZombies(maxCount)
    local char = LocalPlayer.Character
    if not char then return {} end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    
    local myPos = hrp.Position
    local allZombies = KAScanZombiesFast()
    
    -- Update distances live
    for _, z in ipairs(allZombies) do
        if z.Position then z.Distance = (z.Position - myPos).Magnitude end
    end
    
    -- Filter by range
    local inRange = {}
    for _, z in ipairs(allZombies) do
        if z.Distance <= KAConfig.Range then table.insert(inRange, z) end
    end
    
    if #inRange == 0 then return {} end
    
    -- Sort by distance (O(n log n))
    table.sort(inRange, function(a, b) return a.Distance < b.Distance end)
    
    local result = {}
    for i = 1, math.min(maxCount, #inRange) do table.insert(result, inRange[i]) end
    return result
end

local function KAClearHighlight()
    if KAState.TargetHighlight then
        pcall(function() KAState.TargetHighlight:Destroy() end)
        KAState.TargetHighlight = nil
    end
end

local function KAHighlightTarget(zombie)
    if not KAConfig.HighlightTarget or not zombie or not zombie.Model then
        KAClearHighlight()
        return
    end
    if KAState.CurrentTarget == zombie and KAState.TargetHighlight and KAState.TargetHighlight.Parent then
        return
    end
    KAClearHighlight()
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(220, 40, 40)
    highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = zombie.Model
    highlight.Parent = zombie.Model
    KAState.TargetHighlight = highlight
end

local function KAGetEquippedGun()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

-- ==================== FIRE AT ZOMBIES (Solara-safe) ====================
local function KAFireAtZombies(zombies)
    if #zombies == 0 then return 0 end
    
    local gun = KAGetEquippedGun()
    if not gun then
        if KAState.DebugMode then print("[KA] No gun equipped") end
        return 0
    end
    KAState.EquippedGunName = gun.Name
    
    local char = LocalPlayer.Character
    if not char then return 0 end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    local remoteCount = 0
    
    -- Use GunRemotes directly (Solara can fire these)
    if KAState.GunRemotes then
        -- Fire remote (start firing)
        if KAState.GunRemotes.Fire and zombies[1] and zombies[1].Position then
            pcall(function()
                KAState.GunRemotes.Fire:FireServer(
                    gun.Name,
                    origin,
                    (zombies[1].Position - origin).Unit
                )
            end)
            remoteCount = remoteCount + 1
        end
        
        -- Hit remotes for all targets
        if KAState.GunRemotes.Hit then
            local maxHits = math.min(#zombies, KAConfig.MaxRemotesPerFire)
            
            for i = 1, maxHits do
                local zombie = zombies[i]
                if zombie and zombie.Id and zombie.Position then
                    task.spawn(function()
                        local success, err = pcall(function()
                            -- Try string ID first, then number
                            local id = zombie.Id
                            KAState.GunRemotes.Hit:FireServer(gun.Name, id, zombie.Position)
                        end)
                        if not success and KAState.DebugMode then
                            print("[KA] Hit failed:", err)
                        end
                    end)
                end
            end
            remoteCount = remoteCount + maxHits
        end
    end
    
    -- Brute force: fire any RemoteEvent in the gun tool
    if remoteCount == 0 then
        for _, obj in ipairs(gun:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                pcall(function()
                    obj:FireServer()
                end)
                remoteCount = remoteCount + 1
                if KAState.DebugMode then print("[KA] Fired tool remote:", obj.Name) end
            end
        end
    end
    
    if KAState.DebugMode and remoteCount == 0 then
        print("[KA] WARNING: No remotes fired! Check GunRemotes.")
    end
    
    return remoteCount
end

local function KALoop()
    if not KAConfig.Enabled then
        KAClearHighlight()
        KAState.CurrentTarget = nil
        return
    end
    
    local now = tick()
    if now - KAState.LastFireTime < KAConfig.FireRate then return end
    
    local targets = KAGetClosestZombies(KAConfig.MaxRemotesPerFire)
    
    if #targets > 0 then
        local remotesFired = KAFireAtZombies(targets)
        KAState.LastRemoteCount = remotesFired
        KAState.TotalDamageDealt = KAState.TotalDamageDealt + #targets
        KAState.LastFireTime = now
        KAState.CurrentTarget = targets[1]
        KAHighlightTarget(targets[1])
        
        if KAState.DebugMode then
            print("[KA] Hit", #targets, "zombies | Remotes:", remotesFired)
        end
    else
        KAClearHighlight()
        KAState.CurrentTarget = nil
        KAState.LastRemoteCount = 0
    end
end

-- ==================== KILL AURA UI ====================
KABox:AddToggle("KAEnable", {
    Text = "Enable Kill Aura", Default = false,
    Callback = function(Value)
        KAConfig.Enabled = Value
        if not Value then KAClearHighlight() KAState.CurrentTarget = nil end
    end,
})

KABox:AddSlider("KARange", {
    Text = "Range", Default = KAConfig.Range, Min = 10, Max = 200, Rounding = 0,
    Callback = function(Value) KAConfig.Range = Value end,
})

KABox:AddSlider("KAMaxRemotes", {
    Text = "Max Remotes/Tick", Default = KAConfig.MaxRemotesPerFire, Min = 1, Max = 20, Rounding = 0,
    Callback = function(Value) KAConfig.MaxRemotesPerFire = Value end,
})

KABox:AddSlider("KAFireRate", {
    Text = "Fire Rate (x100)", Default = KAConfig.FireRate * 100, Min = 1, Max = 20, Rounding = 0,
    Callback = function(Value) KAConfig.FireRate = Value / 100 end,
})

KABox:AddToggle("KAHighlight", {
    Text = "Highlight Target", Default = KAConfig.HighlightTarget,
    Callback = function(Value)
        KAConfig.HighlightTarget = Value
        if not Value then KAClearHighlight() end
    end,
})

KABox:AddToggle("KADebug", {
    Text = "Debug Mode", Default = true,
    Callback = function(Value) KAState.DebugMode = Value end,
})

KABox:AddLabel("Keybind: [K] to Toggle")

KABox:AddLabel("═══════════════")
KABox:AddLabel("STATUS")

local KAStatusLabel = KABox:AddLabel("GunRemotes: ?")
local KATargetLabel = KABox:AddLabel("Target: None")
local KACountLabel = KABox:AddLabel("Zombies: 0")
local KARemoteLabel = KABox:AddLabel("Remotes: 0 | Total: 0")

-- Status loop
task.spawn(function()
    while true do
        task.wait(0.3)
        local gr = KAState.GunRemotes and (KAState.GunRemotes.Hit and "✓" or "?") or "✗"
        KAStatusLabel:SetText("GunRemotes: " .. gr)
        
        if KAConfig.Enabled and KAState.CurrentTarget then
            local dist = KAState.CurrentTarget.Distance and math.floor(KAState.CurrentTarget.Distance) or 0
            KATargetLabel:SetText("Target: " .. dist .. "st | " .. (KAState.CurrentTarget.Source or "?"))
        else
            KATargetLabel:SetText("Target: None")
        end
        
        KACountLabel:SetText("Zombies: " .. #KAScanZombiesFast())
        KARemoteLabel:SetText("Remotes: " .. KAState.LastRemoteCount .. " | Total: " .. KAState.TotalDamageDealt)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == KAConfig.Keybind then
        KAConfig.Enabled = not KAConfig.Enabled
        Library.Options.KAEnable:SetValue(KAConfig.Enabled)
        if not KAConfig.Enabled then KAClearHighlight() KAState.CurrentTarget = nil end
    end
end)

-- ==================== SETTINGS ====================
local MenuBox = SettingsTab:AddLeftGroupbox("Menu")
MenuBox:AddButton({
    Text = "Unload",
    Func = function()
        if Flying then StopFly() end
        if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
        for zombieModel, _ in pairs(ZombieESP.Zombies) do RemoveZombieESP(zombieModel) end
        if ZombieESP.Folder then ZombieESP.Folder:Destroy() end
        KAClearHighlight()
        KAConfig.Enabled = false
        if KAState.Connection then KAState.Connection:Disconnect() end
        Library:Unload()
    end,
})

MenuBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift", NoUI = true, Text = "Menu Keybind"
})

-- ==================== THEME & SAVE ====================
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:ApplyToTab(SettingsTab)
SaveManager:BuildConfigSection(SettingsTab)
SaveManager:LoadAutoloadConfig()

-- ==================== CONNECTIONS ====================
local zombiesFolder = Workspace:WaitForChild("Zombies_Local")
zombiesFolder.ChildAdded:Connect(function(child)
    if child:IsA("Model") and ZombieESP.Enabled then
        task.wait(0.1)
        CreateZombieESP(child)
    end
end)

zombiesFolder.ChildRemoved:Connect(function(child)
    RemoveZombieESP(child)
end)

RunService.RenderStepped:Connect(UpdateESP)
ScanZombies()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
    PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
    ControlModule = PlayerModule:GetControls()
    if Flying then task.wait(0.5) StartFly() end
end)

-- ==================== INIT ====================
local function Init()
    KAFindRemotes()
    KAState.Connection = RunService.RenderStepped:Connect(KALoop)
    print("[Dex++] Solara version loaded!")
    if KAState.DebugMode then
        print("[Dex++] Solara has ~50-60% sUNC and ~66% UNC")
        print("[Dex++] _G and require() on game modules may not work")
    end
end

if _G.DexCleanup then pcall(_G.DexCleanup) end
_G.DexCleanup = function()
    if KAState.Connection then KAState.Connection:Disconnect() end
    KAClearHighlight()
    KAConfig.Enabled = false
    if ZombieESP.Folder then ZombieESP.Folder:Destroy() end
end

Init()
Library:Notify("Dex++ Hub Loaded! [Solara Compatible]", 3)
