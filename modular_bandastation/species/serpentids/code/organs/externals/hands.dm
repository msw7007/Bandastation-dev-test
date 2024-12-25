/obj/item/bodypart/arm/left/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_SERPENTID
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "lacerate"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'

/obj/item/bodypart/arm/right/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_SERPENTID
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "lacerate"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'

/obj/item/bodypart/arm/carapace
	min_broken_damage = 20
	encased = CARAPACE_ENCASE_WORD

/obj/item/bodypart/arm/carapace/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)

/obj/item/bodypart/arm/right/carapace
	min_broken_damage = 20
	encased = CARAPACE_ENCASE_WORD

/obj/item/bodypart/arm/right/carapace/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, TRUE, min_broken_damage)
