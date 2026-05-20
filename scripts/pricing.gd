extends Node

# ── Room services ──────────────────────────────────────────────────────────────
# Earned when guests pay to use a room.

const BED_SLEEP_PRICE := 14
# Guest pays per night in the bunkhouse.

const BAR_ITEM_COST := 2
# Base ingredient cost per drink; sale price = ceil(item_cost * 1.5).
# Note: room_bar.gd exposes item_cost as an @export, so this is only the default.

const BATH_SERVICE_PRICE := 6
# Guest pays to use the bathhouse.

const OUTHOUSE_SERVICE_PRICE := 2
# Guest pays to use the outhouse.

const TOILET_SERVICE_PRICE := 3
# Guest pays to use the indoor toilet stall.

const INFIRMARY_SERVICE_PRICE := 18
# Guest or worker pays for treatment at the infirmary.

# ── Outdoor services ───────────────────────────────────────────────────────────

const HORSE_POST_TIE_FEE := 8
# Guest pays when they collect their horse from a tied post.

# ── Gambling ───────────────────────────────────────────────────────────────────

const GAMBLING_CHEAT_FEE_MULTIPLIER := 3.0
# When a watcher catches a cheater the fee charged = pot * this multiplier.

# ── Law & order ────────────────────────────────────────────────────────────────

const DRUNK_FIGHT_FINE := 2
# Fine applied to each brawler after a drunken fight; collected on arrest.

const WANTED_BOUNTY_MIN := 10
# Smallest bounty placed on a randomly generated wanted poster.

const WANTED_BOUNTY_MAX := 50
# Largest bounty placed on a randomly generated wanted poster (steps of 10).

# ── Workers ────────────────────────────────────────────────────────────────────
# These are costs, not income, but kept here for holistic balance tuning.

const WORKER_BASE_SALARY := 6
# Daily salary deducted per assigned worker.

const WORKER_HIRE_BASE := 25
# Base one-time hiring cost before trait adjustments.

const WORKER_HIRE_PER_POSITIVE_TRAIT := 15
# Added to hiring cost for each positive trait.

const WORKER_HIRE_PER_NEGATIVE_TRAIT := -5
# Subtracted from hiring cost for each negative trait.

# ── Water tower ────────────────────────────────────────────────────────────────

const WATER_TOWER_RAISE_COST := 25
# One-time cost to raise the water tower and increase its capacity.

# ── Special encounters ─────────────────────────────────────────────────────────
# Positive = player earns money; negative = player spends money.

const ENCOUNTER_SHERIFF_BRIBE := -40
# Cost to bribe the sheriff into dropping his search.

const ENCOUNTER_BARBER_SURGEON_HIRE := -50
# Upfront payment to bring the barber surgeon into the saloon.

const ENCOUNTER_ENTERTAINER_HIRE := -70
# Upfront payment to bring the entertainer into the saloon.

const ENCOUNTER_PRODUCT_PLACEMENT_BASIC := 99
# Revenue from accepting the product placement sign deal.

const ENCOUNTER_PRODUCT_PLACEMENT_NEGOTIATED := 200
# Revenue from successfully negotiating a higher product placement fee.

# ── Tutorial quest rewards ─────────────────────────────────────────────────────

const QUEST_REWARD_CLEANUP := 10
const QUEST_REWARD_BUILD_BAR := 10
const QUEST_REWARD_SERVE_GUESTS := 10
const QUEST_REWARD_BUILD_TABLE := 10
