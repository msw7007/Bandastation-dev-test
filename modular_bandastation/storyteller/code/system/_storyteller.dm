#define USE_LMM_STORYTELLER TRUE
#define LOG_CATEGORY_STORYTELLER "dynamic"
#define LLM_FREQUENCY_CALL 30 MINUTES
GLOBAL_VAR(storyteller_report)

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
	var/datum/storyteller_profile/current_storyteller_profile
	/// Лог событий, который хочет применить СТ
	var/list/pending_decisions = list()
	/// Лог событий, который применил СТ
	var/list/history_log = list()
	// Текущий сценарий, что произошло, сюжетные фазы
	var/story_context = list(
		list(
			"phase" = null,
			"description" = null,
			"passed" = FALSE,
			"duration_min" = null,
			"events_pool" = null
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
	var/list/event_runtime = list()
	var/last_decision_ts = 0
	var/storytell_llm_frequency = LLM_FREQUENCY_CALL

/datum/controller/subsystem/storyteller/Initialize(timeofday)
	if(!active)
		return SS_INIT_NO_NEED

	load_storyteller_metadata()
	load_storyteller_profiles()
	select_storyteller_profile()
	log_world("Storyteller subsystem initialized")

	return SS_INIT_SUCCESS

/datum/controller/subsystem/storyteller/fire(resumed)
	if(!active || !current_storyteller_profile)
		return

	var/time_passed = world.time - last_timer_call

	ticks_passed++
	if(time_passed >= 20)
		update_cached_state()

	if(!istype(current_storyteller_profile))
		log_storyteller("No active storyteller profile datum for [current_storyteller_profile.name]")
		return

	var/freq = (current_storyteller_profile.frequency || 60) SECONDS

	if (time_passed >= freq)
		last_timer_call = world.time
		manual_pulse()
		if (time_passed >= storytell_llm_frequency)
			manual_pulse(FALSE)

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
	if (roundstart_started)
		return
	roundstart_started = TRUE

	update_cached_state(TRUE)
	last_timer_call = world.time

	var/llm_ok = FALSE

	// пробуем LLM
	var/list/payload = build_llm_payload("roundstart")
	if (payload)
		var/json_request = json_encode(payload)
		var/list/resp = send_to_llm(json_request, "roundstart") // синхронно верни list или null
		if (islist(resp) && length(resp))
			handle_roundstart_response(resp)
			llm_ok = TRUE
			st_history_add("roundstart_llm_ok", list())
		else
			st_history_add("roundstart_llm_fail", list())

	// если LLM не сработал — локальный фолбэк: набираем пачку стартовых спавнов по бюджету
	if (!llm_ok)
		var/picked = decide_roundstart_local() // см. ниже
		if (picked)
			st_history_add("roundstart_local", list())
		else
			st_history_add("roundstart_local_none", list())

	log_storyteller("Storyteller roundstart initialized. LLM=[llm_ok]")
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

/datum/controller/subsystem/storyteller/proc/manual_pulse(local = TRUE)
	update_cached_state(FALSE)
	get_chaos_cached()
	compute_target_chaos_and_budget()
	if(local)
		decide_and_trigger(FALSE)
	else
		goal_monitor_tick()
		make_request(is_roundstart = FALSE)
		check_antagonist_missions()

/// Финализация конца раунда: дожимаем антагов/цели и готовим панель отчёта
/datum/controller/subsystem/storyteller/proc/finalize_end_of_round()
	// 1) актуализировать снимок и хаос
	update_cached_state(FALSE)
	get_chaos_cached()

	// 2) мягкая синхронизация задач антагов (через твою же ручку)
	var/list/antag_payload = build_llm_payload("antag_missions")
	if(antag_payload)
		send_to_llm(json_encode(antag_payload), "antag_missions")

	// 3) финальная проверка кастомных целей (если есть completion_hint)
	for(var/list/goal in custom_storyteller_goals)
		if(goal?["completed"] == 0 && goal?["completion_hint"])
			var/list/logs = build_context_from_logs(goal["completion_hint"])
			var/list/req = list("goal"=goal, "logs"=logs, "story_context"=story_context)
			send_to_llm(json_encode(req), "goal_check")

	// 4) записать метрики в blackbox (не обязательно, но полезно)
	if(SSblackbox)
		var/list/chaos = chaos_cache || list()
		SSblackbox.record_feedback("associative", "storyteller_metrics", 1, list(
			"profile" = get_current_profile()?["name"] || "unknown",
			"chaos_raw" = chaos?["raw"] || 0,
			"chaos_smooth" = chaos?["smooth"] || 0,
			"events_known" = length(cached_state?["events"] || list()),
			"custom_goals" = length(custom_storyteller_goals || list())
		))

	// 5) подготовить html-панель для roundend-отчёта
	GLOB.storyteller_report = roundend_panel()
	log_storyteller("Roundend finalize complete.")

/datum/controller/subsystem/storyteller/proc/roundend_panel()
	var/list/parts = list()
	var/list/profile = get_current_profile() || list()
	var/pname = "[profile?["name"] || "Storyteller"]"

	// хаос и краткая сводка
	var/list/C = chaos_cache || list()
	var/s_raw = C?["raw"] || 0
	var/s_sm  = C?["smooth"] || 0

	parts += "<div class='panel stationborder'>"
	parts += "<span class='header'>Storyteller — [pname]</span><br>"
	parts += "Chaos: raw <b>[s_raw]</b>, smooth <b>[s_sm]</b><br>"

	// цели: сколько DM и кастомных
	var/list/goals = cached_state?["goals"] || list()
	var/custom_cnt = 0
	var/dm_cnt = 0
	for(var/g in goals)
		if(islist(g) && g?["source"] == "storyteller") custom_cnt++
		else dm_cnt++

	parts += "<br><b>Goals:</b> DM <b>[dm_cnt]</b>, custom <b>[custom_cnt]</b><br>"

	// фазы сюжета (кратко)
	if(islist(story_context) && length(story_context))
		parts += "<br><b>Story phases:</b><ul class='playerlist'>"
		var/show = min(6, length(story_context))
		for(var/i = 1 to show)
			var/list/ph = story_context[i]
			if(!islist(ph)) continue
			var/status = ph?["passed"] ? "✓" : "…"
			parts += "<li>[status] [html_encode("[ph?["phase"] || "phase"]")]</li>"
		parts += "</ul>"

	parts += "</div>"
	return parts.Join()

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
	var/list/payload = build_llm_payload(is_roundstart ? "roundstart" : "tick")
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
	if(!player || !player.client || !player.mind)
		return

	// Обновим кэш, чтобы метрики/департаменты были актуальны
	update_cached_state(FALSE)

	// 1) фильтруем по префам/банам/возрасту: если игрок не может/не хочет — не гоняем LLM впустую
	if(!player_allows_any_antag(player))
		st_history_add("latejoin_skip", list(
			"reason" = "no_antag_prefs_or_banned",
			"ckey" = player.client.ckey,
		))
		return

	// 2) собираем кандидатов именно из latejoin-ruleset
	var/list/candidates = collect_latejoin_ruleset_candidates(player)
	if(!islist(candidates) || !candidates.len)
		st_history_add("latejoin_skip", list(
			"reason" = "no_latejoin_candidates",
			"ckey" = player.client.ckey,
		))
		return

	// 3) попробуем LLM: если не вышло — DM-fallback
	var/list/payload = build_llm_payload()
	if(payload)
		// Добавим игрока и сузим пул под задачу
		payload["player"] = list(
			"ckey" = player.client.ckey,
			"job" = player.mind.assigned_role?.title,
			"department" = map_role_to_department(player.mind.assigned_role)
		)
		payload["ticks"] = ticks_passed
		payload["candidates"] = candidates // отдаем LLM чистый пул, пусть выберет

		var/json = json_encode(payload)

		// Если send_to_llm синхронный и возвращает успех/провал — используем как гейт
		// Если он асинхронный — делайте INVOKE_ASYNC и таймер-фолбэк; здесь — простая версия.
		var/sent = send_to_llm(json, "latejoin_decision")
		if(sent)
			st_history_add("latejoin_llm_sent", list(
				"ckey" = player.client.ckey,
				"candidates" = length(candidates)
			))
			return

	// LLM не шмог/отключен/вернул ошибку — локальный фолбэк
	st_history_add("latejoin_local_fallback", list(
		"ckey" = player.client.ckey,
		"candidates" = length(candidates)
	))
	decide_latejoin_local(player, candidates)


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
		if(response["event_id"])
			pending_decisions[response["event_id"]] = list(
				"info" = response["info"],
				"targets" = response["targets"],
				"type" = response["type"]
			)

		// Обрабатываем сразу, без доп. асинхронности
		handle_lmm_result(response)

/datum/controller/subsystem/storyteller/proc/st_history_add(kind, list/fields)
	if(!islist(history_log))
		history_log = list()
	var/list/entry = list(
		"ts" = world.time,
		"kind" = "[kind]"
	) + (islist(fields) ? fields : list())
	history_log += list(entry)
	// держим хвост коротким
	if(history_log.len > 100)
		history_log.Cut(1, history_log.len - 100 + 1)

/// Локальный план и запуск roundstart при фейле LLM
/datum/controller/subsystem/storyteller/proc/decide_roundstart_local()
	var/list/profile = get_current_profile() || list()
	var/list/att_list = islist(profile["attention_tags"]) ? profile["attention_tags"] : list()
	var/list/ign_list = islist(profile["ignore_tags"]) ? profile["ignore_tags"] : list()
	var/list/pref_deps = islist(profile["preferred_targets"]) ? profile["preferred_targets"] : list()

	// 1) маппинги тегов: attention = умножитель, ignore = 0
	var/list/att_map = list() // tag -> multiplier
	for(var/t in att_list)
		if(!istext(t)) continue
		var/line = lowertext("[t]")
		var/list/parts = splittext(line, ":")
		var/tag = trim(parts[1])
		if(!length(tag)) continue
		var/mul = 2.0
		if(length(parts) >= 2)
			var/decode = text2num(parts[2])
			if(isnum(decode) && decode > 0) mul = decode
		att_map[tag] = mul

	var/list/ign_set = list() // tag -> TRUE
	for(var/t2 in ign_list)
		if(!istext(t2)) continue
		ign_set[lowertext(trim("[t2]"))] = TRUE

	// 2) бюджет хаоса
	var/list/chaos = compute_target_chaos_and_budget()
	if(!islist(chaos))
		return FALSE
	var/budget = chaos["budget"] || 0
	var/rem_budget = budget // будем уменьшать по мере пиков

	// 3) кандидаты (оба пула: эвенты + рулсеты) для roundstart
	var/list/candidates = collect_available_events(TRUE)
	if(!islist(candidates) || !candidates.len)
		return FALSE

	// 4) таблица рантайма (кулдауны, повторяйки)
	if(!islist(src.event_runtime)) src.event_runtime = list()
	// event_runtime["id"] = list("last_ts"=world.time, "times"=N, "no_repeat"=TRUE/FALSE)

	// 5) скоринг — с учётом мультипликаторов attention/ignore, кулдаунов и no_repeat
	var/list/scored = list()
	for(var/list/E in candidates)
		var/id = "[E["id"]]"
		var/type = "[E["type"]]" // "event"|"ruleset"
		var/name = E["name"] || id
		var/base_weight = max(0.1, E["weight"] || 1)
		var/impact = max(1, E["chaos_impact"] || 1)

		// мета
		var/list/meta = get_event_metadata(id) || list()
		var/cooldown = (meta["cooldown"] || 300) SECONDS
		var/no_repeat = meta["no_repeat"] ? TRUE : FALSE

		// рантайм-фильтры
		var/list/rt = src.event_runtime[id]
		if(islist(rt))
			// CD
			if(world.time - (rt["last_ts"] || 0) < cooldown)
				continue
			// no_repeat
			if(no_repeat && (rt["times"] || 0) >= 1)
				continue

		// теги кандидата
		var/list/tags = list()
		if(islist(E["tags"])) tags = E["tags"]
		else if(istext(E["tags"])) tags = splittext(E["tags"], ",")

		// итоговый множитель веса
		var/ignore_hit = FALSE
		var/mult = 1.0
		for(var/t in tags)
			var/tt = lowertext(trim("[t]"))
			if(ign_set[tt])
				ignore_hit = TRUE; break
			if(att_map[tt])
				mult = max(mult, att_map[tt])

		if(ignore_hit) mult = 0.0
		var/final_weight = base_weight * mult

		// небольшой вкус по департаменту
		var/dep = "[E["target_departs"] || ""]"
		var/dep_bonus = (dep && (dep in pref_deps)) ? 0.5 : 0

		// итоговый score с влиянием бюджета (как в тик-логике)
		var/score = final_weight + dep_bonus
		if(budget < 0)
			score = score / (1 + impact/10.0)
		else
			score = score * (1 + min(0.5, budget/100.0)) + (impact * 0.1)

		// анти-репит
		if(islist(rt))
			var/times = rt["times"] || 0
			score = score / (1 + times * 0.25)

		// кандидата берём, даже если final_weight==0 (вдруг force-pick),
		// но нулевой weight опустит его вниз при сортировке
		scored += list(list(
			"id" = id,
			"type" = type,
			"name" = name,
			"impact" = impact,
			"score" = round(score, 0.1),
			"cooldown" = cooldown,
			"no_repeat" = no_repeat
		))

	if(!scored.len) return FALSE

	// 6) сортировка по score (убывание)
	scored = sortTim(scored, GLOBAL_PROC_REF(st_cmp_desc)) // твой компаратор

	// 7) выбрать до max_picks, стараясь не выходить за бюджет
	var/list/pass_types = list("ruleset", "event")
	for (var/pass in pass_types)
		if (pass == "event")
			rem_budget = rem_budget / 3
		for (var/list/S in scored)
			if (S["type"] != pass) continue

			var/id_pick = S["id"]
			var/type_pick = S["type"]
			var/impact = S["impact"]

			// по желанию можно игнорить бюджет на раундстарте;
			// здесь — мягкий чек: если не влезает, пропускаем именно этот
			if (budget >= 0 && impact > max(0, rem_budget))
				continue

			// учёт кд
			if (!islist(event_runtime[id_pick]))
				event_runtime[id_pick] = list("last_ts"=0, "times"=0)
			event_runtime[id_pick]["last_ts"] = world.time
			event_runtime[id_pick]["times"] = (event_runtime[id_pick]["times"] || 0) + 1

			if (budget >= 0)
				rem_budget = max(0, rem_budget - impact)

			st_history_add("roundstart_local_fire", list(
				"id" = id_pick, "type" = type_pick, "impact" = impact, "rem_budget" = rem_budget
			))

			INVOKE_ASYNC(src, PROC_REF(trigger_decision), id_pick, null, list("source"="local_roundstart","force"=TRUE), type_pick)

	// 8) цель станции: DM-goal или кастом, и лёгкий контекст
	var/goal = SSstation?.generate_station_goals(length(GLOB.player_list))
	if(!goal)
		goal = list(
			"name" = "Стабилизация станции",
			"description" = "Удержать работоспособность ключевых подсистем в первые 30 минут.",
			"completed" = 0, "requires_space" = 0, "required_crew" = 0,
			"completion_hint" = "power online,atmos stable,alerts cleared"
		)
	generate_goals(list(goal))

	// story_context — короткий план для UI
	if(length(current_storyteller_profile.phase_plan))
		story_context = current_storyteller_profile.phase_plan
	else
		story_context = list(
			list(
				"phase" = "Пролог",
				"description" = "Первые инциденты и лёгкие проверки на готовность отделов.",
				"duration_min" = 10,
				"passed" = FALSE,
				"pool" = list( )
			),
			list(
				"phase" = "Эскалация",
				"description" = "Усиление давления на ключевые подсистемы.",
				"duration_min" = 20,
				"passed" = FALSE,
				"pool" = list()
			)
		)

	return TRUE

/datum/controller/subsystem/storyteller/proc/get_current_phase_info()
	// STATION_TIME_PASSED() — децисекунды с начала раунда
	var/elapsed_ds = STATION_TIME_PASSED()
	var/duration_min = round(elapsed_ds / 600)

	if(!length(story_context))
		return list()

	var/acc = 0
	var/idx = 1
	for(var/i = 1 to length(story_context))
		var/list/ph = story_context[i]
		var/dur = max(0, round(text2num(ph["duration_min"]) || 0))
		if(duration_min < acc + dur)
			idx = i; break
		acc += dur
		idx = min(i+1, length(story_context))

	var/list/cur = story_context[idx]
	var/list/pool_ids = list()
	if(islist(cur["pool"]))
		for(var/id in cur["pool"])
			if(istext(id) && length(id)) pool_ids += "[id]"

	return list(
		"index" = idx,
		"title" = cur["title"],
		"description" = cur["description"],
		"pool" = pool_ids,
		"duration_min" = duration_min
	)
