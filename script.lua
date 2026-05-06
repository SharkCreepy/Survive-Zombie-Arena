-- Obsidian UI - Fly + Zombie ESP + Kill Aura
-- Complete rewrite with proper Obsidian UI Library structure

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
    Title = "Dex++ Hub",
    Footer = "Fly + ESP + Kill Aura",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

-- ==================== CREATE TABS ====================
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
    Tooltip = "Toggle fly mode",
    Callback = function(Value)
        Flying = Value
        if Flying then
            StartFly()
        else
            StopFly()
        end
    end,
})

FlyBox:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Tooltip = "Movement speed while flying",
    Callback = function(Value)
        FlySpeed = Value
    end,
})

FlyBox:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
    Tooltip = "Walk through walls",
    Callback = function(Value)
        if Value then
            NoclipConnection = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        else
            if NoclipConnection then
                NoclipConnection:Disconnect()
                NoclipConnection = nil
            end
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
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
        
        if moveDir.Magnitude > 0.01 then
            moveDir = moveDir.Unit * FlySpeed
        else
            moveDir = Vector3.new(0, 0, 0)
        end
        
        if BodyVelocity then
            BodyVelocity.Velocity = moveDir
        end
        
        if BodyGyro then
            local yaw = math.atan2(camLook.X, camLook.Z)
            BodyGyro.CFrame = CFrame.Angles(0, yaw, 0)
        end
    end)
    
    Library:Notify("Fly Enabled!", 3)
end

function StopFly()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    if BodyGyro then
        BodyGyro:Destroy()
        BodyGyro = nil
    end
    if BodyVelocity then
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end
    
    Library:Notify("Fly Disabled", 2)
end

-- ==================== ESP TAB ====================
local ESPBox = ESPTab:AddLeftGroupbox("Zombie ESP")

local ZombieESP = {
    Enabled = false,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    MaxDistance = 1000,
    TextSize = 14,
    Color = Color3.fromRGB(255, 0, 0),
    Zombies = {},
    Folder = nil,
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
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ZombieESP_Billboard"
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
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
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
    healthLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    healthLabel.Font = Enum.Font.GothamBold
    healthLabel.TextSize = ZombieESP.TextSize - 2
    healthLabel.Text = humanoid and tostring(math.floor(humanoid.Health)) .. "/" .. tostring(math.floor(humanoid.MaxHealth)) or "???"
    healthLabel.Parent = billboard
    
    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0, 20)
    distLabel.Position = UDim2.new(0, 0, 0, 40)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
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
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = zombieModel
    highlight.Parent = ZombieESP.Folder
    esp.Highlight = highlight
    
    ZombieESP.Zombies[zombieModel] = esp
    
    zombieModel.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            RemoveZombieESP(zombieModel)
        end
    end)
    
    if humanoid then
        humanoid.HealthChanged:Connect(function(health)
            if ZombieESP.Zombies[zombieModel] and ZombieESP.Zombies[zombieModel].HealthLabel then
                local pct = health / humanoid.MaxHealth
                ZombieESP.Zombies[zombieModel].HealthLabel.Text = tostring(math.floor(health)) .. "/" .. tostring(math.floor(humanoid.MaxHealth))
                if pct > 0.5 then
                    ZombieESP.Zombies[zombieModel].HealthLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                elseif pct > 0.25 then
                    ZombieESP.Zombies[zombieModel].HealthLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                else
                    ZombieESP.Zombies[zombieModel].HealthLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                end
            end
        end)
        
        humanoid.Died:Connect(function()
            RemoveZombieESP(zombieModel)
        end)
    end
end

local function ScanZombies()
    local zombiesFolder = Workspace:FindFirstChild("Zombies_Local")
    if not zombiesFolder then return end
    for _, zombie in pairs(zombiesFolder:GetChildren()) do
        if zombie:IsA("Model") then
            CreateZombieESP(zombie)
        end
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
        if not zombieModel.Parent then
            RemoveZombieESP(zombieModel)
            continue
        end
        
        local head = esp.Head
        if not head or not head.Parent then
            RemoveZombieESP(zombieModel)
            continue
        end
        
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
                esp.DistLabel.Text = tostring(math.floor(distance)) .. "m"
                esp.DistLabel.Visible = true
            else
                esp.DistLabel.Visible = false
            end
        end
        
        if esp.Highlight then
            esp.Highlight.Enabled = true
            esp.Highlight.FillColor = ZombieESP.Color
        end
    end
