extends Node

## AdManager — Google AdMob rewarded video integration for TowerTock
##
## SETUP INSTRUCTIONS:
##   1. Install the GodotAdMob plugin for Godot 4 from:
##      https://github.com/Shin-NiL/Godot-Android-Admob-Plugin
##      OR use the Godot AdMob Android plugin available on AssetLib.
##   2. Place the plugin files in android/plugins/
##   3. Enable the plugin in Export → Android → Plugins
##   4. Replace ADMOB_APP_ID below with your real AdMob App ID from:
##      https://apps.admob.com/
##   5. Replace REWARDED_AD_UNIT_ID with your real ad unit ID for production.
##   6. Keep USE_TEST_ADS = true until ready for production release.
##
## NEVER commit production ad IDs to public source control.
## NEVER use production IDs during development or testing.

signal ad_loaded
signal ad_failed_to_load(error_code: int)
signal ad_shown
signal reward_earned(reward_type: String, reward_amount: int)
signal ad_closed
signal ad_failed_to_show(error_code: int)

## ── Configuration ──────────────────────────────────────────────
## Set to false ONLY when deploying to production with real IDs
const USE_TEST_ADS := true

## Google's official test rewarded ad unit (always safe during development)
const TEST_REWARDED_AD_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"

## TODO: Replace with your production AdMob App ID
## Format: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX
const PRODUCTION_ADMOB_APP_ID := "ca-app-pub-REPLACE_WITH_YOUR_APP_ID"

## TODO: Replace with your production rewarded ad unit ID
const PRODUCTION_REWARDED_AD_UNIT_ID := "ca-app-pub-REPLACE_WITH_YOUR_AD_UNIT"

## ── Runtime state ──────────────────────────────────────────────
var _admob_plugin: Object = null
var _is_plugin_available := false
var _ad_loaded := false
var _ad_showing := false
var _reward_callback_received := false
var _current_run_id := 0
var _ad_run_id := -1  # Run ID for which the ad was shown

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_plugin()

func _init_plugin() -> void:
	if Engine.has_singleton("AdMob"):
		_admob_plugin = Engine.get_singleton("AdMob")
		_is_plugin_available = true
		_connect_signals()
		push_print("AdManager: AdMob singleton found and connected.")
	else:
		push_warning("AdManager: AdMob plugin not available. Ads will be simulated (editor/desktop only).")
		_is_plugin_available = false

func _connect_signals() -> void:
	if not _admob_plugin:
		return
	# Connect AdMob plugin signals (signal names vary by plugin version — check plugin docs)
	if _admob_plugin.has_signal("rewarded_ad_loaded"):
		_admob_plugin.rewarded_ad_loaded.connect(_on_rewarded_loaded)
	if _admob_plugin.has_signal("rewarded_ad_failed_to_load"):
		_admob_plugin.rewarded_ad_failed_to_load.connect(_on_rewarded_failed_to_load)
	if _admob_plugin.has_signal("rewarded_ad_opened"):
		_admob_plugin.rewarded_ad_opened.connect(_on_rewarded_opened)
	if _admob_plugin.has_signal("rewarded_ad_closed"):
		_admob_plugin.rewarded_ad_closed.connect(_on_rewarded_closed)
	if _admob_plugin.has_signal("rewarded_ad_failed_to_show"):
		_admob_plugin.rewarded_ad_failed_to_show.connect(_on_rewarded_failed_to_show)
	if _admob_plugin.has_signal("user_earned_reward"):
		_admob_plugin.user_earned_reward.connect(_on_user_earned_reward)

## ── Public API ─────────────────────────────────────────────────

## Call at game start and after each ad display to pre-load
func load_rewarded_ad() -> void:
	_ad_loaded = false
	_reward_callback_received = false

	if not _is_plugin_available:
		# Simulate a successful load after a short delay (editor/desktop mode)
		await _simulate_delay(1.5)
		_ad_loaded = true
		ad_loaded.emit()
		return

	var unit_id := TEST_REWARDED_AD_UNIT_ID if USE_TEST_ADS else PRODUCTION_REWARDED_AD_UNIT_ID
	_admob_plugin.load_rewarded_ad(unit_id)

## Returns true if a rewarded ad is ready to show
func is_rewarded_ad_available() -> bool:
	return _ad_loaded and not _ad_showing

## Show the rewarded ad. run_id must match the current run.
func show_rewarded_ad(run_id: int) -> void:
	if not is_rewarded_ad_available():
		push_warning("AdManager: show_rewarded_ad called but no ad is ready.")
		ad_failed_to_show.emit(-1)
		return
	if _ad_showing:
		push_warning("AdManager: Ad already showing.")
		return

	_reward_callback_received = false
	_ad_run_id = run_id
	_ad_showing = true

	if not _is_plugin_available:
		# Simulate the ad in editor/desktop mode
		_simulate_rewarded_ad()
		return

	_admob_plugin.show_rewarded_ad()

## Register a new run (increments run ID, resets ad state)
func begin_new_run() -> void:
	_current_run_id += 1
	_ad_run_id = -1
	_reward_callback_received = false
	load_rewarded_ad()

func get_current_run_id() -> int:
	return _current_run_id

## ── Plugin Callbacks ───────────────────────────────────────────

func _on_rewarded_loaded() -> void:
	_ad_loaded = true
	ad_loaded.emit()

func _on_rewarded_failed_to_load(error_code: int) -> void:
	_ad_loaded = false
	ad_failed_to_load.emit(error_code)
	push_warning("AdManager: Rewarded ad failed to load. Code: %d" % error_code)

func _on_rewarded_opened() -> void:
	ad_shown.emit()

func _on_rewarded_closed() -> void:
	_ad_showing = false
	_ad_loaded = false
	ad_closed.emit()
	# Reload for next potential use
	load_rewarded_ad()

func _on_rewarded_failed_to_show(error_code: int) -> void:
	_ad_showing = false
	ad_failed_to_show.emit(error_code)
	push_warning("AdManager: Rewarded ad failed to show. Code: %d" % error_code)

func _on_user_earned_reward(reward_type: String, reward_amount: int) -> void:
	# Guard: only process if this is the run we showed the ad for
	if _ad_run_id != _current_run_id:
		push_warning("AdManager: Reward callback run_id mismatch — ignoring stale callback.")
		return
	# Guard: only process reward once per ad display
	if _reward_callback_received:
		push_warning("AdManager: Duplicate reward callback ignored.")
		return
	_reward_callback_received = true
	reward_earned.emit(reward_type, reward_amount)

## ── Editor/Desktop Simulation ──────────────────────────────────

func _simulate_rewarded_ad() -> void:
	await _simulate_delay(2.0)
	ad_shown.emit()
	# Simulate user completing the ad and earning reward
	await _simulate_delay(3.0)
	_on_user_earned_reward("revive", 1)
	await _simulate_delay(0.5)
	_on_rewarded_closed()

func _simulate_delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

static func push_print(msg: String) -> void:
	print("[AdManager] " + msg)
