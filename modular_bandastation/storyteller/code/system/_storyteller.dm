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
	var/last_chaos_calc = 0
	var/list/chaos_history = list()
	var/list/chaos_cache = list(
		"raw" = 0,
		"smooth" = 0,
		"parts" = list(),
		"ts" = 0
	)

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

/datum/controller/subsystem/storyteller/proc/is_active()
	return active

/datum/controller/subsystem/storyteller/proc/update_cached_state(is_roundstart = FALSE)
	cached_state = collect_full_storyteller_data(is_roundstart)

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

/datum/controller/subsystem/storyteller/proc/get_event_metadata(id)
	if(islist(storyteller_event_metadata[id]))
		return storyteller_event_metadata[id]
	return null

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
