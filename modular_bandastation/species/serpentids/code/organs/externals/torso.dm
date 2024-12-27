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
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	//icon =

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








/// почки - базовые c добавлением дикея, вырабатывают энзимы, которые позволяют ГБС скрываться
/obj/item/organ/kidneys/serpentid
	name = "secreting organ"
	icon = 'modular_ss220/species/serpentids/icons/organs.dmi'
	icon_state = "kidneys"
	desc = "A large looking organ, that can inject chemicals."
	actions_types = 		list(/datum/action/item_action/organ_action/toggle/serpentid)
	action_icon = 			list(/datum/action/item_action/organ_action/toggle/serpentid = 'modular_ss220/species/serpentids/icons/organs.dmi')
	action_icon_state = 	list(/datum/action/item_action/organ_action/toggle/serpentid = "serpentid_abilities")
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_KIDNEYS
	var/cloak_engaged = FALSE
	radial_action_state = "serpentid_stealth"
	radial_action_icon = 'modular_ss220/species/serpentids/icons/organs.dmi'

/obj/item/organ/kidneys/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.15)
	AddComponent(/datum/component/hunger_organ)
	AddComponent(/datum/component/organ_action, radial_action_state, radial_action_icon)

/obj/item/organ/kidneys/serpentid/on_life()
	. = .. ()
	if((owner.m_intent != MOVE_INTENT_RUN || owner.body_position == LYING_DOWN || (world.time - owner.last_movement) >= 5) && (!owner.stat && (owner.mobility_flags & MOBILITY_STAND) && !owner.restrained() && cloak_engaged))
		if(owner.invisibility != INVISIBILITY_LEVEL_TWO)
			owner.alpha -= 51
	else
		if(owner.invisibility != INVISIBILITY_OBSERVER)
			owner.reset_visibility()
			owner.alpha = 255
	if(owner.alpha == 0)
		owner.make_invisible()

/obj/item/organ/kidneys/serpentid/switch_mode(force_off = FALSE)
	. = ..()
	if(!force_off && owner?.nutrition >= NUTRITION_LEVEL_HYPOGLYCEMIA && !cloak_engaged && !(status & ORGAN_DEAD))
		cloak_engaged = TRUE
		chemical_consuption = initial(chemical_consuption)
	else
		cloak_engaged = FALSE
		chemical_consuption = 0
	SEND_SIGNAL(src, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, chemical_consuption)
