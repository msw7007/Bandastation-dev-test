
/obj/item/organ/eyes/serpentid
	name = "serpentid eyeballs"
	icon = 'modular_bandastation/species/icons/mob/species/serpentid/organs.dmi'

// Глаза - включают режим щитков, но очень уязвивым к вспышкам (в 2 раза сильнее молиных глаз)
/obj/item/organ/eyes/serpentid
	name = "visual sensor"
	icon = 'modular_ss220/species/serpentids/icons/organs.dmi'
	desc = "A large looking eyes with some chemical enchanments."
	icon_state = "eyes"
	see_in_dark = 0
	actions_types = 		list(/datum/action/item_action/organ_action/toggle/serpentid)
	action_icon = 			list(/datum/action/item_action/organ_action/toggle/serpentid = 'modular_ss220/species/serpentids/icons/organs.dmi')
	action_icon_state = 	list(/datum/action/item_action/organ_action/toggle/serpentid = "serpentid_abilities")
	flash_protect = FLASH_PROTECTION_EXTRA_SENSITIVE
	tint = FLASH_PROTECTION_NONE
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_EYES
	var/vision_ajust_coefficient = 0.7
	var/update_time_client_colour = 10
	var/active = FALSE
	radial_action_state = "serpentid_nvg"
	radial_action_icon = 'modular_ss220/species/serpentids/icons/organs.dmi'

/obj/item/organ/eyes/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.02)
	AddComponent(/datum/component/hunger_organ)
	AddComponent(/datum/component/organ_action, radial_action_state, radial_action_icon)

// Прок на получение цвета глаз
/obj/item/organ/eyes/serpentid/generate_icon(mob/living/carbon/human/HA)
	if(!istype(HA))
		HA = owner
	var/icon/eyes_icon = new /icon(HA.dna.species.eyes_icon, HA.dna.species.eyes)
	eyes_icon.Blend(eye_color, ICON_ADD)

	return eyes_icon

/obj/item/organ/eyes/serpentid/on_life()
	. = ..()
	if(owner)
		var/mob/mob = owner
		mob.update_client_colour(time = update_time_client_colour)

/obj/item/organ/eyes/serpentid/get_colourmatrix()
	if(!owner)
		return
	var/chem_value = (owner.nutrition - NUTRITION_LEVEL_STARVING)/NUTRITION_LEVEL_HUNGRY
	var/vision_chem = clamp(chem_value, SERPENTID_EYES_LOW_VISIBLE_VALUE, SERPENTID_EYES_MAX_VISIBLE_VALUE)
	var/vision_concentration = (1 - vision_chem/SERPENTID_EYES_MAX_VISIBLE_VALUE/2)*SERPENTID_EYES_LOW_VISIBLE_VALUE

	vision_concentration = SERPENTID_EYES_LOW_VISIBLE_VALUE * (1 - chem_value ** vision_ajust_coefficient)
	var/vision_adjust = clamp(vision_concentration, 0, SERPENTID_EYES_LOW_VISIBLE_VALUE)

	var/vision_matrix = list(vision_chem, vision_adjust, vision_adjust,\
		vision_adjust, vision_chem, vision_adjust,\
		vision_adjust, vision_adjust, vision_chem)
	return vision_matrix

/obj/item/organ/eyes/serpentid/switch_mode(force_off = FALSE)
	. = ..()
	if(!force_off && owner?.nutrition >= NUTRITION_LEVEL_HYPOGLYCEMIA && !(status & ORGAN_DEAD) && !active)
		see_in_dark = 8
		chemical_consuption = initial(chemical_consuption)
		active = TRUE
	else
		see_in_dark = initial(see_in_dark)
		chemical_consuption = 0
		active = FALSE
	owner?.update_sight()
	SEND_SIGNAL(src, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, chemical_consuption)
