//Augmented Eyesight: Gives you X-ray vision or protection from flashes. Also, high DNA cost because of how powerful it is.
//Possible todo: make a custom message for directing a penlight/flashlight at the eyes - not sure what would display though.

/datum/action/changeling/augmented_eyesight
	name = "Augmented Eyesight"
	desc = "Создает больше светочувствительных палочек в наших глазах, что позволяет нашему зрению проникать сквозь большинство загораживающих предметов. \
		Защищает наше зрение от вспышек во время бездействия."
	helptext = "Дает нам рентгеновское зрение или защиту от вспышек. \
		Пока рентгеновское зрение активно, мы станем гораздо более уязвимыми для устройств со вспышкой."
	button_icon_state = "augmented_eyesight"
	chemical_cost = 0
	dna_cost = 2
	// Active = Flash weakness and x-ray
	// Inactive = Flash protection and no x-ray
	active = FALSE

/datum/action/changeling/augmented_eyesight/on_purchase(mob/user) //The ability starts inactive, so we should be protected from flashes.
	. = ..()
	var/obj/item/organ/eyes/ling_eyes = user.get_organ_slot(ORGAN_SLOT_EYES)
	RegisterSignal(user, COMSIG_CARBON_GAIN_ORGAN, PROC_REF(eye_implanted))
	RegisterSignal(user, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(eye_removed))
	if(!isnull(ling_eyes))
		ling_eyes.flash_protect = FLASH_PROTECTION_WELDER //Adjust the user's eyes' flash protection
		to_chat(user, span_changeling("Мы настраиваем глаза, чтобы защитить их от яркого света."))

/datum/action/changeling/augmented_eyesight/sting_action(mob/living/carbon/user)
	if(!istype(user))
		return FALSE

	var/obj/item/organ/eyes/ling_eyes = user.get_organ_slot(ORGAN_SLOT_EYES)
	if(isnull(ling_eyes))
		user.balloon_alert(user, "нет глаз!")
		return FALSE

	..()

	if(active)
		active = FALSE
		REMOVE_TRAIT(user, TRAIT_XRAY_VISION, REF(src))
		ling_eyes.flash_protect = max(ling_eyes.flash_protect += 3, FLASH_PROTECTION_WELDER)
		to_chat(user, span_changeling("Мы настраиваем глаза, чтобы защитить их от яркого света."))

	else
		active = TRUE
		ADD_TRAIT(user, TRAIT_XRAY_VISION, REF(src))
		ling_eyes.flash_protect = max(ling_eyes.flash_protect += -3, FLASH_PROTECTION_HYPER_SENSITIVE)
		to_chat(user, span_changeling("Мы настраиваем глаза, чтобы чувствовать добычу сквозь стены."))

	user.update_sight()
	return TRUE

/datum/action/changeling/augmented_eyesight/Remove(mob/user)
	var/obj/item/organ/eyes/ling_eyes = user.get_organ_slot(ORGAN_SLOT_EYES)
	if(!isnull(ling_eyes))
		ling_eyes.flash_protect = initial(ling_eyes.flash_protect)

	REMOVE_TRAIT(user, TRAIT_XRAY_VISION, REF(src))
	user.update_sight()

	UnregisterSignal(user, list(COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN))
	return ..()

/// Signal proc to grant the correct level of flash sensitivity
/datum/action/changeling/augmented_eyesight/proc/eye_implanted(mob/living/source, obj/item/organ/gained, special)
	SIGNAL_HANDLER

	var/obj/item/organ/eyes/ling_eyes = gained
	if(!istype(ling_eyes))
		return
	if(active)
		ling_eyes.flash_protect = max(ling_eyes.flash_protect += -3, FLASH_PROTECTION_HYPER_SENSITIVE)
	else
		ling_eyes.flash_protect = max(ling_eyes.flash_protect += 3, FLASH_PROTECTION_WELDER)

/// Signal proc to remove flash sensitivity when the eyes are removed
/datum/action/changeling/augmented_eyesight/proc/eye_removed(mob/living/source, obj/item/organ/removed, special)
	SIGNAL_HANDLER

	var/obj/item/organ/eyes/ling_eyes = removed
	if(!istype(ling_eyes))
		return
	ling_eyes.flash_protect = initial(ling_eyes.flash_protect)
	// We don't need to bother about removing or adding x-ray vision, fortunately, because they can't see anyways
