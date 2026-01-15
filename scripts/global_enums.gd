extends Node

enum Items {
	WISKEY_BARREL,
	WISKEY_DRINK,
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
	BATH
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
