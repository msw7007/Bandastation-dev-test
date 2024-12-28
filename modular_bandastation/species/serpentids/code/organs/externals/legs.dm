/obj/item/bodypart/leg/left/serpentid
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	limb_id = SPECIES_SERPENTID
	var/min_broken_damage = 20

/obj/item/bodypart/leg/left/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)

/obj/item/bodypart/leg/right/serpentid
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	limb_id = SPECIES_SERPENTID
	var/min_broken_damage = 20

/obj/item/bodypart/leg/right/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)
