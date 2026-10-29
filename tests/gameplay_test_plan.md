# TowerTock Gameplay Test Plan
# Version: 1.0
# Status: READY FOR EXECUTION

## Test Environment
- Engine: Godot 4.3+
- Platform: Desktop (editor) and Android device
- Build type: Debug (editor), Release (Android)

---

## Section 1: Core Gameplay Tests

### TC-01: New Run Initialization
**Steps:**
1. Launch the game
2. Observe main menu
3. Press Play

**Expected:**
- Main menu displays TowerTock logo, best score, and Play button
- Pressing Play transitions to game scene
- Crane appears at top of screen and begins moving
- Lives show 3 hearts
- Score shows 0

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-02: Crane Movement
**Steps:**
1. Start a new run
2. Observe crane for 10+ seconds

**Expected:**
- Crane carriage moves smoothly left and right
- Movement reverses direction at the rails
- No teleporting or flickering
- Cable connects carriage to building at all times
- Building swings naturally (pendulum effect)

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-03: Building Release
**Steps:**
1. During CRANE_MOVING state, tap the screen

**Expected:**
- Building detaches from crane immediately
- Building does NOT continue following crane horizontally
- Building falls straight down under gravity
- Cable disappears after release
- State transitions: CRANE_MOVING → BUILDING_RELEASED → BUILDING_FALLING

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-04: Double Tap Prevention
**Steps:**
1. Tap screen to release building
2. Immediately tap screen again

**Expected:**
- Only ONE building falls
- Second tap has no effect
- No duplicate score awards

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-05: Perfect Placement
**Steps:**
1. Drop building directly centered over platform
2. Observe placement feedback

**Expected:**
- Building lands centered on platform
- "PERFECT" or highest quality feedback shown
- Maximum points awarded
- Combo counter increases
- sfx_perfect plays
- No trimming of building width

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-06: Partial Overlap
**Steps:**
1. Drop building partially off the side of the tower
2. Observe building trimming

**Expected:**
- Only the overlapping portion remains
- Building is trimmed to the supported width
- Visual geometry matches actual width
- Score reflects partial placement
- Building width decreases for next placement

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-07: Complete Miss
**Steps:**
1. Release building far to the side of the tower

**Expected:**
- Building does NOT land on tower
- Miss sound plays
- Lives reduce by exactly 1 (from 3 to 2)
- Tower does NOT gain height
- Score does NOT increase
- Combo resets to 0
- New building appears after miss animation

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-08: Single Life Deduction Per Miss
**Steps:**
1. Miss deliberately
2. Verify lives count

**Expected:**
- Lives go from N to N-1, never N-2
- Miss callback fires exactly once

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-09: Three Misses → Game Over
**Steps:**
1. Miss three times deliberately

**Expected:**
- After 3rd miss, lives reach 0
- Game Over screen appears
- Gameplay stops
- No new buildings appear
- Score displays correctly

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-10: Camera Tracking
**Steps:**
1. Stack 15+ buildings

**Expected:**
- Camera follows tower upward smoothly
- Crane, active building, and tower top remain visible
- No sudden jumps
- Transition is gradual

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-11: Pause and Resume
**Steps:**
1. During gameplay, press pause button
2. Verify pause state
3. Press Resume

**Expected:**
- Crane stops moving
- Building freezes in place
- Pause menu displays Resume, Restart, Main Menu
- Pressing Resume continues exactly where paused
- Scoring timers do not tick while paused

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-12: Restart
**Steps:**
1. During game over, press Restart

**Expected:**
- New run begins with fresh state
- Lives reset to 3
- Score resets to 0
- Combo resets
- Tower is cleared
- revive_used_this_run = false
- AdManager begins new run ID

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-13: Main Menu Navigation
**Steps:**
1. From game over, press Main Menu
2. From pause, press Main Menu

**Expected:**
- Main menu scene loads
- Best score displays correctly
- Audio plays

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-14: High Score Persistence
**Steps:**
1. Achieve a high score
2. Close and reopen the game

**Expected:**
- High score displayed on main menu matches previous run
- Save file exists at user://towertock_save.cfg

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

