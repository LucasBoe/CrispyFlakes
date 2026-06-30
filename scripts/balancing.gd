extends Node
class_name Balancing

static var GUEST_SPAWN_BASE_RATE = 2
static var GUEST_SPAWN_CURRENT_GUEST_COUNT_EFFECT = 0.1 # for each current guest, x new guests spawn per minute
static var GUEST_SPAWN_MOOD_EFFECT_STRENGTH = 0.9 # (base rate + count effect) * ((1.0 - 0.5) + (x * 0.5) - x = 0 > no effect x > full multiplication (e.g. 25% mood > only 25% of guests spawn)

static var GUEST_DIRT_SPAWN_CHANCE = 0.01
static var GUEST_DIRT_DROP_CHECK_INTERVAL := 1.6

static var GUEST_SATISFACTION_DECAY_RATE := 0.15       # how fast satisfaction decays toward 0 per minute

static var GUEST_ENERGY_LOSS_PER_MINUTE := 0.35        # base energy drain per minute
static var GUEST_ENERGY_DRUNK_MULTIPLIER := 0.35       # extra energy drain per unit of drunkenness
static var GUEST_ENERGY_SITTING_MULTIPLIER := 0.25     # multiplier when seated so you are encounraged to build tables
