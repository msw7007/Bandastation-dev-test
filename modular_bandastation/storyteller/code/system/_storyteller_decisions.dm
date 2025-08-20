/datum/controller/subsystem/storyteller/proc/handle_lmm_result(list/decision)
	handle_lmm_decision(decision)
	generate_goals(decision["goals"])
	handle_goal_completion(decision)
	apply_antag_mission_changes(decision)
	if(islist(decision["announcements"]) && length(decision["announcements"]))
		apply_announcements(decision["announcements"])

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
				"required_crew" = goal_data["required_crew"],
				"completion_hint" = goal_data["completion_hint"]
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

/datum/controller/subsystem/storyteller/proc/handle_goal_completion(list/result)
	if (!islist(result))
		return

	var/list/updated_goal = result["goal"]
	if (!islist(updated_goal))
		return

	var/name = updated_goal["name"]
	if (!name)
		return

	for (var/i in 1 to custom_storyteller_goals.len)
		var/list/original_goal = custom_storyteller_goals[i]
		if (!islist(original_goal))
			continue

		if (original_goal["name"] != name)
			continue

		if (updated_goal["completed"] == 2)
			var/description = updated_goal["description"] || "Нет описания"

			world << "<span class='notice'>Цель «[name]» выполнена!</span>"
			log_storyteller("Storyteller: Цель завершена: [name] — [description]")

			updated_goal["completed"] = 1
			custom_storyteller_goals[i] = updated_goal

		break // цель найдена и обновлена, дальше не идём

/datum/controller/subsystem/storyteller/proc/apply_antag_mission_changes(list/result)
	if (!islist(result))
		return

	var/list/decisions = result["decisions"]
	var/dynamic_context = result["dynamic_context"]

	if (istext(dynamic_context) && length(dynamic_context))
		log_storyteller("ANTAG CONTEXT UPDATE", list("ctx" = dynamic_context))

	if (!islist(decisions))
		return

	for (var/entry in decisions)
		if (!islist(entry))
			continue

		var/ckey = entry["ckey"]
		var/notify = entry["notify_player"]
		var/list/actions = entry["actions"]

		if (!ckey || !islist(actions) || !length(actions))
			continue

		var/datum/antagonist/antag = locate_antag_by_ckey(ckey)
		if (!antag)
			log_storyteller("apply_antag_mission_changes: antagonist not found", list("ckey" = ckey))
			continue

		apply_actions_to_antag(antag, actions, notify)

/datum/controller/subsystem/storyteller/proc/locate_antag_by_ckey(ckey)
	for (var/datum/antagonist/A in GLOB.antagonists)
		if (A.owner && A.owner.key == ckey)
			return A
	return null

/datum/controller/subsystem/storyteller/proc/apply_actions_to_antag(datum/antagonist/A, list/actions, notify_player = FALSE)
	var/mob/living/carbon/human/H = A.owner?.current
	for (var/action in actions)
		if (!islist(action)) continue
		var/op = lowertext(action["op"] || "")
		switch(op)
			if ("add")
				var/text = action["text"]
				if (istext(text) && length(text))
					st_add_custom_objective(A, text)
					log_storyteller("ANTAG ADD OBJ", list("ckey"=A.owner?.key, "text"=text))
			if ("remove")
				var/match = action["match"]
				if (istext(match) && length(match))
					var/removed = st_remove_objectives_by_match(A, match)
					log_storyteller("ANTAG REMOVE OBJ", list("ckey"=A.owner?.key, "match"=match, "removed"=removed))
			if ("replace")
				var/old_match = action["match"]
				var/new_text = action["text"]
				if (istext(old_match) && istext(new_text) && length(new_text))
					var/removed = st_remove_objectives_by_match(A, old_match)
					if (removed)
						st_add_custom_objective(A, new_text)
						log_storyteller("ANTAG REPLACE OBJ", list("ckey"=A.owner?.key, "from"=old_match, "to"=new_text))
			if ("retag")
				var/style = action["style"]
				// тут можно выставлять внутренние флаги/поведение
				log_storyteller("ANTAG RETAG", list("ckey"=A.owner?.key, "style"=style))
			else
				log_storyteller("ANTAG UNKNOWN OP", list("op"=op))

	if (notify_player && H)
		to_chat(H, "<span class='notice'>Ваши цели были обновлены Сторителлером.</span>")

/datum/controller/subsystem/storyteller/proc/st_add_custom_objective(datum/antagonist/A, text)
	var/datum/objective/custom/O = new
	O.explanation_text = text
	A.objectives += O

/datum/controller/subsystem/storyteller/proc/st_remove_objectives_by_match(datum/antagonist/A, match)
	var/removed = 0
	for (var/datum/objective/O in A.objectives.Copy())
		if (findtext("[O.explanation_text]", "[match]"))
			A.objectives -= O
			qdel(O)
			removed++
	return removed

/datum/controller/subsystem/storyteller/proc/st_broadcast_announce(
	org = "cc",
	text,
	title = null,
	important = TRUE,
	force = FALSE
)
	if(!istext(text) || !length(text))
		return

	var/l_org = lowertext("[org]")

	if(l_org == "cc")
		last_cc_announce = world.time
		if(!title) title = "Центральное Командование"
		priority_announce(text, title)
		log_storyteller("CC ANNOUNCE", list("title"=title, "text"=text))
		return

	if(l_org == "syndicate")
		last_syndi_announce = world.time
		if(!title) title = "Синдикат"
		priority_announce(text, title)
		log_storyteller("SYNDI ANNOUNCE", list("title"=title, "text"=text))
		return

	// Кастомный источник (fallback тем же priority_announce)
	if(!title) title = uppertext(org)
	priority_announce(text, title)
	log_storyteller("GENERIC ANNOUNCE", list("org"=org, "title"=title, "text"=text))

/datum/controller/subsystem/storyteller/proc/st_send_fax(
	org = "cc",
	subject = "Директива",
	body = "",
	signature = "Central Command"
)
	if(!istext(body) || !length(body))
		return

	print_command_report(list("[body]\n\n— [signature]"), "[command_name()] Status Summary", announce=FALSE)

/datum/controller/subsystem/storyteller/proc/apply_announcements(list/announcements)
	if(!islist(announcements) || !length(announcements))
		return

	for(var/entry in announcements)
		if(!islist(entry))
			continue

		var/channel = lowertext(entry["channel"] || "announce")
		var/title   = entry["title"] || null
		var/text    = entry["text"]  || ""
		var/force   = entry["force"] ? TRUE : FALSE

		if(!length(text))
			continue

		switch(channel)
			if("cc")
				st_broadcast_announce("cc", text, title, TRUE, force)
			if("syndicate")
				st_broadcast_announce("syndicate", text, title, TRUE, force)
			if("announce") // кастом/дефолт
				st_broadcast_announce("custom", text, title, TRUE, force)
			if("fax_cc")
				var/subject = entry["subject"] || (title || "Директива ЦК")
				var/sign    = entry["signature"] || "Central Command"
				st_send_fax("cc", subject, text, sign)
			if("fax_syndicate")
				var/subject2 = entry["subject"] || (title || "Сообщение Синдиката")
				var/sign2    = entry["signature"] || "Syndicate"
				st_send_fax("syndicate", subject2, text, sign2)
			else
				// неизвестный канал — просто широковещалка под его же названием
				st_broadcast_announce(channel, text, title, TRUE, force)
