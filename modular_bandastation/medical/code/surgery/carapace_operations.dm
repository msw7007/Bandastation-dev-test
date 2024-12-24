//////////////////////////////////////////////////////////////////
//					Хирургия для панциря						//
//////////////////////////////////////////////////////////////////
/datum/surgery/bone_repair/carapace_shell
	name = "Carapace Integrity Repair"
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/retract_carapace,
		/datum/surgery_step/set_bone,
		/datum/surgery_step/finish_carapace,
		/datum/surgery_step/cauterize
	)
	possible_locs = list(BODY_ZONE_CHEST)
	requires_organic_bodypart = TRUE

/datum/surgery_step/finish_carapace
	name = "medicate carapace"

	allowed_tools = list(
		TOOL_BONEGEL = 100,
		TOOL_SCREWDRIVER = 90
	)

	preop_sound = list(
		TOOL_BONEGEL = 'sound/surgery/organ1.ogg',
		/obj/item/screwdriver/power = 'sound/items/drill_hit.ogg',
		/obj/item/screwdriver = 'sound/items/screwdriver.ogg'
	)

	can_infect = TRUE
	blood_level = SURGERY_BLOODSPREAD_HANDS

	time = 2.4 SECONDS

/datum/surgery_step/finish_carapace/begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(
		"[user] starts to finish mending the damaged carapace in [target]'s [affected.name] with \the [tool].",
		"You start to finish mending the damaged carapace in [target]'s [affected.name] with \the [tool].",
		chat_message_type = MESSAGE_TYPE_COMBAT
	)
	return ..()

/datum/surgery_step/finish_carapace/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, datum/surgery/surgery)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(
		"<span class='notice'>[user] has mended the damaged carapace in [target]'s [affected.name] with \the [tool].</span>",
		"<span class='notice'>You have mended the damaged carapace in [target]'s [affected.name] with \the [tool].</span>",
		chat_message_type = MESSAGE_TYPE_COMBAT
	)
	SEND_SIGNAL(target, COMSIG_SURGERY_REPAIR)
	return SURGERY_STEP_CONTINUE

/datum/surgery_step/finish_carapace/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(
		"<span class='warning'>[user]'s hand slips, smearing [tool] in the incision in [target]'s [affected.name]!</span>",
		"<span class='warning'>Your hand slips, smearing [tool] in the incision in [target]'s [affected.name]!</span>",
		chat_message_type = MESSAGE_TYPE_COMBAT
	)
	return SURGERY_STEP_RETRY

/datum/surgery/bone_repair/carapace_shell/can_start(mob/user, mob/living/carbon/target)
	var/can_start = (SEND_SIGNAL(target, COMSIG_SURGERY_STOP) & SURGERY_STOP)
	return can_start

#undef CARAPACE_SHELL_ARMORED_BRUTE
#undef CARAPACE_SHELL_ARMORED_BURN
#undef CARAPACE_SHELL_BROKEN_BRUTE
#undef CARAPACE_SHELL_BROKEN_BURN
