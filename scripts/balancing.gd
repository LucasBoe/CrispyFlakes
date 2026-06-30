extends Node
class_name Balancing

static var GUEST_SPAWN_BASE_RATE = 3.0
static var GUEST_SPAWN_CURRENT_GUEST_COUNT_EFFECT = 0.1 # for each current guest, x new guests spawn per minute
static var GUEST_SPAWN_SATISFACTION_EFFECT_STRENGTH = 0.5 # (base rate + count effect) * ((1.0 - 0.5) + (x * 0.5) - x = 0 > no effect x > full multiplication (e.g. 25% satisfaction > only 25% of guests spawn)

static var GUEST_DIRT_SPAWN_CHANCE = 0.03
static var GUEST_DIRT_DROP_CHECK_INTERVAL := 1.6
