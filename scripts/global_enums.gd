extends Node

@onready var need_icon_drink = preload("res://assets/sprites/ui/icon_drink.png")
@onready var need_icon_energy = preload("res://assets/sprites/ui/icon_energy.png")
@onready var need_icon_hygene = preload("res://assets/sprites/ui/icon_hygene.png")
@onready var need_icon_mood = preload("res://assets/sprites/ui/icon_mood.png")
@onready var need_icon_drunk = preload("res://assets/sprites/ui/icon_drunk.png")

enum Items {
	BEER_BARREL,
	WISKEY_BOX,
	DRINK,
	WATER_BUCKET
}

enum Resources {
	MONEY,
	GUEST
}

enum Jobs {
	IDLE,
	BREWERY,
	BAR,
	WELL,
	BATH,
	JUNK
}

static func job_to_behaviour(job : Jobs):
	match job:
		Enum.Jobs.IDLE:
			return IdleBehaviour
		
		Enum.Jobs.BREWERY:
			return JobBreweryBehaviour
			
		Enum.Jobs.BAR:
			return JobBarBehaviour
			
		Enum.Jobs.WELL:
			return JobWellBehaviour
			
		Enum.Jobs.BATH:
			return JobBathBehaviour
			
		Enum.Jobs.JUNK:
			return JobJunkBehaviour

enum RequestStatus {
	OPEN,
	TIMEOUT,
	FULFILLED
}

enum Need {
	SATISFACTION,
	STAY_DURATION,
	PASSIVE_SATISFACTION_LOSS,
	DRUNKENNESS,
}
static func need_to_icon(need : Enum.Need) -> Texture:
	match need:
			
		Enum.Need.DRUNKENNESS:
			return Enum.need_icon_drunk
			
	return Enum.need_icon_mood
