// Глаза - включают режим щитков, но очень уязвивым к вспышкам (в 2 раза сильнее молиных глаз)
/obj/item/organ/eyes/serpentid
	name = "visual sensor"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	desc = "A large looking eyes with some chemical enchanments."
	icon_state = "eyes"
	actions_types = list(/datum/action/item_action/organ_action/switch_mode)
	flash_protect = FLASH_PROTECTION_HYPER_SENSITIVE
	tint = FLASH_PROTECTION_NONE
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_EYES
	var/vision_ajust_coefficient = 0.7
	var/active = FALSE
	radial_action_state = "serpentid_nvg"
	radial_action_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'

/obj/item/organ/eyes/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.02)
	AddComponent(/datum/component/organ_hunger)
	AddComponent(/datum/component/organ_action, radial_action_state, radial_action_icon)

/obj/item/organ/eyes/serpentid/on_life()
	. = ..()
	if(owner)
		var/mob/mob = owner
		mob.update_client_colour()
		update_colourmatrix()

/obj/item/organ/eyes/serpentid/proc/update_colourmatrix()
	if(!owner)
		return

	var/chem_value = (owner.nutrition - NUTRITION_LEVEL_STARVING)/NUTRITION_LEVEL_STARVING
	var/vision_chem = clamp(chem_value, SERPENTID_EYES_LOW_VISIBLE_VALUE, SERPENTID_EYES_MAX_VISIBLE_VALUE)
	var/vision_concentration = (1 - vision_chem/SERPENTID_EYES_MAX_VISIBLE_VALUE/2)*SERPENTID_EYES_LOW_VISIBLE_VALUE

	vision_concentration = SERPENTID_EYES_LOW_VISIBLE_VALUE * (1 - chem_value ** vision_ajust_coefficient)
	var/vision_adjust = clamp(vision_concentration, 0, SERPENTID_EYES_LOW_VISIBLE_VALUE)

	var/vision_matrix = list(vision_chem, vision_adjust, vision_adjust,\
		vision_adjust, vision_chem, vision_adjust,\
		vision_adjust, vision_adjust, vision_chem)

	var/datum/client_colour/monochrome/serpentid_hungry/new_effect = new (owner)
	new_effect.color = vision_matrix
	owner.add_client_colour(new_effect)

/obj/item/organ/eyes/serpentid/switch_mode(force_off = FALSE)
	. = ..()
	if(!force_off && owner?.nutrition >= NUTRITION_LEVEL_STARVING && !(organ_flags & ORGAN_FAILING) && !active)
		active = TRUE
		lighting_cutoff = LIGHTING_CUTOFF_FULLBRIGHT
		chemical_consuption = initial(chemical_consuption)
		owner.visible_message(span_warning("Зрачки [owner] расширяются!"))
	else
		active = FALSE
		lighting_cutoff = initial(lighting_cutoff)
		chemical_consuption = 0
		owner.visible_message(span_notice("Зрачки [owner] сужаются."))
	owner?.update_sight()
	SEND_SIGNAL(src, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, chemical_consuption)

/datum/client_colour/monochrome/serpentid_hungry
	color = COLOR_MATRIX_GRAYSCALE
