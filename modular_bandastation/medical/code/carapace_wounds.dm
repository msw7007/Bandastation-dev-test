//////////////////////////////////////////////////////////////////
//			Травмы для отслеживания урона панциря				//
//////////////////////////////////////////////////////////////////
/datum/wound/carapace_damaged
	name = "Internal Bleeding"
	sound_effect = 'sound/items/weapons/slice.ogg'
	processes = TRUE
	treatable_tools = list(TOOL_HEMOSTAT)
	base_treat_time = 5 SECONDS
	wound_flags = MANGLES_INTERIOR

	/// Насколько увеличивается входящий по кукле урон на этом уровне травмы
	var/carapace_damage_mult
	/// Сколько урона должна получить кукла, чтобы заработать данную травму
	var/carapace_damage_threshold

/datum/wound/carapace_damaged/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	if(limb.can_bleed() && attack_direction && victim.blood_volume > BLOOD_VOLUME_OKAY)
		victim.spray_blood(attack_direction, severity)

	return ..()

/datum/wound/carapace_damaged/receive_damage(wounding_type, wounding_dmg, wound_bonus)
	if(victim.stat == DEAD || (wounding_dmg < 5) || !limb.can_bleed() || !victim.blood_volume)
		return
	carapace_damage_mult += wounding_dmg
	victim.visible_message("<span class='smalldanger'>Blood droplets fly from [victim]'s carapace.</span>", span_danger("You spray a bit of blood from the blow."), vision_distance=COMBAT_MESSAGE_RANGE)
	var/blood_bled = wounding_dmg / 10
	victim.bleed(blood_bled, TRUE)

/datum/wound/carapace_damaged/handle_process(seconds_per_tick, times_fired)
	if (!victim || HAS_TRAIT(victim, TRAIT_STASIS))
		return

	if(carapace_damage_mult <= 0)
		qdel(src)

/datum/wound/carapace_damaged/treat(obj/item/I, mob/user)
	if(I.tool_behaviour == TOOL_HEMOSTAT || I.get_temperature())
		return tool_clamping(I, user)

/datum/wound/carapace_damaged/on_xadone(power)
	. = ..()

	if (limb) // parent can cause us to be removed, so its reasonable to check if we're still applied
		carapace_damage_mult -= 0.1 // i think it's like a minimum of 3 power, so .09 blood_flow reduction per tick is pretty good for 0 effort

