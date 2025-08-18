// storyteller.dm
#define USE_LMM_STORYTELLER TRUE
#define LOG_CATEGORY_STORYTELLER "dynamic"

SUBSYSTEM_DEF(storyteller)
	name = "Storyteller"
	wait = 2 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	runlevels = RUNLEVEL_GAME
	/// Внутренний счётчик тиков (чтобы ЛММ знала время)
	var/ticks_passed = 0
	/// Состояние активного (будет получаться через конфиг)
	var/active = TRUE
	/// Список собарнных из томла метаданных событий и рулсетов
	var/list/storyteller_event_metadata = list()
	/// Список всех сторителлеров
	var/list/storyteller_profiles = list()
	/// Текущий выбранный СТ
	var/current_storyteller_profile = null
	/// Лог событий, который хочет применить СТ
	var/list/pending_decisions = list()
	/// Лог событий, который применил СТ
	var/list/history_log = list()
	// Текущий сценарий, что произошло, сюжетные фазы
	var/story_context = list(
		list(
			"phase" = null,
			"passed" = FALSE,
			"estimated_time" = null
		)
	)
	// Подсказка от самого LLM себе же
	var/dynamic_context = ""
	// Состояние станции
	var/list/cached_state = list()
	// Таймер обновления
	var/last_timer_call = 0
	// Кастомные задачи
	var/list/custom_storyteller_goals = list()
	// Проверка, что раундстарт уже был вызван ранее
	var/roundstart_started = FALSE
	// Данные с анонсами
	var/last_cc_announce = 0
	var/last_syndi_announce = 0

/datum/controller/subsystem/storyteller/proc/log_storyteller(text, list/data)
	logger.Log(LOG_CATEGORY_STORYTELLER, text, data)

/datum/controller/subsystem/storyteller/proc/load_storyteller_metadata()
	var/filename = "config/bandastation/storyteller_events.toml"

	if (!fexists(filename))
		log_world("Storyteller config not found.")
		active = FALSE
		return

	var/list/result = rustg_raw_read_toml_file(filename)
	if (!result["success"])
		log_world("Failed to load TOML file: [filename] - [result["content"]]")
		active = FALSE
		return

	var/list/decoded = json_decode(result["content"])
	if (!islist(decoded))
		log_world("Failed to parse storyteller config as list.")
		active = FALSE
		return

	storyteller_event_metadata = decoded
	log_world("Storyteller metadata loaded: [length(decoded)] entries.")

/datum/controller/subsystem/storyteller/proc/load_storyteller_profiles()
	var/filename = "config/bandastation/storyteller_profiles.toml"

	if (!fexists(filename))
		log_world("Storyteller config not found.")
		active = FALSE
		return

	var/list/result = rustg_raw_read_toml_file(filename)
	if (!result["success"])
		log_world("Failed to load TOML file: [filename] - [result["content"]]")
		active = FALSE
		return

	var/list/decoded = json_decode(result["content"])
	if (!islist(decoded))
		log_world("Failed to parse storyteller config as list.")
		active = FALSE
		return

	storyteller_profiles = decoded
	log_world("Storyteller profiles loaded: [length(decoded)] entries.")

/datum/controller/subsystem/storyteller/proc/select_storyteller_profile()
	if (!storyteller_profiles || !length(storyteller_profiles))
		return null

	var/list/candidates = list()
	for (var/profile_id in storyteller_profiles)
		var/list/profile = storyteller_profiles[profile_id]
		if (profile["allow_auto"])
			candidates += profile_id

	if (!length(candidates))
		return null

	var/selected = pick(candidates)
	current_storyteller_profile = selected
	log_world("Auto-selected storyteller: [selected]")

/datum/controller/subsystem/storyteller/proc/is_active()
	return active

/datum/controller/subsystem/storyteller/Initialize(timeofday)
	if(!active)
		return SS_INIT_NO_NEED

	load_storyteller_metadata()
	load_storyteller_profiles()
	select_storyteller_profile()
	log_world("Storyteller subsystem initialized")

	return SS_INIT_SUCCESS

