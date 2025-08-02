// dynamic_lmm_patch.dm
// Патч отключает автоспавн midround/latejoin и добавляет хук для LMM

// Переопределяем fire() так, чтобы Dynamic не спавнил midround
/datum/controller/subsystem/dynamic/fire(resumed)
	if(!COOLDOWN_FINISHED(src, midround_cooldown) || EMERGENCY_PAST_POINT_OF_NO_RETURN)
		return

	// Старое поведение: если LLMвыключен — работаем по-старому
	if(SSstoryteller.is_active())
		if(COOLDOWN_FINISHED(src, light_ruleset_start))
			if(try_spawn_midround(LIGHT_MIDROUND))
				return

		if(COOLDOWN_FINISHED(src, heavy_ruleset_start))
			if(try_spawn_midround(HEAVY_MIDROUND))
				return

// Отключаем автоматический latejoin тоже
/datum/controller/subsystem/dynamic/on_latejoin(mob/living/carbon/human/latejoiner)
	if (!SSstoryteller.is_active())
		// Старый код
		. = ..()
	else
		SSstoryteller.handle_latejoin(latejoiner)
		log_dynamic("LMM: Latejoin detected ([key_name(latejoiner)]), передано в storyteller.")

/datum/controller/subsystem/dynamic/proc/get_available_events(is_roundstart)
	var/list/available = list()
	var/population = length(GLOB.alive_player_list)

	// Считаем кандидатов для старта
	var/list/antag_candidates = list()
	if(is_roundstart)
		for(var/mob/dead/new_player/player as anything in GLOB.new_player_list - SSjob.unassigned)
			if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
				antag_candidates += player

	var/num_real_players = length(antag_candidates)
	var/tier = SSdynamic.pick_tier(num_real_players)

	// Какие типы рулсетов проверять
	var/list/types_to_scan = is_roundstart ? subtypesof(/datum/dynamic_ruleset/roundstart) : (subtypesof(/datum/dynamic_ruleset/midround) + subtypesof(/datum/dynamic_ruleset/latejoin))

	for(var/ruleset_type in types_to_scan)
		var/datum/dynamic_ruleset/R = new ruleset_type(dynamic_config)
		if(!R || !R.name)
			if(R) qdel(R)
			continue

		// Пропускаем чисто шаблонные (родительские) рулсеты без флагов
		if(R.ruleset_flags == NONE)
			qdel(R)
			continue

		var/ruleset_weight = R.get_weight(population, tier)
		if(ruleset_weight <= 0 || !R.can_be_selected())
			qdel(R)
			continue

		available += list(list(
			"id" = "[R.type]",
			"name" = R.name,
			"weight" = round(ruleset_weight, 0.1),
			"target_roles" = "any",
			"target_departs" = "any",
			"tags" = "ruleset",
			"type" = "ruleset"
		) + (SSstoryteller.get_event_metadata("[R.type]") || list()))

		qdel(R)

	return available

/datum/dynamic_ruleset/execute()
	. = ..()

	SSstoryteller.log_storyteller_decision(name)
