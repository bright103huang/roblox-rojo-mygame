# 家场景玩法改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Home scene with expanded layout, interactive meditation (breath rhythm + pill refining), sleep minigame, and ceremonial prayer altar.

**Architecture:** Six new/modified client UI scripts, one new animation module, server-side layout/config changes, and ShopService enforcement of meditation-only pill usage. Communication via HomeEvents RemoteEvent + existing ShopEvent.

**Tech Stack:** Roblox Lua (Luau), KeyframeSequence programmatic animation, TweenService for UI, StatusService/DataManager for state.

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `ReplicatedStorage/Shared/Modules/AnimationFactory.lua` | Generate KeyframeSequence for sit/lay/kneel poses |
| `ReplicatedStorage/Shared/Events/HomeEvents.lua` | Create HomeEvents RemoteEvent for meditation/sleep/prayer comms |
| `StarterPlayer/StarterPlayerScripts/client/BreathUI.local.lua` | Breath rhythm minigame UI + pill consumption panel |
| `StarterPlayer/StarterPlayerScripts/client/SleepUI.local.lua` | Peace balance sleep minigame UI |
| `StarterPlayer/StarterPlayerScripts/client/PrayerUI.local.lua` | Prayer altar selection/ceremony UI |

### Modified Files
| File | What Changes |
|------|-------------|
| `ServerScriptService/server/Systems/SceneSetup.server.lua` | Expand Home X to 50, add bed/screen/windows/blue cushion/lights |
| `ServerScriptService/server/Systems/ShopService.server.lua` | Reject UseItem when isMeditating==false |
| `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua` | Add IsMeditating=true when calling UseItem during meditation |
| `ReplicatedStorage/Shared/Config/StatsConfig.lua` | Add MEDITATION/SLEEP numeric constants |
| `ServerScriptService/server/Systems/DataManager.lua` | Add LastSleptDay, PrayerOption fields to DEFAULT_DATA |

---

## Task Dependency Graph

```
Task 1 (AnimationFactory) ──────┬─── Task 3 (Layout/SceneSetup)
Task 2 (Config + Data) ─────────┤
Task 4 (HomeEvents RemoteEvent) ─┼─── Task 5 (BreathUI)
                                 ├─── Task 6 (SleepUI)
                                 ├─── Task 7 (PrayerUI)
                                 └─── Task 8 (ShopService + ShopUI)
```

**Phase 1 (parallel, independent):** Tasks 1, 2, 4
**Phase 2 (parallel, depend on Phase 1):** Tasks 3, 5, 6, 7, 8

---

### Task 1: AnimationFactory Module

**Files:**
- Create: `ReplicatedStorage/Shared/Modules/AnimationFactory.lua`

- [ ] **Step 1: Write the AnimationFactory module structure**

Create a module that generates three KeyframeSequence animations:

```lua
-- ReplicatedStorage/Shared/Modules/AnimationFactory.lua
local AnimationFactory = {}

local function createPose(partName, cframe, weight)
    local pose = Instance.new("Pose")
    pose.Name = partName
    pose.CFrame = cframe
    pose.Weight = weight or 1
    return pose
end

local function createKeyframe(time, poses)
    local kf = Instance.new("Keyframe")
    kf.Time = time
    for _, pose in ipairs(poses) do
        pose.Parent = kf
    end
    return kf
end

function AnimationFactory:CreateSitSequence()
    local seq = Instance.new("KeyframeSequence")
    seq.Name = "SitCrossLegged"
    -- Standing pose at t=0
    local kf0 = createKeyframe(0, {
        createPose("LeftUpperLeg", CFrame.Angles(-0.8, 0.3, 0)),
        createPose("RightUpperLeg", CFrame.Angles(-0.8, -0.3, 0)),
        createPose("HumanoidRootPart", CFrame.new(0, -1.2, 0)),
    })
    kf0.Parent = seq
    -- Sitting pose at t=0.3 (final position)
    local kf1 = createKeyframe(0.3, {
        createPose("LeftUpperLeg", CFrame.Angles(-0.8, 0.3, 0)),
        createPose("RightUpperLeg", CFrame.Angles(-0.8, -0.3, 0)),
        createPose("LeftLowerLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightLowerLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("LeftFoot", CFrame.new(0, 0, 0.3)),
        createPose("RightFoot", CFrame.new(0, 0, -0.3)),
        createPose("LowerTorso", CFrame.Angles(0, 0, -0.1)),
        createPose("HumanoidRootPart", CFrame.new(0, -1.2, 0)),
    })
    kf1.Parent = seq
    return seq
end

function AnimationFactory:CreateLaySequence()
    local seq = Instance.new("KeyframeSequence")
    seq.Name = "LayDown"
    local rot = math.rad(-90)
    local kf0 = createKeyframe(0, {})
    kf0.Parent = seq
    local kf1 = createKeyframe(0.5, {
        createPose("HumanoidRootPart", CFrame.Angles(0, 0, rot)),
        createPose("UpperTorso", CFrame.Angles(0, 0, rot)),
        createPose("LowerTorso", CFrame.Angles(0, 0, rot)),
        createPose("LeftUpperArm", CFrame.Angles(0, 0, 0.2)),
        createPose("RightUpperArm", CFrame.Angles(0, 0, -0.2)),
    })
    kf1.Parent = seq
    return seq
end

function AnimationFactory:CreateKneelSequence()
    local seq = Instance.new("KeyframeSequence")
    seq.Name = "KneelBow"
    -- Kneel down
    local kf0 = createKeyframe(0, {})
    kf0.Parent = seq
    local kf1 = createKeyframe(0.3, {
        createPose("HumanoidRootPart", CFrame.new(0, -1, 0)),
        createPose("LeftUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightUpperLeg", CFrame.Angles(1.2, 0, 0)),
    })
    kf1.Parent = seq
    -- Bow
    local kf2 = createKeyframe(0.6, {
        createPose("HumanoidRootPart", CFrame.new(0, -1, 0)),
        createPose("LeftUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("UpperTorso", CFrame.Angles(math.rad(30), 0, 0)),
    })
    kf2.Parent = seq
    -- Return up
    local kf3 = createKeyframe(1.0, {
        createPose("HumanoidRootPart", CFrame.new(0, -1, 0)),
        createPose("LeftUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightUpperLeg", CFrame.Angles(1.2, 0, 0)),
    })
    kf3.Parent = seq
    return seq
end

function AnimationFactory:PlayAnimation(humanoid, sequence, looped)
    local track = humanoid:LoadAnimation(sequence)
    track.Priority = Enum.AnimationPriority.Action
    track.Looped = looped or false
    track:Play(0.1, 1, 1)
    return track
end

return AnimationFactory
```

- [ ] **Step 2: Test the AnimationFactory structure**

Write a test for AnimationFactory:

```lua
-- Append to tests/run.lua
describe("AnimationFactory", function()
    it("should create sit sequence with correct keyframes", function()
        local factory = require(script.Parent.ReplicatedStorage.Shared.Modules.AnimationFactory)
        local seq = factory:CreateSitSequence()
        expect.ok(seq, "sit sequence should exist")
        expect.ok(seq.Name == "SitCrossLegged", "name should match")
        -- Count keyframes
        local count = 0
        for _ in seq:GetChildren() do count += 1 end
        expect.ok(count >= 2, "should have at least 2 keyframes")
    end)
end)
```

Run: `luau tests/run.lua` (from project root dir)
Expected: Test passes

- [ ] **Step 3: Commit**

```bash
git add ReplicatedStorage/Shared/Modules/AnimationFactory.lua tests/run.lua
git commit -m "feat: add AnimationFactory for programmatic pose generation"
```

---

### Task 2: StatsConfig Constants + DataManager Fields

**Files:**
- Modify: `ReplicatedStorage/Shared/Config/StatsConfig.lua`
- Modify: `ServerScriptService/server/Systems/DataManager.lua`

- [ ] **Step 1: Add meditation/sleep constants to StatsConfig.lua**

Read the existing StatsConfig.lua, then append:

