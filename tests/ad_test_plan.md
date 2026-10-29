# TowerTock Advertising Test Plan
# Version: 1.0

## Setup

Before running ad tests:
1. Keep `USE_TEST_ADS := true` in `scripts/ad_manager.gd`
2. Use Google's official test rewarded ad unit: `ca-app-pub-3940256099942544/5224354917`
3. Test on a physical Android device with the AdMob plugin installed
4. For editor testing: the ad is simulated with a 5-second delay

---

## AD-01: Editor Simulation (No Plugin)

**Environment:** Godot editor / desktop
**Steps:**
1. Lose all 3 lives
2. Tap Watch Ad to Revive

**Expected:**
- Console shows "AdManager: AdMob plugin not available. Ads will be simulated."
- 2-second delay simulates ad loading
- 3-second delay simulates ad viewing
- Reward callback fires
- Revive granted
- Tower and score preserved

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-02: Ad Pre-loading

**Environment:** Android device with plugin
**Steps:**
1. Launch game
2. Let game run for 3 seconds
3. Check logcat for AdMob events

**Expected:**
- `rewarded_ad_loaded` signal fires within a few seconds
- `AdManager._ad_loaded = true`
- No error messages

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-03: Successful Rewarded Ad — Full Flow

**Environment:** Android device
**Steps:**
1. Start run
2. Deliberately miss 3 times
3. Tap Watch Ad to Revive
4. Watch complete test ad
5. Ad closes automatically

**Expected:**
- State: GAME_OVER → REVIVE_AD_PENDING → REVIVE_AD_SHOWING → REVIVE_RECOVERY → CRANE_MOVING
- `user_earned_reward` fires BEFORE ad closes
- `_on_ad_reward_earned` grants revive
- Lives = 1
- Score unchanged from game over moment
- Tower unchanged

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-04: Ad Dismissed Before Completion

**Steps:**
1. Lose 3 lives
2. Tap Watch Ad
3. Manually dismiss ad (X button) before it completes

**Expected:**
- `rewarded_ad_closed` fires WITHOUT `user_earned_reward`
- `_on_ad_closed` detects no reward was given
- State transitions: REVIVE_AD_SHOWING → GAME_OVER_FINAL
- Final game over displays (no revive option)

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-05: Ad Fails to Load

**Steps:**
1. (Android) Block network
2. Start game
3. Wait for ad load to fail
4. Lose 3 lives

**Expected:**
- `rewarded_ad_failed_to_load` fires
- `_ad_loaded = false`
- Game over screen appears WITHOUT revive button
- OR revive button is hidden/disabled

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-06: Ad Fails to Show

**Steps:**
1. Force ad unavailable (code path test)
2. Player requests revive

**Expected:**
- `ad_failed_to_show` fires
- State: GAME_OVER_FINAL (no crash)
- Player can still Restart or go to Main Menu

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-07: Duplicate Reward Callback

**Steps:**
1. Code inspection of `_on_user_earned_reward`
2. Verify `_reward_callback_received` flag is set before processing

**Expected:**
- Second call to `_on_user_earned_reward` is ignored
- `revive_used_this_run` remains true after first reward
- No second revive granted

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-08: Stale Run ID Guard

**Steps:**
1. Show ad for run ID = N
2. Simulate restart (run ID becomes N+1)
3. Fire reward callback with old run ID = N

**Expected:**
- `_ad_run_id (N) != _current_run_id (N+1)` check triggers
- Reward NOT granted to new run
- Warning logged

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-09: Revive Once Per Run

**Steps:**
1. Use revive successfully
2. Lose all lives again
3. Check game over screen

**Expected:**
- Revive button NOT shown
- `revive_used_this_run = true` prevents second revive

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-10: New Run Clears Revive Flag

**Steps:**
1. After using revive, restart
2. Lose 3 lives

**Expected:**
- Revive button shown again
- `revive_used_this_run = false` after `start_new_run()`

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-11: No Auto-Ads During Play

**Steps:**
1. Play for 5+ minutes
2. Stack 30+ buildings

**Expected:**
- NO advertisement appears automatically
- No interstitials interrupt gameplay
- Only user-requested revive ad shows

**Status:** [ ] PASS  [ ] FAIL  

---

## AD-12: Game State After App Resume from Ad

**Steps:**
1. During rewarded ad, press Home button
2. Return to app

**Expected:**
- Ad state is preserved
- Game does not enter invalid state
- If ad completes: reward fires normally
- If ad dismissed: final game over shown

**Status:** [ ] PASS  [ ] FAIL  

---

## Test Summary

| Test | Scenario | Status |
|------|----------|--------|
| AD-01 | Editor simulation | Pending |
| AD-02 | Ad pre-loading | Pending |
| AD-03 | Full rewarded flow | Pending |
| AD-04 | Ad dismissed early | Pending |
| AD-05 | Ad fails to load | Pending |
| AD-06 | Ad fails to show | Pending |
| AD-07 | Duplicate callback | Pending |
| AD-08 | Stale run ID guard | Pending |
| AD-09 | Revive once per run | Pending |
| AD-10 | New run resets revive | Pending |
| AD-11 | No auto-ads | Pending |
| AD-12 | Resume from ad | Pending |

---

## Notes

- All tests must use Google test ad unit IDs during development
- Never use production ad traffic for testing
- Document actual logcat output for AD-02 through AD-08
- Record device model and Android version for each Android test
