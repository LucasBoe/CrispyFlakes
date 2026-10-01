extends RefCounted

# the goal key must be "earn_money_goal"
func get_goal_conditions() -> Dictionary:
	return {
		"earn_money_goal": func() -> bool: return _has_goal_money(),
	}

func get_win_conditions() -> Array[Dictionary]:
	return [
		{
			"condition": func() -> bool: return _has_goal_money(),
			"description": "Grow the saloon's takings to $%d." % _goal(),
		},
	]

func get_lose_conditions() -> Array[Dictionary]:
	return []

func _goal() -> int:
	var campaign := ScenarioHandler.get_current_scenario() as CampaignScenarioData
	return campaign.money_goal if campaign != null else 0

func _has_goal_money() -> bool:
	return int(MoneyHandler.total_stored()) >= _goal()
