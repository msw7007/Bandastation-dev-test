/datum/controller/subsystem/dynamic/fire(resumed)
	if(!COOLDOWN_FINISHED(src, midround_cooldown) || EMERGENCY_PAST_POINT_OF_NO_RETURN)
		return

	if(SSstoryteller.is_active())
		return

	if(COOLDOWN_FINISHED(src, light_ruleset_start))
		if(try_spawn_midround(LIGHT_MIDROUND))
			return

	if(COOLDOWN_FINISHED(src, heavy_ruleset_start))
		if(try_spawn_midround(HEAVY_MIDROUND))
			return

/datum/controller/subsystem/dynamic/on_latejoin(mob/living/carbon/human/latejoiner)
	if (!SSstoryteller.is_active())
		return ..()

	SSstoryteller.handle_latejoin(latejoiner)
	log_dynamic("Storyteller: Latejoin detected ([key_name(latejoiner)]), передано в storyteller.")

/datum/controller/subsystem/dynamic/proc/get_available_events(is_roundstart)
	var/list/available = list()
	var/population = length(GLOB.alive_player_list)

	var/list/antag_candidates = list()
	if(is_roundstart)
		for(var/mob/dead/new_player/player as anything in GLOB.new_player_list - SSjob.unassigned)
			if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
				antag_candidates += player

	var/num_real_players = is_roundstart ? length(antag_candidates) : population
	var/tier = SSdynamic.pick_tier(num_real_players)

	var/list/types_to_scan = is_roundstart
		? subtypesof(/datum/dynamic_ruleset/roundstart)
		: (subtypesof(/datum/dynamic_ruleset/midround) + subtypesof(/datum/dynamic_ruleset/latejoin))

	for(var/ruleset_type in types_to_scan)
		var/datum/dynamic_ruleset/R = new ruleset_type(dynamic_config)
		if(!R || !R.name)
			if(R) qdel(R)
			continue

		if(R.ruleset_flags == NONE)
			qdel(R)
			continue

		var/ruleset_weight = R.get_weight(population, tier)
		if(ruleset_weight <= 0 || !R.can_be_selected())
			qdel(R)
			continue

		var/list/meta = SSstoryteller.get_event_metadata("[R.type]") || list()

		available += list(list(
			"id" = "[R.type]",
			"name" = R.name,
			"weight" = round(ruleset_weight, 0.1),
			"target_roles" = "any",
			"tags" = "none",
			"type" = "ruleset",
			"phase" = is_roundstart ? "roundstart" : "mid_or_late"
		) + meta)

		qdel(R)

	return available

/datum/dynamic_ruleset/execute()
	. = ..()
	if(SSstoryteller.is_active())
		SSstoryteller.log_storyteller_decision(name)