/datum/controller/subsystem/storyteller/proc/update_cached_state(is_roundstart = FALSE)
	cached_state = collect_full_storyteller_data(is_roundstart)

/datum/controller/subsystem/storyteller/fire(resumed)
	if(!active || !current_storyteller_profile || !storyteller_profiles[current_storyteller_profile])
		return

	var/time_passed = world.time - last_timer_call

	if(time_passed >= 20)
		update_cached_state()

	var/list/profile = storyteller_profiles[current_storyteller_profile]
	var/freq = max(1, profile["frequency"] || 60) SECONDS

	if (time_passed >= freq)
		last_timer_call = world.time
		goal_monitor_tick()
		make_request(addition_info = profile["description"], is_roundstart = FALSE)
		check_antagonist_missions()

/datum/controller/subsystem/storyteller/proc/get_current_profile()
	if (current_storyteller_profile && storyteller_profiles)
		return storyteller_profiles[current_storyteller_profile]
	return null

/datum/controller/subsystem/storyteller/proc/get_all_profiles()
	return storyteller_profiles

/datum/controller/subsystem/storyteller/proc/set_storyteller_profile(id)
	if (!storyteller_profiles[id])
		log_storyteller("Attempted to set invalid storyteller profile: [id]", list())
		return FALSE

	if (!storyteller_profiles[id]["allow_manual"])
		log_storyteller("Attempted to manually select forbidden profile: [id]", list())
		return FALSE

	current_storyteller_profile = id
	log_storyteller("Storyteller profile manually set to: [id]", list())
	return TRUE

/datum/controller/subsystem/storyteller/proc/build_llm_payload(type = "tick", addition_info = null)
	var/list/profile = get_current_profile()
	if (!profile)
		log_storyteller("Нет активного storyteller профиля. Прерываем build_llm_payload().")
		return null

	var/list/state = cached_state
	var/list/payload = state.Copy() // включаем: state, events, profile, goals и т.д.

	payload["type"] = type

	if (addition_info)
		payload["addition_info"] = addition_info

	return payload

/datum/controller/subsystem/storyteller/proc/make_request(addition_info = "Текущий тик", promt = "", is_roundstart = FALSE)
	var/list/payload = build_llm_payload(is_roundstart)
	if (!payload)
		return

	payload["ticks"] = ticks_passed

	var/json_request = json_encode(payload)
	var/function = "llm"

	if (is_roundstart)
		function = "roundstart"
		send_to_llm(json_request, function)
	else
		INVOKE_ASYNC(src, PROC_REF(send_to_llm), json_request, function)

/datum/controller/subsystem/storyteller/proc/handle_latejoin(mob/living/carbon/human/player)
	var/list/payload = build_llm_payload()
	if (!payload)
		return

	var/list/player_info = list(
		"ckey" = player?.client?.key,
		"job" = player.mind?.assigned_role,
		"department" = map_role_to_department(player.mind?.assigned_role)
	)
	payload["player"] = player_info
	payload["ticks"] = ticks_passed

	var/json = json_encode(payload)
	send_to_llm(json, "latejoin_decision")

/datum/controller/subsystem/storyteller/proc/check_antagonist_missions()
	if (!is_active())
		return

	var/list/payload = build_llm_payload("antag_missions")
	if (!payload)
		return

	// тут уже внутри payload есть "antags" из collect_antag_data()
	var/json = json_encode(payload)
	INVOKE_ASYNC(src, PROC_REF(send_to_llm), json, "antag_missions")

/datum/controller/subsystem/storyteller/proc/send_to_llm(json_request, function)
	// Запрос в LLM
	var/url = "http://127.0.0.1:5000/[function]?json=[url_encode(json_request)]"
	var/list/result = world.Export(url)

	// TODO: узнать, фигли не заходит
	if((!result) || !(result["CONTENT"]))
		log_storyteller("LLMconnection failed")
		return

	// TODO: хуйнуть обработчик ошибок
	var/json_response = file2text(result["CONTENT"])
	var/list/response = json_decode(json_response)
	if(!response)
		return

	var/resp_type = lowertext(response["type"])

	if(resp_type == "roundstart")
		handle_roundstart_response(response)
	else
		pending_decisions[response["event_id"]] = list(
			"info" = response["info"],
			"targets" = response["targets"],
			"type" = type
		)

		// Обрабатываем сразу, без доп. асинхронности
		handle_lmm_result(response)

