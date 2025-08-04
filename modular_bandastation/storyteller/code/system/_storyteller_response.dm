/datum/controller/subsystem/storyteller/proc/handle_lmm_result(list/decision)
	handle_lmm_decision(decision)
	generate_goals(decision["goals"])
	handle_goal_completion()

/datum/controller/subsystem/storyteller/proc/handle_lmm_decision(list/decision)
	if(!decision || !decision["event_id"] || !decision["type"])
		return

	var/event_id = decision["event_id"]
	var/type = decision["type"]
	dynamic_context = decision["dynamic_context"]

	// Запуск события
	trigger_decision(event_id, decision["targets"], decision["info"], type)

/datum/controller/subsystem/storyteller/proc/handle_roundstart_response(list/response)
	log_storyteller("Обработка roundstart-ответа от LLM")

	if(response["story_context"])
		story_context = response["story_context"]
		log_storyteller("Story context обновлён: [json_encode(story_context)]")

	if(response["decisions"])
		for(var/list/decision in response["decisions"])
			if(!decision["event_id"] || !decision["type"])
				continue

			pending_decisions[decision["event_id"]] = list(
				"info" = decision["info"],
				"targets" = decision["targets"],
				"type" = decision["type"]
			)
			handle_lmm_decision(decision)
	generate_goals(response["goals"])

/datum/controller/subsystem/storyteller/proc/generate_goals(goals_list)
	if (!islist(goals_list) || !length(goals_list))
		return

	for (var/goal_data in goals_list)
		if (!islist(goal_data))
			continue

		var/name = goal_data["name"]
		var/type_str = goal_data["type"]

		if (type_str && ispath(text2path(type_str), /datum/station_goal))
			var/path = text2path(type_str)
			if (!ispath(path, /datum/station_goal))
				continue

			if (SSstation.goals_by_type[path])
				log_storyteller("ST: goal [path] уже существует, пропускаю")
				continue

			new path()
			log_storyteller("Storyteller: Added DM-defined goal: [name]")
		else
			// Кастомная цель от нейросети
			var/list/custom_goal = list(
				"name" = name,
				"description" = goal_data["description"],
				"completed" = goal_data["completed"] ? 1 : 0,
				"requires_space" = goal_data["requires_space"],
				"required_crew" = goal_data["required_crew"]
			)
			add_custom_goal(custom_goal)
			log_storyteller("Storyteller: Added custom goal: [name]")

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

/datum/controller/subsystem/storyteller/proc/handle_goal_completion()
	// Обработка завершённых кастомных целей (completed == 2)
	for (var/i in 1 to custom_storyteller_goals.len)
		var/list/goal = custom_storyteller_goals[i]
		if (!islist(goal))
			continue

		if (goal["completed"] == 2)
			var/name = goal["name"] || "Неизвестная цель"
			var/description = goal["description"] || "Нет описания"

			// Объявление для экипажа (можно заменить на announce или факс)
			world << "<span class='notice'>Цель «[name]» выполнена!</span>"

			// Лог для админов / внешних логов
			log_storyteller("Storyteller: Цель завершена: [name] — [description]")

			// Обновляем статус цели
			goal["completed"] = 1

			// Обновляем список (нужно, потому что list по значению)
			custom_storyteller_goals[i] = goal
