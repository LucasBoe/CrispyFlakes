extends RefCounted

## Demo campaign's win/lose/goal-completion Callables, kept in code (not the
## .tres) since Resources can't cleanly hold arbitrary bound Callables.
## ScenarioHandler loads this via CampaignScenarioData.conditions_script.

const GOAL_MONEY_TARGET := 150

func get_goal_conditions() -> Dictionary:
	return {
		"earn_money_goal": func() -> bool: return _has_money(GOAL_MONEY_TARGET),
	}

func get_win_conditions() -> Array[Dictionary]:
	return [
		{
			"condition": func() -> bool: return _has_money(GOAL_MONEY_TARGET),
			"description": "Grow the saloon's takings to $%d." % GOAL_MONEY_TARGET,
		},
	]

func get_lose_conditions() -> Array[Dictionary]:
	return []

func _has_money(amount: int) -> bool:
	return int(ResourceHandler.resources.get(Enum.Resources.MONEY, 0)) >= amount
