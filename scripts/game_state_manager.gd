extends Node

## GameStateManager — Central finite state machine for TowerTock
## Manages all game states and valid transitions.

signal state_changed(old_state: GameState, new_state: GameState)
signal game_over_triggered
signal run_started
signal revive_granted

enum GameState {
	INITIALIZING,
	MAIN_MENU,
	READY,
	CRANE_MOVING,
	BUILDING_RELEASED,
	BUILDING_FALLING,
	BUILDING_LANDING,
	RESOLVING_PLACEMENT,
	PREPARING_NEXT_BUILDING,
	PAUSED,
	GAME_OVER,
	REVIVE_AD_PENDING,
	REVIVE_AD_SHOWING,
	REVIVE_RECOVERY,
	GAME_OVER_FINAL
}

## Valid transitions map
const VALID_TRANSITIONS: Dictionary = {
	GameState.INITIALIZING:            [GameState.MAIN_MENU, GameState.READY, GameState.CRANE_MOVING],
	GameState.MAIN_MENU:               [GameState.READY, GameState.CRANE_MOVING],
	GameState.READY:                   [GameState.CRANE_MOVING, GameState.MAIN_MENU, GameState.READY],
	GameState.CRANE_MOVING:            [GameState.BUILDING_RELEASED, GameState.PAUSED, GameState.GAME_OVER, GameState.READY, GameState.MAIN_MENU],
	GameState.BUILDING_RELEASED:       [GameState.BUILDING_FALLING, GameState.READY, GameState.MAIN_MENU],
	GameState.BUILDING_FALLING:        [GameState.BUILDING_LANDING, GameState.RESOLVING_PLACEMENT, GameState.PAUSED, GameState.READY, GameState.MAIN_MENU],
	GameState.BUILDING_LANDING:        [GameState.RESOLVING_PLACEMENT, GameState.READY, GameState.MAIN_MENU],
	GameState.RESOLVING_PLACEMENT:     [GameState.PREPARING_NEXT_BUILDING, GameState.CRANE_MOVING, GameState.GAME_OVER, GameState.READY, GameState.MAIN_MENU],
	GameState.PREPARING_NEXT_BUILDING: [GameState.CRANE_MOVING, GameState.READY, GameState.MAIN_MENU],
	GameState.PAUSED:                  [GameState.CRANE_MOVING, GameState.BUILDING_FALLING, GameState.MAIN_MENU, GameState.READY],
	GameState.GAME_OVER:               [GameState.REVIVE_AD_PENDING, GameState.REVIVE_AD_SHOWING, GameState.REVIVE_RECOVERY, GameState.GAME_OVER_FINAL, GameState.READY, GameState.MAIN_MENU],
	GameState.REVIVE_AD_PENDING:       [GameState.REVIVE_AD_SHOWING, GameState.GAME_OVER_FINAL, GameState.GAME_OVER, GameState.READY, GameState.MAIN_MENU],
	GameState.REVIVE_AD_SHOWING:       [GameState.REVIVE_RECOVERY, GameState.GAME_OVER_FINAL, GameState.GAME_OVER, GameState.READY, GameState.MAIN_MENU],
	GameState.REVIVE_RECOVERY:         [GameState.CRANE_MOVING, GameState.READY, GameState.MAIN_MENU],
	GameState.GAME_OVER_FINAL:         [GameState.READY, GameState.MAIN_MENU],
}

var current_state: GameState = GameState.INITIALIZING
var previous_state: GameState = GameState.INITIALIZING
var _state_before_pause: GameState = GameState.CRANE_MOVING

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func transition_to(new_state: GameState) -> bool:
	if new_state == current_state:
		return true

	var allowed: Array = VALID_TRANSITIONS.get(current_state, [])
	if new_state not in allowed:
		push_warning("GameStateManager: Invalid transition from %s to %s" % [
			GameState.keys()[current_state], GameState.keys()[new_state]
		])
		return false

	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)

	match current_state:
		GameState.GAME_OVER:
			game_over_triggered.emit()
		GameState.READY:
			run_started.emit()
		GameState.REVIVE_RECOVERY:
			revive_granted.emit()

	return true

func is_in_state(state: GameState) -> bool:
	return current_state == state

func is_gameplay_active() -> bool:
	return current_state in [
		GameState.CRANE_MOVING,
		GameState.BUILDING_RELEASED,
		GameState.BUILDING_FALLING,
		GameState.BUILDING_LANDING,
		GameState.RESOLVING_PLACEMENT,
		GameState.PREPARING_NEXT_BUILDING
	]

func get_state_before_pause() -> GameState:
	return _state_before_pause

func record_state_before_pause() -> void:
	_state_before_pause = current_state
