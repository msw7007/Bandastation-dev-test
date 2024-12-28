/obj/item/bodypart/arm/left/serpentid
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	limb_id = SPECIES_SERPENTID
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "pierce"
	unarmed_attack_effect = ATTACK_EFFECT_SMASH
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'
	var/min_broken_damage = 20

/obj/item/bodypart/arm/left/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)

/obj/item/bodypart/arm/right/serpentid
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	limb_id = SPECIES_SERPENTID
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "pierce"
	unarmed_attack_effect = ATTACK_EFFECT_SMASH
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'
	var/min_broken_damage = 20

/obj/item/bodypart/arm/right/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)