```lua
-- Add to StatsConfig.lua
MEDITATION = {
    BaseStaminaRecovery = 3,
    BaseSpiritRecovery = 6,
    BaseFatigueLoss = 2,
    PerfectMultiplier = 1.5,
    PreciseMultiplier = 1.2,
    NormalMultiplier = 1.0,
    MissMultiplier = 0.5,
    HighMaliceThreshold = 30,
    MaxMaliceThreshold = 50,
    PhaseInhaleDuration = 2.0,
    PhaseHoldDuration = 1.5,
    PhaseExhaleDuration = 2.0,
    PerfectWindow = 0.15,
    PreciseWindow = 0.30,
    TranceLayerStep = 3,  -- every N perfect cycles = 1 layer
},
SLEEP = {
    Duration = 20,  -- seconds
    AdvanceHours = 2,
    PeaceZoneWidth = 0.4,  -- fraction of total range
    NightmareInterval = 10,
    NightmareShrinkFactor = 0.5,
    DeepThreshold = 0.8,
    LightThreshold = 0.5,
    RestlessThreshold = 0.25,
    DeepStaminaRecovery = -1,  -- -1 means full
    DeepSpiritRecovery = 20,
    LightStaminaRecovery = 30,
    LightSpiritRecovery = 10,
    LightFatigueLoss = 15,
    RestlessStaminaRecovery = 15,
    RestlessSpiritRecovery = 5,
    RestlessFatigueLoss = 5,
    InsomniaStaminaRecovery = 5,
    InsomniaFatigueLoss = 2,
    ExpPerDeepSleep = 3,
    ExpPerLightSleep = 1,
},
```

- [ ] **Step 2: Add fields to DataManager DEFAULT_DATA**

Read existing DEFAULT_DATA, then add:

```lua
LastSleptDay = "",       -- format YYYYMMDD for once-per-day sleep
PrayerOption = "",       -- last prayer choice type
```

- [ ] **Step 3: Commit**

```bash
git add ReplicatedStorage/Shared/Config/StatsConfig.lua ServerScriptService/server/Systems/DataManager.lua
git commit -m "feat: add meditation/sleep constants and DataManager fields"
```

---

### Task 3: SceneSetup Layout Expansion

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Step 1: Expand Home scene X range and add new decorations**

Read the existing `setupHomeScene()` function (around line 711-876). Replace it with expanded version:

- Change X range: from 30 (-14~14) to 50 (-24~24)
- Blue cushion: `BrickColor.new("Bright blue")` with orange inner, size `Vector3.new(4, 0.3, 4)`
- Floor rug: circular bright yellow under cushion
- Bed: decorative wooden frame + mattress at X=-14 to -10 area
- Screen divider: at X=-7 between bed and meditation area
- Windows: on back wall (Z=-4) at X=-20 and X=20 with transparent glass
- Extra PointLight fixtures per zone
- Prayer area upgrade: add incense burner with ParticleEmitter

Note: Keep existing meditation Touched logic BUT remove the old auto-heal passive loop. The meditation interaction will now be driven by BreathUI instead.

- [ ] **Step 2: Verify layout loads without errors**

Run the server. Expected: Home scene spawns with expanded layout, no nil errors.

- [ ] **Step 3: Commit**

```bash
git add ServerScriptService/server/Systems/SceneSetup.server.lua
git commit -m "feat: expand Home scene layout with new decorations and bed"
```

---

### Task 4: HomeEvents RemoteEvent

**Files:**
- Create: `ReplicatedStorage/Shared/Events/HomeEvents.lua`

- [ ] **Step 1: Create HomeEvents module**

```lua
-- ReplicatedStorage/Shared/Events/HomeEvents.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
    eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "Events"
    eventsFolder.Parent = ReplicatedStorage
end

local HomeEvent = eventsFolder:FindFirstChild("HomeEvent")
if not HomeEvent then
    HomeEvent = Instance.new("RemoteEvent")
    HomeEvent.Name = "HomeEvent"
    HomeEvent.Parent = eventsFolder
end

return HomeEvent
```

This acts as a bidirectional channel with action string routing:
- Client→Server: "BreathResult", "SleepComplete", "PrayerChoice"
- Server→Client: "BreathSettlement", "SleepSettlement", "PrayerResult"

- [ ] **Step 2: Verify the module loads**

Run: `luau tests/run.lua` (module is a simple wrapper, no complex logic to test beyond checking no errors)

- [ ] **Step 3: Commit**

```bash
git add ReplicatedStorage/Shared/Events/HomeEvents.lua
git commit -m "feat: add HomeEvents RemoteEvent for home interaction comms"
```

---

### Task 5: BreathUI (Meditation + Pill Panel)

**Files:**
- Create: `StarterPlayer/StarterPlayerScripts/client/BreathUI.local.lua`
- Reference: `ReplicatedStorage/Shared/Events/HomeEvents.lua`
- Reference: `ReplicatedStorage/Shared/Modules/AnimationFactory.lua`

This is the most complex component. The script:

1. Listens for a RemoteEvent signal from server when player touches cushion
2. Plays sit animation via AnimationFactory
3. Shows breath ring UI with TweenService animations
4. Handles F key press/release for inhale/hold/exhale phases
5. Sends breath result to server each cycle
6. Shows pill inventory panel on left side
7. Handles pill consumption via ShopEvent (with IsMeditating=true)

- [ ] **Step 1: Write BreathUI structure with UI creation and show/hide**

```lua
-- StarterPlayer/StarterPlayerScripts/client/BreathUI.local.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local ShopEvent = ReplicatedStorage:FindFirstChild("Events"):FindFirstChild("ShopEvent")
local AnimationFactory = require(ReplicatedStorage.Shared.Modules.AnimationFactory)

-- Breath phases
local PHASES = {
    INHALE = { duration = 2.0, perfect = 0.15, precise = 0.30 },
    HOLD = { duration = 1.5, perfect = 0.15, precise = 0.30 },
    EXHALE = { duration = 2.0, perfect = 0.15, precise = 0.30 },
}
local TRANCE_LAYER_STEP = 3
local HIGH_MALICE_THRESHOLD = 30
local MAX_MALICE_THRESHOLD = 50

local BreathUI = {}
local isActive = false
local currentPhase = nil
local phaseStartTime = 0
local isFPressed = false
local isHolding = false
local consecutivePerfect = 0
local currentLayer = 0
local breathMultiplier = 1.0
local malAdjust = 1.0  -- malice adjustment factor for speed

-- UI elements
local screenGui, outerRing, cursor, phaseLabel, feedbackLabel, layerLabel, backpackFrame

function BreathUI:CreateUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BreathUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Backdrop
    local backdrop = Instance.new("ImageLabel")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.5
    backdrop.Parent = screenGui
    
    -- Ring container (centered)
    local ringContainer = Instance.new("Frame")
    ringContainer.Name = "RingContainer"
    ringContainer.Size = UDim2.new(0, 200, 0, 200)
    ringContainer.Position = UDim2.new(0.5, -100, 0.5, -120)
    ringContainer.BackgroundTransparency = 1
    ringContainer.Parent = screenGui
    
    -- Outer ring
    outerRing = Instance.new("Frame")
    outerRing.Name = "OuterRing"
    outerRing.Size = UDim2.new(0, 40, 0, 40)
    outerRing.Position = UDim2.new(0.5, -20, 0.5, -20)
    outerRing.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    outerRing.BackgroundTransparency = 0.6
    outerRing.Parent = ringContainer
    -- Corner to make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = outerRing
    
    -- Cursor (inner dot)
    cursor = Instance.new("Frame")
    cursor.Name = "Cursor"
    cursor.Size = UDim2.new(0, 8, 0, 8)
    cursor.Position = UDim2.new(0.5, -4, 0.5, -4)
    cursor.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
    cursor.BackgroundTransparency = 0.2
    cursor.Parent = ringContainer
    local cursorCorner = Instance.new("UICorner")
    cursorCorner.CornerRadius = UDim.new(1, 0)
    cursorCorner.Parent = cursor
    
    -- Phase label
    phaseLabel = Instance.new("TextLabel")
    phaseLabel.Name = "PhaseLabel"
    phaseLabel.Size = UDim2.new(0, 200, 0, 30)
    phaseLabel.Position = UDim2.new(0.5, -100, 0.5, 50)
    phaseLabel.BackgroundTransparency = 1
    phaseLabel.Text = "准备"
    phaseLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
    phaseLabel.TextSize = 24
    phaseLabel.Font = Enum.Font.SourceSansBold
    phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
    phaseLabel.Parent = screenGui
    
    -- Feedback label
    feedbackLabel = Instance.new("TextLabel")
    feedbackLabel.Name = "FeedbackLabel"
    feedbackLabel.Size = UDim2.new(0, 200, 0, 24)
    feedbackLabel.Position = UDim2.new(0.5, -100, 0.5, 80)
    feedbackLabel.BackgroundTransparency = 1
    feedbackLabel.Text = ""
    feedbackLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    feedbackLabel.TextSize = 18
    feedbackLabel.Font = Enum.Font.SourceSans
    feedbackLabel.TextXAlignment = Enum.TextXAlignment.Center
    feedbackLabel.Parent = screenGui
    
    -- Layer display
    layerLabel = Instance.new("TextLabel")
    layerLabel.Name = "LayerDisplay"
    layerLabel.Size = UDim2.new(0, 200, 0, 20)
    layerLabel.Position = UDim2.new(0.5, -100, 0.5, 105)
    layerLabel.BackgroundTransparency = 1
    layerLabel.Text = ""
    layerLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    layerLabel.TextSize = 14
    layerLabel.Font = Enum.Font.SourceSans
    layerLabel.TextXAlignment = Enum.TextXAlignment.Center
    layerLabel.Parent = screenGui
    
    -- Exit hint
    local exitHint = Instance.new("TextLabel")
    exitHint.Name = "ExitHint"
    exitHint.Size = UDim2.new(0, 200, 0, 20)
    exitHint.Position = UDim2.new(0.5, -100, 1, -40)
    exitHint.BackgroundTransparency = 1
    exitHint.Text = "按 Esc 结束打坐"
    exitHint.TextColor3 = Color3.fromRGB(150, 150, 150)
    exitHint.TextSize = 14
    exitHint.Font = Enum.Font.SourceSans
    exitHint.TextXAlignment = Enum.TextXAlignment.Center
    exitHint.Parent = screenGui
    
    -- Pill backpack panel (left side)
    backpackFrame = Instance.new("Frame")
    backpackFrame.Name = "BackpackPanel"
    backpackFrame.Size = UDim2.new(0, 120, 0, 300)
    backpackFrame.Position = UDim2.new(0, 10, 0.5, -150)
    backpackFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    backpackFrame.BackgroundTransparency = 0.3
    backpackFrame.Parent = screenGui
    local bpCorner = Instance.new("UICorner")
    bpCorner.CornerRadius = UDim.new(0, 6)
    bpCorner.Parent = backpackFrame
    
    local bpLabel = Instance.new("TextLabel")
    bpLabel.Name = "BPLabel"
    bpLabel.Size = UDim2.new(1, 0, 0, 24)
    bpLabel.BackgroundTransparency = 1
    bpLabel.Text = "丹药"
    bpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    bpLabel.TextSize = 14
    bpLabel.Font = Enum.Font.SourceSansBold
    bpLabel.Parent = backpackFrame
    
    BreathUI:Hide()
end

function BreathUI:Show(data)
    screenGui.Enabled = true
    isActive = true
    consecutivePerfect = 0
    currentLayer = 0
    BreathUI:UpdateLayerDisplay()
    -- Get malice for difficulty adjustment
    malAdjust = 1.0
    local malice = player:GetAttribute("Malice") or 0
    if malice > MAX_MALICE_THRESHOLD then
        BreathUI:Hide()
        return  -- can't meditate
    elseif malice > HIGH_MALICE_THRESHOLD then
        malAdjust = 1.33  -- phases 33% faster
    end
    -- Populate backpack panel
    BreathUI:PopulateBackpack()
    -- Start first breath cycle
    BreathUI:StartPhase("INHALE")
end

function BreathUI:Hide()
    isActive = false
    if screenGui then
        screenGui.Enabled = false
    end
    currentPhase = nil
end

return BreathUI
```

