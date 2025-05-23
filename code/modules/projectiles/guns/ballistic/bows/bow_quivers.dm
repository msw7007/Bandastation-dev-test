
/obj/item/storage/bag/quiver
	name = "quiver"
	desc = "Holds arrows for your bow. Good, because while pocketing arrows is possible, it surely can't be pleasant."
	icon = 'icons/obj/weapons/bows/quivers.dmi'
	icon_state = "quiver"
	inhand_icon_state = null
	worn_icon_state = "harpoon_quiver"
	storage_type = /datum/storage/bag/quiver

	/// type of arrow the quivel should hold
	var/arrow_path = /obj/item/ammo_casing/arrow

/obj/item/storage/bag/quiver/lesser
	storage_type = /datum/storage/bag/quiver/less

/obj/item/storage/bag/quiver/full/PopulateContents()
	. = ..()
	for(var/i in 1 to 10)
		new arrow_path(src)

/obj/item/storage/bag/quiver/holy
	name = "divine quiver"
	desc = "Holds arrows for your divine bow, where they wait to find their target."
	icon_state = "holyquiver"
	inhand_icon_state = "holyquiver"
	worn_icon_state = "holyquiver"
	arrow_path = /obj/item/ammo_casing/arrow/holy

/obj/item/storage/bag/quiver/holy/PopulateContents()
	. = ..()
	for(var/i in 1 to 10)
		new arrow_path(src)
