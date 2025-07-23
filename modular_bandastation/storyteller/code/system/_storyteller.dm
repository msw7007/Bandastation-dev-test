// storyteller.dm
#define USE_LMM_STORYTELLER TRUE
#define LOG_CATEGORY_STORYTELLER "dynamic"

SUBSYSTEM_DEF(storyteller)
	name = "Storyteller"
	wait = 1 MINUTES
	priority = FIRE_PRIORITY_DEFAULT
	runlevels = RUNLEVEL_GAME
	/// Храним последний ответ от ЛММ (для логов/админов)
	var/last_decision = null
	/// Внутренний счётчик тиков (чтобы ЛММ знала время)
	var/ticks_passed = 0
	/// Состояние активного (будет получаться через конфиг)
	var/active = TRUE

/datum/controller/subsystem/storyteller/proc/is_active()
	return active

/datum/controller/subsystem/storyteller/Initialize(timeofday)
	if(!active)
		return SS_INIT_NO_NEED

	log_world("Storyteller subsystem initialized")
	return SS_INIT_SUCCESS

/datum/controller/subsystem/storyteller/fire(resumed)
	if(!active)
		return

	ticks_passed++
	main_logic()

/datum/controller/subsystem/storyteller/proc/main_logic(addition_info = "Текущий тик", promt = "", is_roundstart = FALSE)
	var/list/state = collect_station_state()
	var/list/events = collect_available_events(is_roundstart)
	var/function = "llm"
	var/json_request = json_encode(list(
		"state" = state,
		"events" = events,
		"ticks" = ticks_passed,
		"addition_info" = addition_info,
		"storyteller_profile" = "Balanced"
	))
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

/proc/log_storyteller(text, list/data)
	logger.Log(LOG_CATEGORY_STORYTELLER, text, data)
