/obj/item/bodypart/head/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_serpentid
	is_dimorphic = TRUE
	head_flags = HEAD_LIPS|HEAD_EYESPRITES|HEAD_EYECOLOR|HEAD_EYEHOLES|HEAD_DEBRAIN|HEAD_HAIR|HEAD_serpentid
	species_bodytype = SPECIES_serpentid

/obj/item/bodypart/chest/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_serpentid
	is_dimorphic = TRUE
	wing_types = list(/obj/item/organ/wings/functional/dragon)
	species_bodytype = SPECIES_serpentid

/obj/item/bodypart/chest/serpentid/get_butt_sprite()
	return BUTT_SPRITE_serpentid

/obj/item/bodypart/arm/left/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_serpentid
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "lacerate"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'

/obj/item/bodypart/arm/right/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_serpentid
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "lacerate"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'

/obj/item/bodypart/leg/left/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_serpentid

/obj/item/bodypart/leg/right/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_serpentid