[TASK 5 CONTINUED - See note about file size]

### Task 6: SleepUI (Peace Balance Minigame)

**Files:**
- Create: `StarterPlayer/StarterPlayerScripts/client/SleepUI.local.lua`
- Reference: `ReplicatedStorage/Shared/Events/HomeEvents.lua`
- Reference: `ReplicatedStorage/Shared/Modules/AnimationFactory.lua`

- [ ] **Step 1: Write SleepUI with peace balance gameplay**

```lua
-- StarterPlayer/StarterPlayerScripts/client/SleepUI.local.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local AnimationFactory = require(ReplicatedStorage.Shared.Modules.AnimationFactory)

local SleepUI = {}
local isActive = false
local peaceTime = 0
local totalTime = 0
local pointerPos = 0.5  -- 0=left, 1=right
local pointerVelocity = 0
local peaceZoneWidth = 0.4
local isNightmare = false
local nightmareTimer = 0

-- UI elements
local screenGui, pointerBar, pointer, peaceZone, depthLabel, statusLabel, timerLabel

function SleepUI:CreateUI()
    -- Similar pattern to BreathUI: ScreenGui with backdrop
    -- Center: horizontal bar (pointerBar) 400px wide
    -- Peace zone: green highlighted area in middle (40% width)
    -- Pointer: small triangle/circle that oscillates left/right
    -- Timer: countdown from 20s
    -- Depth: text showing sleep quality tier
end

function SleepUI:Start()
    -- Play lay animation
    -- Show UI
    -- Start physics loop
    -- After 20s: send result to server
end

function SleepUI:Update(dt)
    -- Physics: pointer oscillates
    -- Click → push right
    -- No click → drift left
    -- Check nightmare
    -- Accumulate peaceTime if pointer in peace zone
end

return SleepUI
```

