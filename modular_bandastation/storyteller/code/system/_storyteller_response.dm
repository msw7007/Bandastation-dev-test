// ----------------------------------------------------------
// Локальный выбор и запуск одного события/рулсета
// Возвращает TRUE, если что-то запустили
// ----------------------------------------------------------
/datum/controller/subsystem/storyteller/proc/decide_and_trigger(is_roundstart = FALSE)
	// 0) кандидаты
	var/list/candidates = collect_available_events(is_roundstart)
	if(!islist(candidates) || !candidates.len)
		return FALSE

	// 1) профиль вкусов и настроек
	var/datum/storyteller_profile/P = get_current_profile_datum()
	var/list/profile = get_current_profile() || list()
	var/list/att = islist(profile["attention_tags"]) ? profile["attention_tags"] : list()
	var/list/ign = islist(profile["ignore_tags"]) ? profile["ignore_tags"] : list()
	var/list/pref_deps = islist(profile["preferred_targets"]) ? profile["preferred_targets"] : list()

	var/deadband = P?.deadband || 5
	var/min_gap  = (P?.min_gap_sec || 180) SECONDS
	var/allow_force = P?.allow_force_pick ? TRUE : FALSE
	var/assist_window = P?.assist_window || 0
	var/assist_prob   = P?.assist_prob || 0

	// 2) бюджет хаоса
	var/list/chaos = compute_target_chaos_and_budget()
	if(!islist(chaos)) return FALSE
	var/budget = chaos["budget"] || 0
	var/abs_budget = abs(budget)

	// 2a) если недавно стреляли — спим
	if(world.time - last_decision_ts < min_gap)
		return FALSE

	// 2b) deadband вокруг нуля — вероятностно дропаём
	if(deadband > 0 && abs_budget <= deadband)
		var/p_base = clamp(1.0 - (abs_budget / deadband), 0.0, 1.0)
		if(prob(p_base * 100))
			return FALSE

	// 3) рантайм-кулдауны
	if(!islist(src.event_runtime)) src.event_runtime = list()
	// event_runtime[id] = list("last_ts"=..., "times"=...)

	// 4) скоринг и фильтр кулдаунов/одноразовости
	var/list/scored = list()
	for(var/list/E in candidates)
		var/id = "[E["id"]]"
		var/type = "[E["type"]]" // "event" | "ruleset" | "latejoin"
		var/name = E["name"] || id
		var/weight = max(0.1, E["weight"] || 1)
		var/impact = max(1, E["chaos_impact"] || 1)

		// метаданные из TOML
		var/list/meta = get_event_metadata(id) || list()
		var/cooldown = (meta["cooldown"] || 300) SECONDS
		var/no_repeat = meta["no_repeat"] ? TRUE : FALSE

		var/list/rt = src.event_runtime[id]
		// одноразовое — если уже было, скипаем
		if(no_repeat && islist(rt) && (rt["times"] || 0) > 0)
			continue
		// кулдаун — если не прошёл, скипаем
		if(islist(rt))
			if(world.time - (rt["last_ts"] || 0) < cooldown)
				continue

		// вкусы профиля: attention +1, ignore -∞ (обнуляем вес), preferred_deps +1
		var/taste = 0
		var/list/tags = list()
		if(islist(E["tags"])) tags = E["tags"]
		else if(istext(E["tags"])) tags = splittext(E["tags"], ",")

		var/ignored_hit = FALSE
		for(var/t in tags)
			var/tt = lowertext(trim("[t]"))
			if(tt in ign)
				ignored_hit = TRUE
				break
			if(tt in att) taste += 1
		if(ignored_hit)
			// игнор-тег: вес = 0, но можно ещё дать лёгкий минус к score,
			// чтобы точно утонул среди остальных
			weight = 0
			taste -= 0.5

		// итоговый скор
		var/score = weight + taste
		if(budget < 0)
			score = score / (1 + impact/10.0)
		else
			score = score * (1 + min(0.5, budget/100.0)) + (impact * 0.1)

		var/dept_mult = 1.0
		var/dep = "[E["target_departs"] || ""]"
		if (length(dep))
			var/list/st = cached_state?["state"]?["departments"]?[dep]
			if (islist(st))
				var/str = clamp(st?["avg_exp"] || 0, 0, 100) / 100.0 // 0..1
				var/base_cap = (dep in pref_deps) ? 3.0 : 2.0
				dept_mult = base_cap * str

		score = score * dept_mult

		// лёгкая защита от повтора
		if(islist(rt))
			var/times = rt["times"] || 0
			score = score / (1 + times * 0.25)

		var/list/phase = get_current_phase_info()
		var/list/pool_ids = islist(phase["pool"]) ? phase["pool"] : list()
		if(id in pool_ids)
			score *= P.phase_pool_boost

		scored += list(list(
			"id" = id,
			"type" = type,
			"name" = name,
			"score" = score,
			"impact" = impact
		))

	if(!scored.len) return FALSE

	// 5) сортировка по score
	scored = sortTim(scored, GLOBAL_PROC_REF(st_cmp_desc))

	// 6) выбор кандидата (бюджет/ассист/форс)
	var/list/pick = null
	if(budget >= 0)
		for(var/list/S in scored)
			if(S["impact"] <= budget) { pick = S; break }

		if(!islist(pick) && assist_window > 0)
			var/list/best = null
			var/best_def = 1e9
			for(var/list/S2 in scored)
				var/def = (S2["impact"] - budget)
				if(def > 0 && def <= assist_window && def < best_def)
					best_def = def; best = S2
			if(islist(best) && (assist_prob <= 0 || prob(assist_prob)))
				pick = best

		if(!islist(pick) && allow_force)
			pick = scored[1]
	else
		if(assist_window > 0 && abs_budget <= assist_window && (assist_prob <= 0 || prob(assist_prob)))
			var/minImpact = 1e9
			for(var/list/S3 in scored)
				if(S3["impact"] < minImpact)
					minImpact = S3["impact"]; pick = S3

	if(!islist(pick)) return FALSE

	// 7) запуск
	var/id_pick = pick["id"]
	var/type_pick = pick["type"]
	var/success = trigger_decision(id_pick, null, list("source"="local"), type_pick)

	// 8) обновить рантайм + зафиксировать gap/историю
	if(success)
		if(!islist(src.event_runtime[id_pick])) src.event_runtime[id_pick] = list("last_ts"=0, "times"=0)
		src.event_runtime[id_pick]["last_ts"] = world.time
		src.event_runtime[id_pick]["times"] = (src.event_runtime[id_pick]["times"] || 0) + 1
		last_decision_ts = world.time
		log_storyteller("Local decide: started [id_pick] ([type_pick]); budget=[budget]")
		st_history_add("local_decision", list("id"=id_pick, "type"=type_pick, "budget"=budget))
		return TRUE

	return FALSE