/datum/controller/subsystem/storyteller/proc/setup_roundstart()
	// Собираем состояние: сколько игроков, их профили, баланс отделов
	if (roundstart_started)
		return

	roundstart_started = TRUE
	update_cached_state(is_roundstart = TRUE)
	last_timer_call = world.time
	make_request(addition_info = "Сгенерируй сюжет используя только переданные из JSON события. Тебе не обязательно использовать их все и передай их вместо примечания.", is_roundstart = TRUE)
	log_storyteller("Сторителлер перехватил начало раунда.")
	return TRUE

/datum/controller/subsystem/storyteller/proc/get_event_metadata(id)
	if(islist(storyteller_event_metadata[id]))
		return storyteller_event_metadata[id]
	return null

/datum/controller/subsystem/storyteller/proc/log_storyteller_decision(name, info = null, targets = null)
	if(pending_decisions[name])
		var/list/pending = pending_decisions[name]
		info = info || pending["info"]
		targets = targets || pending["targets"]
		pending_decisions -= name

	var/list/entry = list(
		"tick" = world.time,
		"name" = name
	)
	if(info)
		entry["info"] = info
	if(targets)
		entry["targets"] = targets

	history_log += list(entry)

/datum/controller/subsystem/storyteller/proc/locate_mob_by_ckey(var/ckey)
	for(var/mob/living/carbon/human/H in GLOB.alive_player_list)
		if(H.client?.key == ckey)
			return H
	return null

/datum/controller/subsystem/storyteller/proc/add_custom_goal(goal)
	if(!islist(goal))
		return
	custom_storyteller_goals += list(goal)

/datum/controller/subsystem/storyteller/proc/goal_monitor_tick()
	for (var/goal in custom_storyteller_goals)
		if (!goal["completed"] == 0) // already requested
			continue

		var/hint = goal["completion_hint"]
		if (!hint)
			continue

		var/search_context = build_context_from_logs(hint)
		if (!search_context)
			continue

		var/json = json_encode(list(
			"goal" = goal,
			"logs" = search_context,
			"story_context" = story_context
		))

		INVOKE_ASYNC(src, PROC_REF(send_to_llm), json,  "goal_check")

// Получение логов категории
/datum/controller/subsystem/storyteller/proc/get_logs_by_category(category_name)
	var/list/result = list()

	var/datum/log_category/category = logger.log_categories[category_name]
	if (!category)
		return result

	for (var/datum/log_entry/E in category.entries)
		result += "[E.timestamp]: [E.message]"

	return result

/datum/controller/subsystem/storyteller/proc/get_all_logs()
	var/list/all = list()

	for (var/category_name in logger.log_categories)
		all += get_logs_by_category(category_name)

	return all

/datum/controller/subsystem/storyteller/proc/filter_logs_by_keywords(list/logs, list/keywords)
	var/list/matched = list()

	for (var/line in logs)
		for (var/kw in keywords)
			if (findtext(line, kw))
				matched += line
				break

	return matched

/// Построение логов для проверки кастомной цели
/proc/build_context_from_logs(hint)
	if (!hint || !length(hint))
		return null

	var/list/keywords = splittext(lowertext(hint), ",") // ключевые слова
	var/list/matched_logs = list()

	// Пробегаем по всем лог-категориям
	for (var/category in logger.log_categories)
		var/datum/log_category/C = logger.log_categories[category]
		if (!C?.entries || !length(C.entries))
			continue

		// Пробегаем по всем записям
		for (var/datum/log_entry/E in C.entries)
			if (!E?.message)
				continue

			var/msg = lowertext(E.message)
			for (var/kw in keywords)
				if (findtext(msg, kw))
					matched_logs += E.message
					break // нашли одно совпадение — достаточно

	return matched_logs
