extends Node


@onready var need_icon_drink = preload("res://assets/sprites/ui/icon_drink.png")
@onready var need_icon_energy = preload("res://assets/sprites/ui/icon_energy.png")
@onready var need_icon_hygene = preload("res://assets/sprites/ui/icon_hygene.png")
@onready var need_icon_mood = preload("res://assets/sprites/ui/icon_mood.png")
@onready var need_icon_drunk = preload("res://assets/sprites/ui/icon_drunk.png")

@onready var placement_icon_above_or_below = preload("res://assets/sprites/ui/2x/icon_above_and_below.png")
@onready var placement_icon_above_ground = preload("res://assets/sprites/ui/2x/icon_above.png")
@onready var placement_icon_below_ground = preload("res://assets/sprites/ui/2x/icon_below_ground.png")


enum Items {
	BEER_BARREL,
	WISKEY_BOX,
	DRINK,
	WATER_BUCKET,
	WISKEY_BOX_RAW,
	BROOM,
	WOOD,
	MONEY,
	CRATE
}

enum Resources {
	MONEY,
	GUEST
}

enum NpcStatus {
	# Health
	INJURED,
	WELL_TREATED,
	BADLY_TREATED,
	# Criminal / legal
	MARKED_FOR_ARREST,
	ARRESTED,
	KNOWN_FUGITIVE,
	CARRYING_LOOT,
	HAS_OUTSTANDING_FINE,
}

enum RoomType {
	INFRASTRUCTURE,
	BEVERAGES,
	SAFETY,
	ENTERTAINMENT,
}

enum PlacementLimit {
	ABOVE_OR_BELOW,
	ABOVE_GROUND,
	BELOW_GROUND,
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
	TRADING_OFFICE,
	STOVE_KEEPER,
	DIGGING,
	GAMBLING_WATCHER,
	DOCTOR,
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

		Enum.Jobs.TRADING_OFFICE:
			return JobTradingOfficeBehaviour

		Enum.Jobs.STOVE_KEEPER:
			return JobStoveKeeperBehaviour

		Enum.Jobs.DIGGING:
			return JobDiggingBehaviour

		Enum.Jobs.GAMBLING_WATCHER:
			return JobGamblingWatcherBehaviour

		Enum.Jobs.DOCTOR:
			return JobDoctorBehaviour

enum ZLayer {
	NPC_IN_OUTHOUSE = -620,
	NPC_OUTSIDE = -500,
	INFRASTRUCTURE_PIPES = -190,
	NPC_FAR_BACK = -150,
	NPC_BEHIND_CONTENT = -50,
	NPC_DEFAULT = 0,
	NPC_DRAGGED = 4090,
	INFO_LAYER
}

enum RequestStatus {
	OPEN,
	IN_PROGRESS,
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

enum EquipmentSlot {
	WEAPON,
}

enum FireRate {
	SLOW,
	MEDIUM,
	FAST,
}
func placement_limit_to_icon(limit : Enum.PlacementLimit) -> Texture:
	match limit:
		Enum.PlacementLimit.ABOVE_OR_BELOW:
			return Enum.placement_icon_above_or_below
		Enum.PlacementLimit.ABOVE_GROUND:
			return Enum.placement_icon_above_ground
		Enum.PlacementLimit.BELOW_GROUND:
			return Enum.placement_icon_below_ground
	return Enum.placement_icon_above_or_below

static func need_to_icon(need : Enum.Need) -> Texture:
	match need:
		Enum.Need.ENERGY:
			return Enum.need_icon_energy
			
		Enum.Need.DRUNKENNESS:
			return Enum.need_icon_drunk
			
	return Enum.need_icon_mood
