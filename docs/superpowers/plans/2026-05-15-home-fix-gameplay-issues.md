# Home 场景体验修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Fix 6 gameplay issues in the Home scene: spawn position, ESC key conflicts, entrance guidance hints, bed redesign, breathing circle timing, animation confirmation.

**Architecture:** Modify SceneSetup (Spawn+bed+layout+hints), modify BreathUI/SleepUI/PrayerUI (remove ESC, remove ESC hints), do NOT touch AnimationFactory (already working).

---

### Task 1: Fix Spawn Position (Root Cause)

**Problem:** Home spawn position `(-500, 3, 0)` lands directly on meditation cushion at `(-500, 1, 0)`, triggering `Touched` → BreathUI → Humanoid.WalkSpeed=0 → can't move.

**Fix:** Move spawn to entrance area, away from all interaction zones. Put it at the right side near the entrance, so player can see the whole room.

**Files:**
- Modify: `ReplicatedStorage/Shared/Config/SceneConfig.luau`

- [ ] **Change spawn from (-500, 3, 0) to (-500, 1, -6)** (front of the house, away from all interaction pads)

### Task 2: Remove All ESC Key Usage

**Problem:** ESC conflicts with Studio's built-in ESC (menu/shortcut stop). User says "不要用esc键，删掉相关提示".

**Files:**
- Modify: `StarterPlayer/StarterPlayerScripts/client/BreathUI.local.lua`
- Modify: `StarterPlayer/StarterPlayerScripts/client/SleepUI.local.lua`

**Changes per file:**

**BreathUI:** (2 changes)
1. Line 173 (`elseif input.KeyCode == Enum.KeyCode.Escape then`) → delete the ESC branch
2. Line 489-498 (`按 Esc 结束打坐` hint text) → delete or replace with "按 F 结束打坐"

**SleepUI:** (1 change)
1. Line 214 (`elseif input.KeyCode == Enum.KeyCode.Escape then`) → delete the ESC branch

**PrayerUI and HomeServer:** No ESC usage found, OK.

- [ ] **Delete ESC key branch in BreathUI InputBegan**
- [ ] **Change "按 Esc" hint to "按 F" in BreathUI**
- [ ] **Delete ESC key branch in SleepUI InputBegan**

### Task 3: Redesign Bed — Move to Right Side, Bigger, Realistic

**Problem:** Bed is at X=-12 (left side), looks small and basic. User wants it on the RIGHT side, bigger and realistic, character can lie on it.

**Changes needed:**
1. SceneSetup.server.lua: Remove old bed at X=-12
2. Add new large bed at X=15
3. Expand scene if needed (current W=50 is -24 ~ +24, new bed at X=15 needs space)

**Layout plan:**
```
-24      -16         -8        0          8          15        +24
  |  祈福区  |  屏风    |  打坐区  |  休闲区  |  ★大床★  |
  |  香炉    |  隔断    |  蒲团    |  茶具    |  真实床   |
  |  药架    |          |  地毯    |  挂画    |  卧榻     |
```

**Bed design (large, realistic):**
- Base/mattress: 6x0.5x5 (big enough)
- Pillow: 1x0.3x2 at one end
- Bed frame (headboard): taller decorative wall piece at X=19
- Bed legs: 4 decor cylinders at corners
- Blanket/quilt: slightly different color on top
- Location: X=15, Z=0 center

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Move bed from X=-12 to X=15, build larger realistic bed**
- [ ] **Shift prayer area more left to accommodate layout**

### Task 4: Add Entrance Guidance Hints

**Problem:** No clear guidance on entering Home. Player doesn't know left=prayer, center=meditation, right=sleep/bed.

**Hint boards at spawn area:**
- One big welcome hint: "家 — 左走祈福 | 中走打坐 | 右走大床睡觉"
- At X=-16: "祈福台" hint
- At X=0: "打坐炼化" hint (already exists but refine)
- At X=15: "大床睡觉" hint

Remove the old hints that mention ESC.

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Add entrance guidance hint board**
- [ ] **Refine zone-specific hint boards (remove ESC mentions)**

### Task 5: Breathing Circle Only on Meditation Choice

**Problem:** Breathing circle shows on spawn because spawn triggers cushion Touched. Fixed by Task 1 (spawn fix). Also ensure:

- BreathUI only shows when player walks to cushion and touches it
- The current `Touched → StartMeditation` flow is correct
- No auto-trigger on scene load

**Verification:** After Task 1 spawn fix, player spawns away from cushion. Only walking to cushion at X=0 triggers BreathUI.

**Files:** No code changes needed (already correct logic, spawn fix is the root cause).

- [ ] **Verify spawn fix resolves auto-BreathUI trigger**
