/obj/item/bodypart/head/serpentid
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	limb_id = SPECIES_SERPENTID
	icon_state = "serpentid_head_m"
	is_dimorphic = TRUE
	head_flags = HEAD_EYESPRITES|HEAD_EYECOLOR|HEAD_EYEHOLES|HEAD_DEBRAIN
	encased = CARAPACE_ENCASE_WORD
	actions_types = 		list(/datum/action/item_action/organ_action/toggle)
	//action_icon = 			list(/datum/action/item_action/organ_action/toggle = 'modular_bandastation/species/serpentids/icons/organs.dmi')
	//action_icon_state = 	list(/datum/action/item_action/organ_action/toggle = "serpentid_eyes_0")
	var/eye_shielded = FALSE
	var/open_bodypart_threshold = 30

// Может и на оффы, но пока увы. Я не против, если этот код отправит на оффы КТО угодно.
/obj/item/bodypart/head/serpentid/on_adding(mob/living/carbon/new_owner)
	. = ..()
	for(var/datum/action/action as anything in actions)
		action.Grant(new_owner)

/obj/item/bodypart/head/serpentid/on_removal(mob/living/carbon/old_owner)
	. = ..()
	for(var/X in actions)
		var/datum/action/A = X
		A.Remove(owner)

/obj/item/bodypart/head/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, FALSE, open_threshold = open_bodypart_threshold)

/obj/item/bodypart/head/serpentid/ui_action_click()
	var/obj/item/organ/eyes/E = owner.get_organ_slot(ORGAN_SLOT_EYES)
	eye_shielded = !eye_shielded
	E.flash_protect = eye_shielded ? FLASH_PROTECTION_WELDER : E::flash_protect
	E.tint = eye_shielded ? FLASH_PROTECTION_WELDER : E::tint
	owner.update_sight()

	for(var/datum/action/item_action/T in actions)
		T.button_icon_state ="serpentid_eyes_[eye_shielded]"
