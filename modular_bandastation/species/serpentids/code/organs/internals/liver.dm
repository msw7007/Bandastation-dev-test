/// печень - вырабатывает глутамат натрия из нутриентов
/obj/item/organ/liver/serpentid
	name = "chemical processor"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "liver"
	desc = "A large looking liver."
	alcohol_tolerance = ALCOHOL_RATE * 2

/obj/item/organ/liver/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, tox_mult_damage = 0.5, tox_rate = 0.1)
