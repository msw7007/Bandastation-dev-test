/// печень - вырабатывает глутамат натрия из нутриентов
/obj/item/organ/liver/serpentid
	name = "chemical processor"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "liver"
	desc = "A large looking liver."
	alcohol_tolerance = ALCOHOL_RATE * 2
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	radial_action_state = "serpentid_stealth"
	radial_action_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_KIDNEYS
	var/cloak_engaged = FALSE

/obj/item/organ/liver/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.1, 0.5)
	AddComponent(/datum/component/hunger_organ)
	AddComponent(/datum/component/organ_action, radial_action_state, radial_action_icon)

/obj/item/organ/liver/serpentid/on_life()
	. = .. ()
	if((owner.move_intent != MOVE_INTENT_RUN || owner.body_position == LYING_DOWN || (world.time - owner.last_pushoff) >= 5) && (!owner.stat && (owner.mobility_flags & MOBILITY_STAND) && !owner.buckled && cloak_engaged))
		make_invisible()
	else
		if(owner.invisibility != INVISIBILITY_MAXIMUM)
			reset_visibility()

/obj/item/organ/liver/serpentid/switch_mode(force_off = FALSE)
	if(!force_off && owner?.nutrition >= NUTRITION_LEVEL_STARVING && !cloak_engaged)
		cloak_engaged = TRUE
		chemical_consuption = initial(chemical_consuption)
	else
		cloak_engaged = FALSE
		chemical_consuption = 0
	SEND_SIGNAL(src, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, chemical_consuption)

/obj/item/organ/liver/serpentid/proc/make_invisible()
	animate(owner, alpha = 0, time = 5 SECONDS)
	owner.remove_from_all_data_huds()
	owner.add_atom_colour(SSparallax.get_parallax_color(), TEMPORARY_COLOUR_PRIORITY)

/obj/item/organ/liver/serpentid/proc/reset_visibility()
	animate(owner, alpha = 255, time = 1 SECONDS)
	owner.add_to_all_human_data_huds()
	owner.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY)