// ----------------------------------------------------------
// Непосредственный запуск выбранного события / рулсета
// Учитывает cooldown/no_repeat из TOML, если не форс.
// Возвращает TRUE, если запустили.
// ----------------------------------------------------------
/datum/controller/subsystem/storyteller/proc/trigger_decision(event_id, targets, info, type)
	var/force = islist(info) ? (info["force"] ? TRUE : FALSE) : FALSE

	// запреты повторов/кулдауна (если не форс)
	if(!force)
		var/list/meta = get_event_metadata(event_id) || list()
		var/cooldown = (meta["cooldown"] || 300) SECONDS
		var/no_repeat = meta["no_repeat"] ? TRUE : FALSE
		var/list/rt = src.event_runtime[event_id]

		if(no_repeat && islist(rt) && (rt["times"] || 0) > 0)
			log_storyteller("Trigger blocked by no_repeat: [event_id]")
			return FALSE
		if(islist(rt))
			if(world.time - (rt["last_ts"] || 0) < cooldown)
				log_storyteller("Trigger blocked by cooldown: [event_id]")
				return FALSE

	if(type == "event")
		var/datum/round_event_control/E
		for(var/datum/round_event_control/C in SSevents.control)
			if("[C.type]" == event_id) // сравнение по строке типа
				E = C
				break
		if(E)
			if (force)
				E.run_event(random = TRUE)
			else
				SSevents.TriggerEvent(E)
		else
			log_game("Storyteller: event id not found [event_id]")
			return FALSE

	else if(type == "ruleset" || type == "latejoin")
		var/path = text2path(event_id)
		if(!ispath(path, /datum/dynamic_ruleset))
			log_game("Storyteller: Invalid ruleset path [event_id]")
			return FALSE

		// если есть конфиг динамики — лучше передать его в конструктор
		var/datum/dynamic_ruleset/R = new path(SSdynamic?.dynamic_config)
		if(!R)
			log_game("Storyteller: Failed to create ruleset [event_id]")
			return FALSE

		var/list/candidates = list()
		if(type == "latejoin")
			if(!length(targets) || !istype(targets[1], /mob/living))
				log_game("Storyteller: Invalid latejoin target for [event_id]")
				qdel(R)
				return FALSE
			candidates = list(targets[1])
		else
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
	var/list/meta = get_event_metadata(event_id) || list()
	var/inject_val = meta["chaos_impact"] || 5
	add_chaos_injection("[event_id]", inject_val, 5 MINUTES)
	return TRUE

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
	st_history_add("llm_decision", list(
		"id" = event_id, "type" = type, "info" = "[decision["info"]]"
	))

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

	st_history_add("goal_added", list("name" = name))

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

	print_command_report(list("[body]\n\n— [signature]"), "[subject]", announce=FALSE)

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

	st_history_add("announce", list("count" = length(announcements)))

