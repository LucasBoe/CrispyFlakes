extends RoomStorageBase
class_name RoomAgingCellar

const CELLAR_MULTIPLIER = 2.0

func try_receive(item : Item) -> bool:
	var received = super.try_receive(item)
	if received:
		item.aging_multiplier = CELLAR_MULTIPLIER
	return received

func take(itemType : Enum.Items) -> Item:
	var item = super.take(itemType)
	if item != null:
		item.aging_multiplier = 1.0
	return item

