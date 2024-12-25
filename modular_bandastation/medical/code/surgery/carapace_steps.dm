//////////////////////////////////////////////////////////////////
//					Этапы операций для панциря					//
//////////////////////////////////////////////////////////////////

//Слом карапаса - вызывает перелом при завершении
/datum/surgery_step/retract_carapace
	name = "retract carapace (retractors)"
	implements = list(
		TOOL_RETRACTOR = 100,
		TOOL_SCREWDRIVER = 45,
		TOOL_WIRECUTTER = 35,
		/obj/item/stack/rods = 35)
	time = 24
	preop_sound = 'sound/items/handling/surgery/retractor1.ogg'
	success_sound = 'sound/items/handling/surgery/retractor2.ogg'

/datum/surgery_step/retract_carapace/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	display_results(
		user,
		target,
		span_notice("You begin to retract the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)]..."),
		span_notice("[user] begins to retract the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)]."),
		span_notice("[user] begins to retract the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)]."),
	)
	display_pain(target, "You feel a severe stinging pain spreading across your [target.parse_zone_with_bodypart(target_zone)] as the carapace is pulled back!")

/datum/surgery_step/retract_carapace/success(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	//Активировать слом карапаса

	return ..()

/datum/surgery_step/mend_carapace
	name = "reset carapace (bonesetter)"
	implements = list(
		TOOL_BONESET = 100,
		/obj/item/stack/sticky_tape/surgical = 60,
		/obj/item/stack/sticky_tape/super = 40,
		/obj/item/stack/sticky_tape = 20)
	time = 40

/datum/surgery_step/mend_carapace/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	if(surgery.operated_wound)
		display_results(
			user,
			target,
			span_notice("You begin to reset the carapace in [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]..."),
			span_notice("[user] begins to reset the carapace in [target]'s [target.parse_zone_with_bodypart(user.zone_selected)] with [tool]."),
			span_notice("[user] begins to reset the carapace in [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]."),
		)
		display_pain(target, "The aching pain in your [target.parse_zone_with_bodypart(user.zone_selected)] is overwhelming!")
	else
		user.visible_message(span_notice("[user] looks for [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]."), span_notice("You look for [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]..."))

/datum/surgery_step/mend_carapace/success(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	if(surgery.operated_wound)
		if(isstack(tool))
			var/obj/item/stack/used_stack = tool
			used_stack.use(1)
		display_results(
			user,
			target,
			span_notice("You successfully reset the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)]."),
			span_notice("[user] successfully resets the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)] with [tool]!"),
			span_notice("[user] successfully resets the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)]!"),
		)
		log_combat(user, target, "reset a compound fracture in", addition="COMBAT MODE: [uppertext(user.combat_mode)]")
		SEND_SIGNAL(target, COMSIG_SURGERY_MEND_CARAPACE)
	else
		to_chat(user, span_warning("[target] has no compound fracture there!"))
	return ..()

/datum/surgery_step/mend_carapace/failure(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, fail_prob = 0)
	..()
	if(isstack(tool))
		var/obj/item/stack/used_stack = tool
		used_stack.use(1)

/datum/surgery_step/set_carapace
	name = "repair compound fracture (bone gel/tape)"
	implements = list( \
		/obj/item/stack/medical/bone_gel = 100, \
		/obj/item/stack/sticky_tape/surgical = 100, \
		/obj/item/stack/sticky_tape/super = 50, \
		/obj/item/stack/sticky_tape = 30, \
	)
	time = 40

/datum/surgery_step/set_carapace/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	if(surgery.operated_wound)
		display_results(
			user,
			target,
			span_notice("You begin to repair the carapace in [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]..."),
			span_notice("[user] begins to repair the carapace in [target]'s [target.parse_zone_with_bodypart(user.zone_selected)] with [tool]."),
			span_notice("[user] begins to repair the carapace in [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]."),
		)
		display_pain(target, "The aching pain in your [target.parse_zone_with_bodypart(user.zone_selected)] is overwhelming!")
	else
		user.visible_message(span_notice("[user] looks for [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]."), span_notice("You look for [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]..."))

/datum/surgery_step/set_carapace/success(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	if(surgery.operated_wound)
		if(isstack(tool))
			var/obj/item/stack/used_stack = tool
			used_stack.use(1)
		display_results(
			user,
			target,
			span_notice("You successfully repair the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)]."),
			span_notice("[user] successfully repairs the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)] with [tool]!"),
			span_notice("[user] successfully repairs the carapace in [target]'s [target.parse_zone_with_bodypart(target_zone)]!"),
		)
		log_combat(user, target, "repaired a compound carapace in", addition="COMBAT MODE: [uppertext(user.combat_mode)]")
		qdel(surgery.operated_wound)
	else
		to_chat(user, span_warning("[target] has no compound carapace there!"))
	return ..()

/datum/surgery_step/set_carapace/failure(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, fail_prob = 0)
	..()
	if(isstack(tool))
		var/obj/item/stack/used_stack = tool
		used_stack.use(1)
