extends Node

@onready var need_icon_drink = preload("res://assets/sprites/ui/icon_drink.png")
@onready var need_icon_energy = preload("res://assets/sprites/ui/icon_energy.png")
@onready var need_icon_hygene = preload("res://assets/sprites/ui/icon_hygene.png")
@onready var need_icon_mood = preload("res://assets/sprites/ui/icon_mood.png")
@onready var need_icon_drunk = preload("res://assets/sprites/ui/icon_drunk.png")

const JOB_BED_BEHAVIOUR = preload("res://scripts/npc/behaviours/job_bed_behaviour.gd")

enum Items {
	BEER_BARREL,
	WISKEY_BOX,
	DRINK,
	WATER_BUCKET,
	WISKEY_BOX_RAW
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
	JUNK,
	DESTILLERY,
	PRISON,
	SAFE,
	OUTHOUSE_CLEANER,
	BED_CLEANER,
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
			
		Enum.Jobs.DESTILLERY:
			return JobDestilleryBehaviour
			
		Enum.Jobs.PRISON:
			return JobPrisonBehaviour

		Enum.Jobs.SAFE:
			return JobSafeBehaviour

		Enum.Jobs.OUTHOUSE_CLEANER:
			return JobOuthouseBehaviour

		Enum.Jobs.BED_CLEANER:
			return JOB_BED_BEHAVIOUR

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
	ENERGY,
}
static func need_to_icon(need : Enum.Need) -> Texture:
	match need:
		Enum.Need.ENERGY:
			return Enum.need_icon_energy
			
		Enum.Need.DRUNKENNESS:
			return Enum.need_icon_drunk
			
	return Enum.need_icon_mood