### TC-15: Difficulty Progression
**Steps:**
1. Stack 20+ buildings

**Expected:**
- Crane visibly moves faster over time
- Pendulum swing amplitude increases
- Game remains fair and not unplayably fast

**Status:** [ ] PASS  [ ] FAIL  
**Notes:** ___

---

## Section 2: Stability Tests

### TC-16: No Building Penetration
**Expected:**
- No building passes through another building
- No building passes through the platform

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-17: No Floating Buildings
**Expected:**
- Each building rests exactly at the calculated position
- No gaps appear between stacked buildings

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-18: No Duplicate Buildings
**Expected:**
- Only one falling building exists at a time
- No ghost buildings appear

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-19: No Stuck States
**Steps:**
1. Play through 50+ placements
2. Mix perfect, partial, and miss placements

**Expected:**
- Game never gets stuck waiting for state transition
- New building always appears within 2 seconds of previous landing

**Status:** [ ] PASS  [ ] FAIL  

---

## Section 3: Rewarded Ad Tests

### TC-20: Revive Option Appears
**Steps:**
1. Lose all 3 lives

**Expected:**
- Game Over screen shows "Watch Ad to Revive" button
- Button is clearly labeled and optional
- Restart and Main Menu also available

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-21: Successful Revive
**Steps:**
1. Lose all 3 lives
2. Tap "Watch Ad to Revive"
3. Watch the complete ad (simulated in editor)

**Expected:**
- Ad loads and displays
- After ad completes: reward callback fires
- Game resumes with 1 life
- Tower height preserved
- Score preserved
- revive_used_this_run = true

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-22: Ad Closed Without Reward
**Steps:**
1. Lose all 3 lives
2. Tap "Watch Ad to Revive"
3. Close ad before it completes

**Expected:**
- No revive granted
- Final game over shown
- Game does NOT crash

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-23: Revive Used Only Once Per Run
**Steps:**
1. Revive successfully
2. Lose again in same run
3. Observe game over screen

**Expected:**
- "Watch Ad to Revive" button is NOT shown
- Only Restart and Main Menu available

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-24: New Run Resets Revive Eligibility
**Steps:**
1. Use revive
2. Restart game
3. Lose all lives again

**Expected:**
- Revive button appears again
- revive_used_this_run = false at start of new run

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-25: Ad Failure Handling
**Steps:**
1. (Android) Enable airplane mode
2. Lose all lives
3. Tap Watch Ad

**Expected:**
- Ad fails gracefully
- Player shown appropriate message or final game over
- Game does NOT freeze or crash
- Restart still works

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-26: No Duplicate Reward
**Steps:**
1. Simulate duplicate reward callback (code inspection)

**Expected:**
- Second reward callback is ignored
- `_reward_callback_received` guard prevents double revive

**Status:** [ ] PASS  [ ] FAIL  

---

## Section 4: Android Device Tests

### TC-27: Installation and Launch
**Steps:**
1. Install debug APK on Android device
2. Launch app

**Expected:**
- App launches without crash
- Portrait orientation enforced
- Main menu appears

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-28: Touch Input
**Expected:**
- Tap accurately releases building
- Touch targets on buttons are large enough
- No accidental taps misrouted

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-29: App Backgrounding
**Steps:**
1. During gameplay, press Home button
2. Reopen app

**Expected:**
- Game resumes correctly (or shows appropriate state)
- Audio resumes correctly
- No crash on resume

**Status:** [ ] PASS  [ ] FAIL  

---

### TC-30: Network Unavailable
**Steps:**
1. Enable airplane mode
2. Play game
3. Try to use revive

**Expected:**
- Core gameplay works without network
- Revive gracefully shows unavailable message
- No crash

**Status:** [ ] PASS  [ ] FAIL  

---

## Test Summary

| Section | Tests | Passed | Failed | Pending |
|---------|-------|--------|--------|---------|
| Core Gameplay | 15 | | | 15 |
| Stability | 4 | | | 4 |
| Rewarded Ads | 7 | | | 7 |
| Android | 4 | | | 4 |
| **Total** | **30** | | | **30** |

---

## Known Issues / Notes

_Document issues found during testing here._
