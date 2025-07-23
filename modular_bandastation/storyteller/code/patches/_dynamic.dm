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
	if (SSstoryteller.is_active())
		// Старый код
		. = ..()
	else
		log_dynamic("LMM: Latejoin detected ([key_name(latejoiner)]), передано в storyteller.")

/datum/controller/subsystem/dynamic/proc/get_available_events(is_roundstart)
	var/list/available = list()
	var/population = length(GLOB.alive_player_list)

	var/list/antag_candidates = list()
	if(is_roundstart)
		for(var/mob/dead/new_player/player as anything in GLOB.new_player_list - SSjob.unassigned)
			if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
				antag_candidates += player

	var/num_real_players = length(antag_candidates)
	var/tier = SSdynamic.pick_tier(num_real_players) // если у тебя есть метод для тира, иначе жёстко задать LOW или MEDIUM

	if (is_roundstart)
		// Берём только стартовые рулсеты (как get_roundstart_rulesets)
		for (var/ruleset_type in subtypesof(/datum/dynamic_ruleset/roundstart))
			var/datum/dynamic_ruleset/roundstart/R = new ruleset_type(dynamic_config)
			var/ruleset_weight = R.get_weight(population, tier)
			if (ruleset_weight <= 0 || !R.can_be_selected())
				continue

			available += list(list(
				"id" = "[R.type]",
				"name" = R.name,
				"weight" = round(ruleset_weight, 0.1),
				"target_roles" = "any",
				"target_departs" = "any",
				"tags" = "ruleset",
				"influence" = "moderate",
				"type" = "ruleset"
			))
	else
		// Собираем все midround и latejoin рулсеты
		for (var/ruleset_type in subtypesof(/datum/dynamic_ruleset/midround) + subtypesof(/datum/dynamic_ruleset/latejoin))
			var/datum/dynamic_ruleset/R = new ruleset_type(dynamic_config)
			var/ruleset_weight = R.get_weight(population, tier)
			if (ruleset_weight <= 0 || !R.can_be_selected())
				continue

			available += list(list(
				"id" = "[R.type]",
				"name" = R.name,
				"weight" = round(ruleset_weight, 0.1),
				"target_roles" = "any",
				"target_departs" = "any",
				"tags" = "ruleset",
				"influence" = "moderate",
				"type" = "ruleset"
			))

	return available