/datum/controller/subsystem/storyteller/proc/add_custom_goal(goal)
	if(!islist(goal))
		return
	custom_storyteller_goals += list(goal)

/datum/controller/subsystem/storyteller/proc/decide_latejoin_local(mob/living/carbon/human/player, list/candidates)
	if(!islist(candidates) || !candidates.len || !player)
		return FALSE

	// Профильные вкусы
	var/list/profile = get_current_profile() || list()
	var/list/att_list = islist(profile["attention_tags"]) ? profile["attention_tags"] : list()
	var/list/ign_list = islist(profile["ignore_tags"]) ? profile["ignore_tags"] : list()
	var/list/pref_deps = islist(profile["preferred_targets"]) ? profile["preferred_targets"] : list()

	var/list/att_map = list()
	for(var/t in att_list)
		if(!istext(t)) continue
		var/line = lowertext("[t]")
		var/list/parts = splittext(line, ":")
		var/tag = trim(parts[1])
		if(!length(tag)) continue
		var/mul = 2.0
		if(length(parts) >= 2)
			var/val = text2num(parts[2])
			if(isnum(val) && val > 0) mul = val
		att_map[tag] = mul

	var/list/ign_set = list()
	for(var/t2 in ign_list)
		if(!istext(t2)) continue
		ign_set[lowertext(trim("[t2]"))] = TRUE

	// Бюджет хаоса
	var/list/chaos = compute_target_chaos_and_budget()
	var/budget = chaos?["budget"] || 0

	if(!islist(src.event_runtime)) src.event_runtime = list()

	// Скоринг
	var/list/scored = list()
	for(var/list/E in candidates)
		var/id = "[E["id"]]"
		var/name = E["name"] || id
		var/base_weight = max(0.1, E["weight"] || 1)
		var/impact = max(1, E["chaos_impact"] || 1)

		// Метаданные
		var/list/meta = get_event_metadata(id) || list()
		var/cooldown = (meta["cooldown"] || E["cooldown"] || 300) SECONDS
		var/no_repeat = meta["no_repeat"] ? TRUE : FALSE

		// Runtime-фильтры
		var/list/rt = src.event_runtime[id]
		if(islist(rt))
			if(world.time - (rt["last_ts"] || 0) < cooldown)
				continue
			if(no_repeat && (rt["times"] || 0) >= 1)
				continue

		// Теги
		var/list/tags = list()
		if(islist(E["tags"])) tags = E["tags"]
		else if(istext(E["tags"])) tags = splittext(E["tags"], ",")

		// Attention/Ignore
		var/ignore_hit = FALSE
		var/mult = 1.0
		for(var/t in tags)
			var/tt = lowertext(trim("[t]"))
			if(ign_set[tt]) { ignore_hit = TRUE; break }
			if(att_map[tt]) mult = max(mult, att_map[tt])
		if(ignore_hit) mult = 0.0

		// Деп-бонусы
		var/dep = "[E["target_departs"] || ""]"
		var/dep_bonus = (dep && (dep in pref_deps)) ? 0.5 : 0

		var/score = (base_weight * mult) + dep_bonus
		if(budget < 0)
			score = score / (1 + impact/10.0)
		else
			score = score * (1 + min(0.5, budget/100.0)) + (impact * 0.1)

		if(islist(rt))
			var/times = rt["times"] || 0
			score = score / (1 + times * 0.25)

		scored += list(list(
			"id" = id,
			"name" = name,
			"impact" = impact,
			"score" = round(score, 0.1),
			"cooldown" = cooldown,
			"no_repeat" = no_repeat
		))

	if(!scored.len)
		return FALSE

	// Сортировка по score убыв.
	scored = sortTim(scored, GLOBAL_PROC_REF(st2_cmp_desc))

	// Лучший кандидат
	var/list/pick = scored[1]
	if(!islist(pick))
		return FALSE

	var/id_pick = pick["id"]
	var/ok = trigger_decision(id_pick, player, list("source"="latejoin_local"), "ruleset")
	if(ok)
		if(!islist(src.event_runtime[id_pick]))
			src.event_runtime[id_pick] = list("last_ts"=0, "times"=0)
		src.event_runtime[id_pick]["last_ts"] = world.time
		src.event_runtime[id_pick]["times"] = (src.event_runtime[id_pick]["times"] || 0) + 1

		st_history_add("latejoin_local_fire", list(
			"id" = id_pick,
			"ckey" = player.client.ckey,
			"score" = pick["score"],
			"impact" = pick["impact"],
		))
		return TRUE

	st_history_add("latejoin_local_fail", list(
		"id" = id_pick,
		"ckey" = player.client.ckey
	))
	return FALSE
