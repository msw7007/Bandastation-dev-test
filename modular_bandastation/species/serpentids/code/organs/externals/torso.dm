/obj/item/bodypart/chest/serpentid
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	limb_id = SPECIES_SERPENTID
	is_dimorphic = TRUE
	wing_types = list(/obj/item/organ/wings/functional/dragon)
	species_bodytype = SPECIES_SERPENTID
	var/min_broken_damage = 40
	//icon =
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_KIDNEYS
	var/cloak_engaged = FALSE
	var/radial_action_state = "serpentid_stealth"
	var/radial_action_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'

/obj/item/bodypart/chest/serpentid/get_butt_sprite()
	return BUTT_SPRITE_SERPENTID

/obj/item/bodypart/chest/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, FALSE, min_broken_damage)
	AddComponent(/datum/component/carapace_shell, owner)
	AddComponent(/datum/component/hunger_organ)
	AddComponent(/datum/component/organ_action, radial_action_state, radial_action_icon)

/obj/item/bodypart/chest/serpentid/on_life()
	. = .. ()
	if((owner.move_intent != MOVE_INTENT_RUN || owner.body_position == LYING_DOWN || (world.time - owner.last_pushoff) >= 5) && (!owner.stat && (owner.mobility_flags & MOBILITY_STAND) && !owner.buckled && cloak_engaged))
		make_invisible()
	else
		if(owner.invisibility != INVISIBILITY_MAXIMUM)
			reset_visibility()

/obj/item/bodypart/chest/serpentid/proc/switch_mode(force_off = FALSE)
	if(!force_off && owner?.nutrition >= NUTRITION_LEVEL_STARVING && !cloak_engaged)
		cloak_engaged = TRUE
		chemical_consuption = initial(chemical_consuption)
	else
		cloak_engaged = FALSE
		chemical_consuption = 0
	SEND_SIGNAL(src, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, chemical_consuption)

/obj/item/bodypart/chest/serpentid/proc/make_invisible()
	animate(owner, alpha = 0, time = 5 SECONDS)
	owner.remove_from_all_data_huds()
	owner.add_atom_colour(SSparallax.get_parallax_color(), TEMPORARY_COLOUR_PRIORITY)

/obj/item/bodypart/chest/serpentid/proc/reset_visibility()
	animate(owner, alpha = 255, time = 1 SECONDS)
	owner.add_to_all_human_data_huds()
	owner.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY)

// Допилить броню
