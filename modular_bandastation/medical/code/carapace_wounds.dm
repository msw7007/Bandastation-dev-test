//////////////////////////////////////////////////////////////////
//			Травмы для отслеживания урона панциря				//
//////////////////////////////////////////////////////////////////

#define CARAPACE_HEAL_TOOL_AMOUNT 20
#define CARAPACE_HEAL_SELF_AMOUNT 2
#define CARAPACE_HEAL_GEL_FACTOR 2
#define CARAPACE_HEAL_TAPE_FACTOR 2
#define CARAPACE_DAMAGE_THRESHOLD_NO_STEALTH 50
#define CARAPACE_DAMAGE_THRESHOLD_NO_ARMOR 100
#define CARAPACE_DAMAGE_THRESHOLD_NO_RIG 150

/datum/wound/carapace_damaged
	name = "Internal Bleeding"
	sound_effect = 'sound/items/weapons/slice.ogg'
	processes = TRUE
	treatable_tools = list(TOOL_HEMOSTAT)
	base_treat_time = 5 SECONDS
	wound_flags = MANGLES_INTERIOR

	// Сколько урона должна получить кукла, чтобы заработать данную травму
	var/carapace_damage_value
	// Какие трейты убирает/добавляет состояние травмы
	var/list/wound_traits
	var/alert_path
	var/last_attacking_time = 0 SECONDS
	var/time_to_heal = 0 SECONDS
	/// Have we been bone gel'd?
	var/gelled
	/// Have we been taped?
	var/taped

/datum/wound/carapace_damaged/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	if(limb.can_bleed() && attack_direction && victim.blood_volume > BLOOD_VOLUME_OKAY)
		victim.spray_blood(attack_direction, severity)

	return ..()

/datum/wound/carapace_damaged/receive_damage(wounding_type, wounding_dmg, wound_bonus)
	if(victim.stat == DEAD || (wounding_dmg < 5) || !limb.can_bleed() || !victim.blood_volume)
		return
	carapace_damage_value += wounding_dmg
	victim.visible_message("<span class='smalldanger'>Blood droplets fly from [victim]'s carapace.</span>", span_danger("You spray a bit of blood from the blow."), vision_distance=COMBAT_MESSAGE_RANGE)
	var/blood_bled = wounding_dmg / 10
	victim.bleed(blood_bled, TRUE)
	last_attacking_time = world.time

/datum/wound/carapace_damaged/handle_process(seconds_per_tick, times_fired)
	if (!victim || HAS_TRAIT(victim, TRAIT_STASIS))
		return

	var/datum/wound/carapace_damaged/check_wound
	for(var/limb_wound in limb.wounds)
		var/datum/wound/current_wound = limb_wound
		if(istype(current_wound, /datum/wound/carapace_damaged/))
			check_wound = current_wound
			progress_wound(check_wound)

	var/calculated_timer = last_attacking_time - world.time
	if(calculated_timer > time_to_heal)
		carapace_damage_value -= CARAPACE_HEAL_SELF_AMOUNT

	carapace_damage_value -=  (gelled ? CARAPACE_HEAL_GEL_FACTOR : 0) * (taped ? CARAPACE_HEAL_TAPE_FACTOR : 1)

	if(carapace_damage_value <= 0)
		victim.clear_alert("carapace_break")
		qdel(src)

/datum/wound/carapace_damaged/proc/progress_wound(income_wound)
	var/wound_path
	switch(carapace_damage_value)
		if(CARAPACE_DAMAGE_THRESHOLD_NO_STEALTH to CARAPACE_DAMAGE_THRESHOLD_NO_ARMOR)
			wound_path = /datum/wound/carapace_damaged/moderate
		if(CARAPACE_DAMAGE_THRESHOLD_NO_ARMOR to CARAPACE_DAMAGE_THRESHOLD_NO_RIG)
			wound_path = /datum/wound/carapace_damaged/severe
		if(CARAPACE_DAMAGE_THRESHOLD_NO_RIG to INFINITY)
			wound_path = /datum/wound/carapace_damaged/critical

	if(!wound_path)
		return

	var/datum/wound/carapace_damaged/check_wound = income_wound
	if(!istype(check_wound, wound_path))
		var/datum/wound/carapace_damaged/new_wound = new wound_path()
		new_wound.apply_wound(limb, silent = FALSE, old_wound = check_wound, wound_source = "Carapace breaks", replacing = TRUE)
		check_wound.remove_wound()
	else
		qdel(check_wound)

/datum/wound/carapace_damaged/treat(obj/item/I, mob/user)
	if(istype(I, /obj/item/stack/medical/bone_gel))
		return gel(I, user)
	else if(istype(I, /obj/item/stack/sticky_tape/surgical))
		return tape(I, user)