/// Полевое лечение
/datum/wound/carapace_damaged/proc/tool_clamping(obj/item/I, mob/user)

	var/improv_penalty_mult = (I.tool_behaviour == TOOL_HEMOSTAT ? 1 : 1.25) // 25% longer and less effective if you don't use a real hemostat
	var/self_penalty_mult = (user == victim ? 1.5 : 1) // 50% longer and less effective if you do it to yourself
	var/pierce_founded = FALSE
	var/treatment_delay = base_treat_time * self_penalty_mult * improv_penalty_mult

	if(HAS_TRAIT(src, TRAIT_WOUND_SCANNED))
		treatment_delay *= 0.5
		user.visible_message(span_danger("[user] begins expertly restore internals in [victim]'s [limb.plaintext_zone] with [I]..."), span_warning("You begin restoring internals in [user == victim ? "your" : "[victim]'s"] [limb.plaintext_zone] with [I], keeping the holo-image indications in mind..."))
	else
		user.visible_message(span_danger("[user] begins restoring internals in [victim]'s [limb.plaintext_zone] with [I]..."), span_warning("You begin restoring internals in [user == victim ? "your" : "[victim]'s"] [limb.plaintext_zone] with [I]..."))

	for(var/limb_wound in limb.wounds)
		var/datum/wound/current_wound = limb_wound
		if(istype(current_wound, /datum/wound/pierce))
			pierce_founded = TRUE

	if (!(pierce_founded))
		return TRUE

	if(!do_after(user, treatment_delay, target = victim, extra_checks = CALLBACK(src, PROC_REF(still_exists))))
		return TRUE

	var/varing_wording = (!limb.can_bleed() ? "holes" : "bleeding")
	user.visible_message(span_green("[user] restore internals in [victim]."), span_green("You restore internals with reducing some of the [varing_wording] on [victim]."))
	if(prob(30))
		victim.emote("scream")
	var/blood_cauterized = (0.6 / (self_penalty_mult * improv_penalty_mult))
	adjust_blood_flow(-blood_cauterized)

	if(blood_flow > 0)
		return try_treating(I, user)
	return TRUE

/datum/wound_pregen_data/flesh_carapace_damaged
	abstract = TRUE

	required_limb_biostate = (BIO_FLESH)
	required_wounding_types = list(WOUND_BLUNT)

	wound_series = WOUND_SERIES_CARAPACE_DAMAGED

/datum/wound/carapace_damaged/get_limb_examine_description()
	return span_warning("The flesh on this limb appears heavy buldged")

/datum/wound/carapace_damaged/moderate
	name = "Minor internal bleeding"
	desc = "Patient's skin has been formed some kind of bulge. Look a like there is a little intrnal bleed."
	treat_text = "Treat affected site with cautarizing inside after piecring patient's skin." // space is cold in ss13, so it's like an ice pack!
	examine_desc = "has a small bulge"
	occur_text = "spurts out a thin stream of blood"
	severity = WOUND_SEVERITY_MODERATE
	threshold_penalty = 5

	status_effect_type = /datum/status_effect/wound/carapace_damaged/moderate

	simple_treat_text = "<b>Internal bleeding operation</b> the wound will remove blood loss, help the wound close by itself quicker, and speed up the blood recovery period."
	homemade_treat_text = "<b>Cauterizing</b> can help to close wounds inside, but you need some small hole to get there."

/datum/wound_pregen_data/flesh_carapace_damaged/light_cd
	abstract = FALSE

	wound_path_to_generate = /datum/wound/carapace_damaged/moderate

	threshold_minimum = 40

/datum/wound/carapace_damaged/moderate/update_descriptions()
	if(!limb.can_bleed())
		examine_desc = "has a small, circular hole"
		occur_text = "splits a small hole open"

/datum/wound/carapace_damaged/severe
	name = "Noticable internal bleeding"
	desc = "Patient's internal tissue is penetrated, causing sizeable internal bleeding and reduced limb stability."
	treat_text = "Repair internals under skin by cautery throught some kind of hole."
	examine_desc = "is a noticable buldge under skin on their limb"
	occur_text = "looses a violent spray of blood"
	severity = WOUND_SEVERITY_SEVERE
	threshold_penalty = 15

	status_effect_type = /datum/status_effect/wound/carapace_damaged/severe

	simple_treat_text = "<b>Internal bleeding operation</b> the wound will remove blood loss, help the wound close by itself quicker, and speed up the blood recovery period."
	homemade_treat_text = "<b>Cauterizing</b> can help to close wounds inside, but you need some small hole to get there."

/datum/wound_pregen_data/flesh_carapace_damaged/medium_cd
	abstract = FALSE

	wound_path_to_generate = /datum/wound/carapace_damaged/severe

	threshold_minimum = 55

/datum/wound/carapace_damaged/severe/update_descriptions()
	if(!limb.can_bleed())
		occur_text = "tears a hole open"

/datum/wound/carapace_damaged/critical
	name = "Ruptured internals"
	desc = "Patient's internal tissue and circulatory system is shredded, causing significant internal bleeding and damage to internal organs."
	treat_text = "Surgical repair of internal bleeding throught puncture wound, followed by supervised resanguination."
	examine_desc = "is forming big buldge under their skin and you hear some sorts of hoarseness"
	occur_text = "blasts apart, sending chunks of viscera flying in all directions"
	severity = WOUND_SEVERITY_CRITICAL
	initial_flow = 6
	carapace_damageding_chance = 150
	carapace_damageding_coefficient = 4.75
	threshold_penalty = 25
	heart_attack_chance = 2
	lungs_damage = 5
	status_effect_type = /datum/status_effect/wound/carapace_damaged/critical

	simple_treat_text = "<b>Internal bleeding operation</b> the wound will remove blood loss, help the wound close by itself quicker, and speed up the blood recovery period."
	homemade_treat_text = "<b>Cauterizing</b> can help to close wounds inside, but you need some small hole to get there."

/datum/wound_pregen_data/flesh_carapace_damaged/heavy_cd
	abstract = FALSE

	wound_path_to_generate = /datum/wound/carapace_damaged/critical

	threshold_minimum = 70
