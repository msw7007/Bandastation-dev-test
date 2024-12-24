/obj/item/organ/heart/serpentid
	name = "double heart"
	icon = 'modular_bandastation/species/serpentids/icon/organs.dmi'
	icon_state = "heart"
	desc = "A pair of hearts."

/obj/item/organ/heart/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.03)
	AddComponent(/datum/component/defib_heart_hunger)