- [ ] **Step 2: Implement pointer physics and nightmare system**

The pointer uses a simple spring-like physics:
- Natural drift: pointer velocity moves toward left at 0.3/s
- Click impulse: adds +0.4 to velocity (capped at 1.0/s)
- Damping: velocity *= 0.98 each frame
- Peace zone center at 0.5, width configurable (0.4 default)
- Nightmare: when pointer exits bounds for 3+ sec → insomnia

- [ ] **Step 3: Wire up HomeEvent for result submission**

On completion (20s or Esc), call:
```lua
HomeEvent:FireServer("SleepComplete", {
    PeaceRatio = peaceTime / totalTime,
    NightmaresTriggered = nightmareCount,
})
```

- [ ] **Step 4: Commit**

---

### Task 7: PrayerUI (Ceremonial Prayer Altar)

**Files:**
- Create: `StarterPlayer/StarterPlayerScripts/client/PrayerUI.local.lua`
- Reference: `ReplicatedStorage/Shared/Events/HomeEvents.lua`

- [ ] **Step 1: Write PrayerUI with three-tier selection**

Three buttons: 诚心礼拜 (free), 焚香祷告 (10 XianJing), 虔诚供奉 (50 XianJing)
Each shows cost/benefit info.
On click: `HomeEvent:FireServer("PrayerChoice", { Option = choice })`
Server validates cost, deducts, applies effects.
Server fires back: `PrayerResult` with success/message.

- [ ] **Step 2: Play kneel animation on selection**

```lua
local kneelSeq = AnimationFactory:CreateKneelSequence()
local track = AnimationFactory:PlayAnimation(humanoid, kneelSeq)
```

- [ ] **Step 3: Commit**

---

### Task 8: ShopService + ShopUI Enforcement

**Files:**
- Modify: `ServerScriptService/server/Systems/ShopService.server.lua`
- Modify: `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua`

- [ ] **Step 1: Enforce isMeditating in ShopService**

In the `UseItem:Shop` handler (around line 421-435), change:
```lua
-- BEFORE:
local isMeditating = contextData and contextData.IsMeditating or false
-- AFTER:
local isMeditating = contextData and contextData.IsMeditating == true
if not isMeditating then
    ShopEvent:FireClient(player, "UseItemResult", {
        Success = false,
        Message = "丹药需在打坐时炼化",
        Backpack = data and data.Backpack or {},
    })
    return
end
```

Also enforce in `ShopService:UseItem()` itself:
```lua
if not isMeditating then
    return { Success = false, Message = "丹药需在打坐时炼化" }
end
```

- [ ] **Step 2: Update ShopUI to pass IsMeditating from BreathUI**

In `ShopUI.local.lua` UseItem click handler:
```lua
-- BEFORE:
ShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = itemKey })
-- AFTER:
ShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = itemKey, IsMeditating = true })
```

Note: This only applies when called from within BreathUI. The ShopUI standalone backpack page should still show items but clicking "使用" from non-meditation context will be rejected by the server.

- [ ] **Step 3: Commit**

---

## Spec Coverage Checklist

- [x] Layout expansion (Task 3)
- [x] Blue cushion (Task 3)
- [x] Bed/sleep area (Task 3)
- [x] Screen/windows/lights (Task 3)
- [x] Prayer altar ceremony UI (Task 7)
- [x] Three-tier prayer options (Task 7)
- [x] Kneel animation (Task 1)
- [x] Breath rhythm meditation (Task 5)
- [x] F key inhale/hold/exhale (Task 5)
- [x] Judgment windows (Task 5)
- [x] Trance layers (Task 5)
- [x] Malice difficulty (Task 5)
- [x] Pill consumption during meditation (Task 5 + Task 8)
- [x] ShopService enforcement (Task 8)
- [x] Sleep peace balance minigame (Task 6)
- [x] Nightmare system (Task 6)
- [x] Once-per-day sleep (Task 2 + DataManager)
- [x] TimeService AdvanceHours (Task 6 server handler)
- [x] AnimationFactory (Task 1)
- [x] HomeEvents RemoteEvent (Task 4)
- [x] Anti-cheat (server validation in each event handler)
- [x] DataManager fields (Task 2)