/datum/wound/carapace_damaged/proc/gel(obj/item/stack/medical/bone_gel/I, mob/user)
	if(gelled)
		to_chat(user, span_warning("[user == victim ? "Your" : "[victim]'s"] [limb.plaintext_zone] is already coated with bone gel!"))
		return TRUE

	if(!do_after(user, base_treat_time * 1.5 * (user == victim ? 1.5 : 1), target = victim, extra_checks=CALLBACK(src, PROC_REF(still_exists))))
		return TRUE

	I.use(1)
	if(user != victim)
		user.visible_message(span_notice("[user] finishes applying [I] to [victim]'s [limb.plaintext_zone], emitting a fizzing noise!"), span_notice("You finish applying [I] to [victim]'s [limb.plaintext_zone]!"), ignored_mobs=victim)
		to_chat(victim, span_userdanger("[user] finishes applying [I] to your [limb.plaintext_zone], and you can feel the bones exploding with pain as they begin melting and reforming!"))
	else
		if(!HAS_TRAIT(victim, TRAIT_ANALGESIA))
			if(prob(25 + (20 * (severity - 2)) - min(victim.get_drunk_amount(), 10))) // 25%/45% chance to fail self-applying with severe and critical wounds, modded by drunkenness
				victim.visible_message(span_danger("[victim] fails to finish applying [I] to [victim.p_their()] [limb.plaintext_zone], passing out from the pain!"), span_notice("You pass out from the pain of applying [I] to your [limb.plaintext_zone] before you can finish!"))
				victim.AdjustUnconscious(5 SECONDS)
				return TRUE
		victim.visible_message(span_notice("[victim] finishes applying [I] to [victim.p_their()] [limb.plaintext_zone], grimacing from the pain!"), span_notice("You finish applying [I] to your [limb.plaintext_zone], and your bones explode in pain!"))

	victim.apply_damage(25, BRUTE, limb, wound_bonus = CANT_WOUND)

	if(!HAS_TRAIT(victim, TRAIT_ANALGESIA))
		victim.apply_damage(100, STAMINA)
		victim.emote("scream")
	gelled = TRUE
	return TRUE

/datum/wound/carapace_damaged/proc/tape(obj/item/stack/sticky_tape/surgical/I, mob/user)
	if(!gelled)
		to_chat(user, span_warning("[user == victim ? "Your" : "[victim]'s"] [limb.plaintext_zone] must be coated with bone gel to perform this emergency operation!"))
		return TRUE
	if(taped)
		to_chat(user, span_warning("[user == victim ? "Your" : "[victim]'s"] [limb.plaintext_zone] is already wrapped in [I.name] and reforming!"))
		return TRUE

	user.visible_message(span_danger("[user] begins applying [I] to [victim]'s' [limb.plaintext_zone]..."), span_warning("You begin applying [I] to [user == victim ? "your" : "[victim]'s"] [limb.plaintext_zone]..."))

	if(!do_after(user, base_treat_time * (user == victim ? 1.5 : 1), target = victim, extra_checks=CALLBACK(src, PROC_REF(still_exists))))
		return TRUE

	I.use(1)
	if(user != victim)
		user.visible_message(span_notice("[user] finishes applying [I] to [victim]'s [limb.plaintext_zone], emitting a fizzing noise!"), span_notice("You finish applying [I] to [victim]'s [limb.plaintext_zone]!"), ignored_mobs=victim)
		to_chat(victim, span_green("[user] finishes applying [I] to your [limb.plaintext_zone], you immediately begin to feel your bones start to reform!"))
	else
		victim.visible_message(span_notice("[victim] finishes applying [I] to [victim.p_their()] [limb.plaintext_zone], !"), span_green("You finish applying [I] to your [limb.plaintext_zone], and you immediately begin to feel your bones start to reform!"))

	taped = TRUE
	return TRUE

/datum/wound/carapace_damaged/on_xadone(power)
	. = ..()

	if (limb) // parent can cause us to be removed, so its reasonable to check if we're still applied
		carapace_damage_value -= 0.1 // i think it's like a minimum of 3 power, so .09 blood_flow reduction per tick is pretty good for 0 effort

/// Полевое лечение
/datum/wound/carapace_damaged/proc/tool_clamping(obj/item/I, mob/user)

	var/improv_penalty_mult = (I.tool_behaviour == TOOL_CAUTERY ? 1 : 1.25) // 25% longer and less effective if you don't use a real cauterisation tool
	var/self_penalty_mult = (user == victim ? 1.5 : 1) // 50% longer and less effective if you do it to yourself
	var/treatment_delay = base_treat_time * self_penalty_mult * improv_penalty_mult

	if(HAS_TRAIT(src, TRAIT_WOUND_SCANNED))
		treatment_delay *= 0.5
		user.visible_message(span_danger("[user] begins expertly restore internals in [victim]'s [limb.plaintext_zone] with [I]..."), span_warning("You begin restoring internals in [user == victim ? "your" : "[victim]'s"] [limb.plaintext_zone] with [I], keeping the holo-image indications in mind..."))
	else
		user.visible_message(span_danger("[user] begins restoring internals in [victim]'s [limb.plaintext_zone] with [I]..."), span_warning("You begin restoring internals in [user == victim ? "your" : "[victim]'s"] [limb.plaintext_zone] with [I]..."))

	if (!carapace_damage_value)
		return TRUE

	if(!do_after(user, treatment_delay, target = victim, extra_checks = CALLBACK(src, PROC_REF(still_exists))))
		return TRUE

	user.visible_message(span_green("[user] restore fractures in [victim]."), span_green("You restore fractures on [victim]."))
	if(prob(30))
		victim.emote("scream")
	carapace_damage_value -= CARAPACE_HEAL_TOOL_AMOUNT
	return TRUE

/datum/wound_pregen_data/carapace_damaged
	abstract = TRUE

	required_limb_biostate = (BIO_FLESH)
	required_wounding_types = list(WOUND_BLUNT)

	wound_series = WOUND_SERIES_CARAPACE_DAMAGED

/datum/wound/carapace_damaged/get_limb_examine_description()
	return span_warning("The flesh on this limb appears heavy buldged")

/datum/wound/carapace_damaged/moderate
	name = "Minor carapace fracture"
	desc = "Patient's carapace has a small fractures. Look like it will be diffucult for them to hide."
	treat_text = "Treat torso with some cauterization tool or bone gel with surgical tape." // space is cold in ss13, so it's like an ice pack!
	examine_desc = "has a small fracture"
	occur_text = "covering with small fractures"
	severity = WOUND_SEVERITY_MODERATE
	threshold_penalty = 5
	wound_traits = list(TRAIT_SERPENTID_CAMOUFLAGE)
	status_effect_type = /datum/status_effect/wound/carapace_damaged/moderate
	time_to_heal = 5 MINUTES
	simple_treat_text = "<b>Integrity of carapace</b> can be restored with gel and tape."
	homemade_treat_text = "<b>Cauterizing</b> can help to repair fractures."

/datum/wound_pregen_data/carapace_damaged/carapace_break_light
	abstract = FALSE
	wound_path_to_generate = /datum/wound/carapace_damaged/moderate
	threshold_minimum = 40

/datum/wound/carapace_damaged/severe
	name = "Noticable carapace fractures"
	desc = "Patient's carapace covered with noticable fractures."
	treat_text = "Treat torso with some cauterization tool or bone gel with surgical tape."
	examine_desc = "has a series of fractures"
	occur_text = "covering with severe fractures"
	severity = WOUND_SEVERITY_SEVERE
	threshold_penalty = 15
	time_to_heal = 10 MINUTES
	status_effect_type = /datum/status_effect/wound/carapace_damaged/severe
	wound_traits = list(TRAIT_SERPENTID_ARMOR)
	simple_treat_text = "<b>Integrity of carapace</b> can be restored with gel and tape."
	homemade_treat_text = "<b>Cauterizing</b> can help to repair fractures."

/datum/wound_pregen_data/carapace_damaged/carapace_break_severe
	abstract = FALSE
	wound_path_to_generate = /datum/wound/carapace_damaged/severe
	threshold_minimum = 55

/datum/wound/carapace_damaged/critical
	name = "Critical carapace fractures"
	desc = "Patient's torso covered with huge amount of fractures and it's almost seen their internals."
	treat_text = "Treat torso with some cauterization tool or bone gel with surgical tape."
	examine_desc = "has a huge open fracture on their carapace"
	occur_text = "covering with huge fractures"
	severity = WOUND_SEVERITY_CRITICAL
	threshold_penalty = 25
	time_to_heal = 15 MINUTES
	status_effect_type = /datum/status_effect/wound/carapace_damaged/critical
	wound_traits = list(TRAIT_RESISTLOWPRESSURE, TRAIT_RESISTCOLD)
	simple_treat_text = "<b>Integrity of carapace</b> can be restored with gel and tape."
	homemade_treat_text = "<b>Cauterizing</b> can help to repair fractures."

/datum/wound_pregen_data/carapace_damaged/carapace_break_critical
	abstract = FALSE
	wound_path_to_generate = /datum/wound/carapace_damaged/critical
	threshold_minimum = 70

/datum/wound/carapace_damaged/apply_wound(obj/item/bodypart/L, silent, datum/wound/old_wound, smited, attack_direction, wound_source, replacing)
	. = ..()
	var/have_carapace = SEND_SIGNAL(victim, COMSIG_HAVE_CARAPACE)
	if(!ispath(L, /obj/item/bodypart/chest) || have_carapace)
		qdel(src)
	victim.throw_alert("carapace_break", alert_path)
	for(var/trait_macro in wound_traits)
		REMOVE_TRAIT(victim, trait_macro, "wound")

/datum/wound/carapace_damaged/remove_wound(ignore_limb, replaced = FALSE)
	. = ..()
	for(var/trait_macro in wound_traits)
		ADD_TRAIT(victim, trait_macro, "wound")

