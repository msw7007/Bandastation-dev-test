/obj/item/bodypart/chest/serpentid
	icon_greyscale = 'modular_bandastation/species/icons/mob/species/serpentid/body.dmi'
	limb_id = SPECIES_SERPENTID
	is_dimorphic = TRUE
	wing_types = list(/obj/item/organ/wings/functional/dragon)
	species_bodytype = SPECIES_SERPENTID

/obj/item/bodypart/chest/serpentid/get_butt_sprite()
	return BUTT_SPRITE_SERPTENTID

#define SERPENTID_ARMOR_THRESHOLD_1 30
#define SERPENTID_ARMOR_THRESHOLD_2 60
#define SERPENTID_ARMOR_THRESHOLD_3 90

#define SERPENTID_ARMORED_LOW_TEMP 0
#define SERPENTID_ARMORED_HIGH_TEMP 400
#define SERPENTID_ARMORED_STEP_TEMP 30

/obj/item/bodypart/chest/carapace
	min_broken_damage = 40
	encased = CARAPACE_ENCASE_WORD

/obj/item/bodypart/chest/carapace/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, FALSE, min_broken_damage)

/obj/item/bodypart/chest/carapace/replaced()
	. = ..()
	AddComponent(/datum/component/carapace_shell, owner, treshold_1 = SERPENTID_ARMOR_THRESHOLD_1, treshold_2 = SERPENTID_ARMOR_THRESHOLD_2, treshold_3 = SERPENTID_ARMOR_THRESHOLD_3, threshold_cold = SERPENTID_ARMORED_LOW_TEMP, threshold_heat = SERPENTID_ARMORED_HIGH_TEMP, temp_progression = SERPENTID_ARMORED_STEP_TEMP)

#undef SERPENTID_ARMOR_THRESHOLD_1
#undef SERPENTID_ARMOR_THRESHOLD_2
#undef SERPENTID_ARMOR_THRESHOLD_3
#undef SERPENTID_ARMORED_LOW_TEMP
#undef SERPENTID_ARMORED_HIGH_TEMP
#undef SERPENTID_ARMORED_STEP_TEMP


///Хитиновые конечности - прочее
/obj/item/bodypart/groin/carapace
	min_broken_damage = 40
	encased = CARAPACE_ENCASE_WORD

/obj/item/bodypart/groin/carapace/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, FALSE, min_broken_damage)