### Task 5 (continued): BreathUI Complete Steps

- [ ] **Step 2: Implement breath cycle with F key handling**

After Hide(), add the breath phase cycle logic:

```lua
function BreathUI:StartPhase(phaseName)
    if not isActive then return end
    currentPhase = phaseName
    phaseStartTime = tick()
    phaseLabel.Text = phaseName == "INHALE" and "吸气" or (phaseName == "HOLD" and "屏息" or "呼气")
    local duration = phaseTimers[phaseName]
    if malAdjust > 1 then duration = duration / malAdjust end
    local targetSize = (phaseName == "INHALE") and UDim2.new(0, 200, 0, 200)
        or (phaseName == "EXHALE") and UDim2.new(0, 40, 0, 40)
        or UDim2.new(0, 200, 0, 200)
    local tween = TweenService:Create(outerRing,
        TweenInfo.new(duration, Enum.EasingStyle.OutQuad),
        { Size = targetSize }
    )
    tween:Play()
end
```

Handle keyboard input and judgment:

```lua
local fDownConn = UserInputService.InputBegan:Connect(function(input, gp)
    if not isActive or gp then return end
    if input.KeyCode == Enum.KeyCode.F then
        isFPressed = true
        if currentPhase == "INHALE" then
            BreathUI:Judge("INHALE")
            BreathUI:StartPhase("HOLD")
        end
    elseif input.KeyCode == Enum.KeyCode.Escape then
        BreathUI:End()
    end
end)

local fUpConn = UserInputService.InputEnded:Connect(function(input, gp)
    if not isActive or gp then return end
    if input.KeyCode == Enum.KeyCode.F then
        isFPressed = false
        if currentPhase == "EXHALE" then
            BreathUI:Judge("EXHALE")
            BreathUI:StartPhase("INHALE")
        elseif currentPhase == "HOLD" then
            BreathUI:StartPhase("EXHALE")
        end
    end
end)
```

- [ ] **Step 3: Implement judgment + trance layers**

```lua
function BreathUI:Judge(phase)
    local elapsed = tick() - phaseStartTime
    local expected = phaseTimers[phase]
    local adjustedDuration = malAdjust > 1 and (expected / malAdjust) or expected
    local diff = math.abs(elapsed - adjustedDuration)
    local judgment = diff < 0.15 and "perfect" or diff < 0.30 and "precise" or diff < 0.50 and "normal" or "miss"
    local colors = { perfect = Color3.fromRGB(255,255,100), precise = Color3.fromRGB(150,255,150), normal = Color3.fromRGB(200,200,200), miss = Color3.fromRGB(255,100,100) }
    local texts = { perfect = "完美", precise = "精准", normal = "普通", miss = "失误" }
    feedbackLabel.TextColor3 = colors[judgment]
    feedbackLabel.Text = texts[judgment]
    if judgment == "perfect" then
        consecutivePerfect += 1
        if consecutivePerfect % 3 == 0 then
            currentLayer = math.min(3, currentLayer + 1)
            local names = { "", "初定", "入定", "禅定" }
            layerLabel.Text = "层数: " .. currentLayer .. " (" .. names[currentLayer] .. ")"
        end
    else
        consecutivePerfect = 0; currentLayer = 0
        layerLabel.Text = ""
    end
    HomeEvent:FireServer("BreathResult", { Judgment = judgment, Layer = currentLayer })
    task.delay(0.5, function() if feedbackLabel then feedbackLabel.Text = "" end end)
end
```

- [ ] **Step 4: Implement pill backpack panel + server handler**

Populate backpack UI on "BackpackData" event.
Server handler for "BreathResult" and "GetBackpack" actions (add to SceneSetup or a new HomeServer.lua).

- [ ] **Step 5: Implement End function and cleanup**

Stop animation, restore WalkSpeed/AutoRotate, disconnect input events.

- [ ] **Step 6: Commit**

```bash
git add StarterPlayer/StarterPlayerScripts/client/BreathUI.local.lua
git commit -m "feat: add BreathUI meditation minigame with pill panel"
```
