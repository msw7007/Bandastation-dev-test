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

