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
	WATER_BUCKET,
	WISKEY_BOX_RAW,
	BROOM,
	MONEY
}

enum Resources {
	MONEY,
	GUEST
}

enum Jobs {
	IDLE,
	BREWERY,
	BAR,
	ENTERTAINMENT,
	WELL,
	BATH,
	JUNK,
	DESTILLERY,
	PRISON,
	SAFE,
	OUTHOUSE_CLEANER,
	BED_CLEANER,
	BROOM_CLEANER,
	BOUNCER,
	WATER_TOWER,
}

static func job_to_behaviour(job : Jobs):
	match job:
		Enum.Jobs.IDLE:
			return IdleBehaviour
		
		Enum.Jobs.BREWERY:
			return JobBreweryBehaviour
			
		Enum.Jobs.BAR:
			return JobBarBehaviour

		Enum.Jobs.ENTERTAINMENT:
			return JobEntertainmentBehaviour
			
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
			return JobBedBehaviour

		Enum.Jobs.BROOM_CLEANER:
			return JobBroomCleanerBehaviour

		Enum.Jobs.BOUNCER:
			return JobBouncerBehaviour

		Enum.Jobs.WATER_TOWER:
			return JobWaterTowerBehaviour

enum ZLayer {
	NPC_OUTSIDE = -500,
	NPC_BEHIND_ROOM_DEEP = -150,
	NPC_BEHIND_ROOM_CONTENT = -50,
	ROOM_CONTENT_BACK = -10,
	ROOM_CONTENT_DEFAULT = 0,
	ROOM_CONTENT_FRONT = 10,
	NPC_DEFAULT = 0,
	PUDDLE = 100,
	DEBUG_OVERLAY = 1000,
}

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
