/datum/controller/subsystem/storyteller/proc/handle_lmm_decision(list/decision)
	if(!decision || !decision["event_id"] || !decision["type"])
		return

	var/event_id = decision["event_id"]
	var/type = decision["type"]

	// Запуск события
	trigger_decision(event_id, decision["targets"], decision["info"], type)

/datum/controller/subsystem/storyteller/proc/trigger_decision(event_id, targets, info, type)
	if(type == "event")
		var/datum/round_event_control/E
		for(var/datum/round_event_control/C in SSevents.control)
			if("[C.type]" == event_id) // Сравниваем строку
				E = C
				break

		if(E)
			SSevents.TriggerEvent(E)

	else if(type == "ruleset" || type == "latejoin") // latejoin — тот же ruleset, но с конкретной целью
		var/path = text2path(event_id)
		if(!ispath(path, /datum/dynamic_ruleset))
			log_game("Storyteller: Invalid ruleset path [event_id]")
			return FALSE

		var/datum/dynamic_ruleset/R = new path(null)
		if(!R)
			log_game("Storyteller: Failed to create ruleset [event_id]")
			return FALSE

		var/list/candidates = list()

		if(type == "latejoin")
			// Целевой кандидат обязателен
			if(!length(targets) || !istype(targets[1], /mob/living))
				log_game("Storyteller: Invalid latejoin target for [event_id]")
				qdel(R)
				return FALSE

			candidates = list(targets[1])
		else
			// Стандартный подбор кандидатов
			if(istype(R, /datum/dynamic_ruleset/roundstart))
				for(var/mob/dead/new_player/player as anything in GLOB.new_player_list - SSjob.unassigned)
					if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
						candidates += player
			else if(istype(R, /datum/dynamic_ruleset/midround))
				var/datum/dynamic_ruleset/midround/collector = R
				candidates = collector.collect_candidates() || list()
			else if(istype(R, /datum/dynamic_ruleset/latejoin))
				candidates = GLOB.alive_player_list.Copy()

		if(!length(candidates))
			log_game("Storyteller: Ruleset [event_id] has no valid candidates.")
			qdel(R)
			return FALSE

		candidates = R.trim_candidates(candidates)

		if(!R.prepare_execution(length(candidates), candidates))
			log_game("Storyteller: Ruleset [event_id] could not prepare (no valid candidates).")
			qdel(R)
			return FALSE

		R.execute()
		SSdynamic.executed_rulesets += R

	log_storyteller("Storyteller: Triggering [event_id], targets: [targets], info: [info]")
	// Позже: вызов через Event Controller или прямой запуск
