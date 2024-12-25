/obj/item/bodypart/leg/left/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_SERPENTID

/obj/item/bodypart/leg/right/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_SERPENTID


/obj/item/bodypart/foot/carapace
	min_broken_damage = 20
	encased = CARAPACE_ENCASE_WORD

/obj/item/bodypart/foot/carapace/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)

/obj/item/bodypart/foot/right/carapace
	min_broken_damage = 20
	encased = CARAPACE_ENCASE_WORD

/obj/item/bodypart/foot/right/carapace/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)