end

ESPBox:AddToggle("ESPEnable", {
    Text = "Enable Zombie ESP",
    Default = false,
    Tooltip = "Show ESP on all zombies",
    Callback = function(Value)
        ZombieESP.Enabled = Value
        if Value then ScanZombies() end
    end,
})

ESPBox:AddToggle("ESPName", {
    Text = "Show Name",
    Default = true,
    Callback = function(Value)
        ZombieESP.ShowName = Value
    end,
})

ESPBox:AddToggle("ESPHealth", {
    Text = "Show Health",
    Default = true,
    Callback = function(Value)
        ZombieESP.ShowHealth = Value
    end,
})

ESPBox:AddToggle("ESPDistance", {
    Text = "Show Distance",
    Default = true,
    Callback = function(Value)
        ZombieESP.ShowDistance = Value
    end,
})

ESPBox:AddSlider("ESPMaxDist", {
    Text = "Max Distance",
    Default = 1000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Callback = function(Value)
        ZombieESP.MaxDistance = Value
    end,
})

ESPBox:AddSlider("ESPTextSize", {
    Text = "Text Size",
    Default = 14,
    Min = 8,
    Max = 24,
    Rounding = 0,
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
    Default = Color3.fromRGB(255, 0, 0),
    Title = "Color",
    Transparency = 0,
    Callback = function(Value)
        ZombieESP.Color = Value
    end,
})

-- ==================== KILL AURA TAB ====================
local KABox = KillAuraTab:AddLeftGroupbox("Kill Aura")

local KAConfig = {
    Enabled = false,
    Range = 50,
    MaxTargets = 10,
    LimitTargets = true,
    FireRate = 0.05,
    HighlightTarget = true,
    Keybind = Enum.KeyCode.K,
}

local KAState = {
    Connection = nil,
    LastFireTime = 0,
    CurrentTarget = nil,
    TargetHighlight = nil,
    ZombieClient = nil,
    GunClient = nil,
    GunRemotes = nil,
    EquippedGunName = nil,
}

local KACachedZombies = {}
local KALastScan = 0
local KAScanInterval = 0.15

local function FindGameClients()
    if _G.ZombieClient and typeof(_G.ZombieClient) == "table" and _G.ZombieClient.Zombies then
        KAState.ZombieClient = _G.ZombieClient
    end
    if _G.GunClient and typeof(_G.GunClient) == "table" and _G.GunClient.TryFire then
        KAState.GunClient = _G.GunClient
    end
    
    local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 5)
    if playerScripts then
        local function scan(parent)
            for _, obj in ipairs(parent:GetChildren()) do
                if obj:IsA("ModuleScript") then
                    local s, r = pcall(function() return require(obj) end)
                    if s and typeof(r) == "table" then
                        if not KAState.ZombieClient and r.Zombies and r.GetNearbyZombieIds then
                            KAState.ZombieClient = r
                        end
                        if not KAState.GunClient and r.TryFire and r.EquippedGun ~= nil then
                            KAState.GunClient = r
                        end
                    end
                end
                if obj:IsA("Folder") or obj:IsA("ScreenGui") then
                    scan(obj)
                end
            end
        end
        scan(playerScripts)
    end
    
    local gunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
    if gunRemotes then
        KAState.GunRemotes = {
            Fire = gunRemotes:FindFirstChild("GunFire"),
            Hit = gunRemotes:FindFirstChild("GunHit"),
        }
    end
    
    print("[KA] ZombieClient:", KAState.ZombieClient ~= nil)
    print("[KA] GunClient:", KAState.GunClient ~= nil)
end

local function KAScanZombies()
    local now = tick()
    if now - KALastScan < KAScanInterval then
        return KACachedZombies
    end
    KALastScan = now
    
    local zombies = {}
    
    if KAState.ZombieClient and KAState.ZombieClient.Zombies then
        for id, data in pairs(KAState.ZombieClient.Zombies) do
            if data and not data.IsDying and data.Model and data.Model.Parent then
                table.insert(zombies, {
                    Id = id,
                    Model = data.Model,
                    Position = data.CurrentPosition or data.TargetPosition,
                    Tier = data.Tier or "Unknown"
                })
            end
        end
        KACachedZombies = zombies
        return zombies
    end
    
    local folder = Workspace:FindFirstChild("Zombies_Local")
    if folder then
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") then
                local pos = nil
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hrp then pos = hrp.Position end
                local id = tonumber(model.Name:match("%d+")) or model.Name
                table.insert(zombies, {Id = id, Model = model, Position = pos})
            end
        end
    end
    
    KACachedZombies = zombies
    return zombies
