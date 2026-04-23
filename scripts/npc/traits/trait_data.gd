extends Resource
class_name TraitData

enum Polarity {
	POSITIVE,
	NEGATIVE,
}

@export var id: String = ""
@export var pair_id: String = ""
@export var trait_name: String = ""
@export_multiline var description: String = ""
@export var polarity: Polarity = Polarity.POSITIVE

func _init(_id: String = "", _pair_id: String = "", _trait_name: String = "", _description: String = "", _polarity: Polarity = Polarity.POSITIVE) -> void:
	id = _id
	pair_id = _pair_id
	trait_name = _trait_name
	description = _description
	polarity = _polarity

func is_positive() -> bool:
	return polarity == Polarity.POSITIVE
