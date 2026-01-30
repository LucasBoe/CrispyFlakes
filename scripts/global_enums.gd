extends Node

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

enum RequestStatus {
	OPEN,
	TIMEOUT,
	FULFILLED
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