end

local function KAGetZombiesInRange()
    local char = LocalPlayer.Character
    if not char then return {} end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    
    local myPos = hrp.Position
    local result = {}
    
    for _, zombie in ipairs(KAScanZombies()) do
        if zombie.Position and (zombie.Position - myPos).Magnitude <= KAConfig.Range then
            zombie.Distance = (zombie.Position - myPos).Magnitude
            table.insert(result, zombie)
        end
    end
    
    table.sort(result, function(a, b)
        return (a.Distance or 0) < (b.Distance or 0)
    end)
    
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

local function KABatchFire(zombies)
    if #zombies == 0 then return false end
    
    local gun = KAGetEquippedGun()
    if not gun then return false end
    KAState.EquippedGunName = gun.Name
    
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    local limit = KAConfig.LimitTargets and KAConfig.MaxTargets or #zombies
    
    local hitData = {}
    for i = 1, math.min(#zombies, limit) do
        local zombie = zombies[i]
        if zombie.Position and zombie.Id then
            table.insert(hitData, {Id = zombie.Id, Position = zombie.Position})
        end
    end
    
    if #hitData == 0 then return false end
    
    if KAState.GunClient and KAState.GunClient.TryFire then
        local oldGetAim = KAState.GunClient.GetAimDirection
        for _, hit in ipairs(hitData) do
            local dir = (hit.Position - origin).Unit
            if oldGetAim then
                KAState.GunClient.GetAimDirection = function(self) return dir end
            end
            local wasFiring = KAState.GunClient.IsFiring
            KAState.GunClient.IsFiring = true
            pcall(function() KAState.GunClient:TryFire() end)
            KAState.GunClient.IsFiring = wasFiring
        end
        if oldGetAim then
            KAState.GunClient.GetAimDirection = oldGetAim
        end
        
        if KAState.GunRemotes and KAState.GunRemotes.Hit then
            for _, hit in ipairs(hitData) do
                task.spawn(function()
                    pcall(function()
                        KAState.GunRemotes.Hit:FireServer(gun.Name, hit.Id, hit.Position)
                    end)
                end)
            end
        end
        return true
    end
    
    if KAState.GunRemotes then
        if KAState.GunRemotes.Fire then
            pcall(function()
                KAState.GunRemotes.Fire:FireServer(gun.Name, origin, (zombies[1].Position - origin).Unit)
            end)
        end
        if KAState.GunRemotes.Hit then
            for _, hit in ipairs(hitData) do
                task.spawn(function()
                    pcall(function()
                        KAState.GunRemotes.Hit:FireServer(gun.Name, hit.Id, hit.Position)
                    end)
                end)
            end
        end
        return true
    end
    
    return false
end

local function KALoop()
    if not KAConfig.Enabled then
        KAClearHighlight()
        KAState.CurrentTarget = nil
        return
    end
    
    local now = tick()
    if now - KAState.LastFireTime < KAConfig.FireRate then return end
    
    local targets = KAGetZombiesInRange()
    
    if #targets > 0 then
        KABatchFire(targets)
        KAState.LastFireTime = now
        KAState.CurrentTarget = targets[1]
        KAHighlightTarget(targets[1])
    else
        KAClearHighlight()
        KAState.CurrentTarget = nil
    end
end

-- Kill Aura UI Elements
KABox:AddToggle("KAEnable", {
    Text = "Enable Kill Aura",
    Default = false,
    Tooltip = "Toggle Kill Aura on/off",
    Callback = function(Value)
        KAConfig.Enabled = Value
        if not Value then
            KAClearHighlight()
            KAState.CurrentTarget = nil
        end
    end,
})

KABox:AddSlider("KARange", {
    Text = "Range",
    Default = KAConfig.Range,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Tooltip = "Detection range in studs",
    Callback = function(Value)
        KAConfig.Range = Value
    end,
})

KABox:AddToggle("KALimit", {
    Text = "Limit Max Targets",
    Default = KAConfig.LimitTargets,
    Tooltip = "Toggle max targets limit",
    Callback = function(Value)
        KAConfig.LimitTargets = Value
    end,
})

KABox:AddSlider("KAMaxTargets", {
    Text = "Max Targets",
    Default = KAConfig.MaxTargets,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Tooltip = "Max zombies to target (1-50)",
    Callback = function(Value)
        KAConfig.MaxTargets = Value
    end,
})

KABox:AddToggle("KAHighlight", {
    Text = "Highlight Target",
    Default = KAConfig.HighlightTarget,
    Tooltip = "Toggle target highlight",
    Callback = function(Value)
        KAConfig.HighlightTarget = Value
        if not Value then KAClearHighlight() end
    end,
})

KABox:AddSlider("KAFireRate", {
    Text = "Fire Rate",
    Default = KAConfig.FireRate * 100,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Tooltip = "Fire rate (lower = faster)",
    Callback = function(Value)
        KAConfig.FireRate = Value / 100
    end,
})

KABox:AddLabel("Keybind: [K] to Toggle")

-- Status Labels
KABox:AddLabel("═══════════════")
KABox:AddLabel("STATUS")

local KAStatusLabel = KABox:AddLabel("ZombieClient: ? | GunClient: ?")
local KATargetLabel = KABox:AddLabel("Target: None")
local KACountLabel = KABox:AddLabel("Zombies: 0")
local KALimitLabel = KABox:AddLabel("Limit: ON | Max: 10")

-- Status Update Loop
task.spawn(function()
    while true do
        task.wait(0.3)
        
        local zc = KAState.ZombieClient and "✓" or "✗"
        local gc = KAState.GunClient and "✓" or "✗"
        KAStatusLabel:SetText("ZombieClient: " .. zc .. " | GunClient: " .. gc)
        
        if KAConfig.Enabled and KAState.CurrentTarget then
            local dist = KAState.CurrentTarget.Position and math.floor((KAState.CurrentTarget.Position - (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new())).Magnitude) or 0
            KATargetLabel:SetText("Target: " .. tostring(KAState.CurrentTarget.Tier or "Zombie") .. " | " .. dist .. " studs")
        else
            KATargetLabel:SetText("Target: None")
        end
        
        KACountLabel:SetText("Zombies: " .. #KAScanZombies())
        
        if KAConfig.LimitTargets then
            KALimitLabel:SetText("Limit: ON | Max: " .. KAConfig.MaxTargets)
        else
            KALimitLabel:SetText("Limit: OFF | All in range")
        end
    end
end)

-- Keybind
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == KAConfig.Keybind then
        KAConfig.Enabled = not KAConfig.Enabled
        Library.Options.KAEnable:SetValue(KAConfig.Enabled)
        if not KAConfig.Enabled then
            KAClearHighlight()
            KAState.CurrentTarget = nil
        end
    end
end)

-- ==================== SETTINGS TAB ====================
local MenuBox = SettingsTab:AddLeftGroupbox("Menu")

MenuBox:AddButton({
    Text = "Unload",
    Func = function()
        if Flying then StopFly() end
        if NoclipConnection then
            NoclipConnection:Disconnect()
            NoclipConnection = nil
        end
        for zombieModel, _ in pairs(ZombieESP.Zombies) do
            RemoveZombieESP(zombieModel)
        end
        if ZombieESP.Folder then
            ZombieESP.Folder:Destroy()
        end
        KAClearHighlight()
        KAConfig.Enabled = false
        if KAState.Connection then
            KAState.Connection:Disconnect()
        end
        Library:Unload()
    end,
})

MenuBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu Keybind"
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
    
    if Flying then
        task.wait(0.5)
        StartFly()
    end
end)

-- ==================== INIT ====================
local function Init()
    FindGameClients()
    KAState.Connection = RunService.RenderStepped:Connect(KALoop)
    print("[Dex++] Loaded successfully!")
end

if _G.DexCleanup then pcall(_G.DexCleanup) end

_G.DexCleanup = function()
    if KAState.Connection then KAState.Connection:Disconnect() end
    KAClearHighlight()
    KAConfig.Enabled = false
end

Init()

Library:Notify("Dex++ Hub Loaded!", 3)
