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

/datum/controller/subsystem/storyteller/fire(resumed)
	if(!active || !current_storyteller_profile || !storyteller_profiles[current_storyteller_profile])
		return

	ticks_passed++

	var/list/profile = storyteller_profiles[current_storyteller_profile]
	var/freq = max(1, profile["frequency"] || 60)

	if (ticks_passed % freq == 0)
		main_logic(profile["description"] || "Текущий тик")

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

/datum/controller/subsystem/storyteller/proc/main_logic(addition_info = "Текущий тик", promt = "", is_roundstart = FALSE)
	var/list/state = collect_station_state()
	var/list/events = collect_available_events(is_roundstart)

	var/list/profile_data = get_current_profile()
	var/function = "llm"

	if (!profile_data)
		log_storyteller("Нет активного storyteller профиля. Используется заглушка.")
		profile_data = list("name" = "Unknown", "description" = "No profile active.")

	var/list/request_payload = list(
		"state" = state,
		"events" = events,
		"ticks" = ticks_passed,
		"addition_info" = addition_info,
		"storyteller_profile" = profile_data
	)

	var/json_request = json_encode(request_payload)

	if(is_roundstart)
		send_to_llm(json_request, function)
	else
		INVOKE_ASYNC(src, PROC_REF(send_to_llm), json_request, function)

/datum/controller/subsystem/storyteller/proc/send_to_llm(json_request, function)
	// Запрос в LLM
	var/url = "http://127.0.0.1:5000/[function]?json=[url_encode(json_request)]"
	var/list/result = world.Export(url)

	// TODO: узнать, фигли не заходит
	if(!result || !"CONTENT" in result)
		log_storyteller("LLMconnection failed")
		return

	// TODO: хуйнуть обработчик ошибок
	var/json_response = file2text(result["CONTENT"])
	var/list/decision = json_decode(json_response)
	if(!decision)
		return

	// Обрабатываем сразу, без доп. асинхронности
	handle_lmm_decision(decision)

/datum/controller/subsystem/storyteller/proc/setup_roundstart()
	// Собираем состояние: сколько игроков, их профили, баланс отделов
	main_logic(addition_info = "Сгенерируй сюжет используя только переданные из JSON события. Тебе не обязательно использовать их все и передай их вместо примечания.", is_roundstart = TRUE)

	log_storyteller("Сторителлер перехватил начало раунда.")
	return TRUE

/datum/controller/subsystem/storyteller/proc/get_event_metadata(id)
	if(islist(storyteller_event_metadata[id]))
		return storyteller_event_metadata[id]
	return null
