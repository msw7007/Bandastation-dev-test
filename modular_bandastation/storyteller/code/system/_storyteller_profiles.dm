/datum/storyteller_profile
	// Идентификатор (ключ из TOML)
	var/id = "default"
	// Видимые поля
	var/name = "Storyteller"
	var/description = ""
	var/frequency = 60                // сек между тик-запросами СТ
	var/allow_auto = TRUE

	// Поведенческие предпочтения
	var/list/attention_tags = list()  // любит
	var/list/ignore_tags = list()     // игнорит
	var/list/preferred_targets = list() // департаменты приоритета (строки)

	// Хаос-управление
	var/list/chaos_curve = list(10, 15, 25, 35, 25, 15) // 6 бинов по 10 мин, 0..100
	var/list/chaos_scatter_pct = list(0.15,0.15,0.15,0.15,0.15,0.15) // допуск ±%
	var/list/chaos_cycle_multipliers = list(1.0) // помножители по часам; последняя повторяется

	var/deadband = 5                 // ± зона тишины вокруг цели (п.п. хаоса)
	var/min_gap_sec = 180            // пауза между решениями (сек)
	var/drop_shape = 1.0             // крутизна функции дропа (1.0 = линейно)
	var/allow_force_pick = FALSE     // брать ли топ-1 «форсункой», если не влазит в бюджет
	var/assist_window = 5            // сколько п.п. можно «перекрыть» при нехватке бюджета
	var/assist_prob = 50             // шанс (%) помочь, если не хватает в пределах assist_window

	var/list/phase_plan = list()
	var/phase_pool_boost = 2

/datum/controller/subsystem/storyteller/proc/get_profile_as_list(datum/storyteller_profile/storyteller)
	// attention_tags: "combat" -> 2.0 (по умолчанию), "invasion:1.5" -> 1.5
	var/list/att_raw = storyteller.attention_tags?.Copy() || list()
	var/list/att_map = list()
	for(var/entry in att_raw)
		if(!istext(entry)) continue
		var/s = lowertext(trim("[entry]"))
		if(!length(s)) continue
		var/tag = s
		var/mul = 2.0
		var/colon = findtext(s, ":")
		if(colon)
			tag = lowertext(trim(copytext(s, 1, colon)))
			var/numtxt = trim(copytext(s, colon+1))
			var/n = text2num(numtxt)
			if(isnum(n) && n > 0) mul = n
		if(length(tag)) att_map[tag] = mul

	// ignore_tags: любой указанный тег -> игнор (вес = 0)
	var/list/ign_raw = storyteller.ignore_tags?.Copy() || list()
	var/list/ign_set = list()
	for(var/entry2 in ign_raw)
		if(!istext(entry2)) continue
		var/tag2 = lowertext(trim("[entry2]"))
		if(length(tag2)) ign_set[tag2] = TRUE

	return list(
		"id" = storyteller.id,
		"name" = storyteller.name,
		"description" = storyteller.description,
		"frequency" = storyteller.frequency,
		"allow_auto" = storyteller.allow_auto,

		// исходные списки
		"attention_tags" = att_raw,
		"ignore_tags" = ign_raw,
		"preferred_targets" = storyteller.preferred_targets?.Copy() || list(),
		"chaos_curve" = storyteller.chaos_curve?.Copy() || list(),
		"chaos_scatter_pct" = storyteller.chaos_scatter_pct?.Copy() || list(),
		"chaos_cycle_multipliers" = storyteller.chaos_cycle_multipliers?.Copy() || list(),
		"deadband" = storyteller.deadband,
		"min_gap_sec" = storyteller.min_gap_sec,
		"drop_shape" = storyteller.drop_shape,
		"allow_force_pick" = storyteller.allow_force_pick,
		"assist_window" = storyteller.assist_window,
		"assist_prob" = storyteller.assist_prob,

		// разобранные карты для решателя/UI
		"att_map" = att_map,
		"ign_set" = ign_set,

		"phase_plan" = islist(storyteller.phase_plan) ? storyteller.phase_plan.Copy() : list(),
		"phase_pool_boost" = storyteller.phase_pool_boost
	)

/datum/controller/subsystem/storyteller/proc/load_storyteller_profiles()
	var/filename = "config/bandastation/storyteller_profiles.toml"
	var/list/loaded = list()

	if (!fexists(filename))
		log_storyteller("Storyteller config not found: [filename]. Using built-in default.")
		loaded["default"] = new /datum/storyteller_profile
		storyteller_profiles = loaded
		return

	var/list/result = rustg_raw_read_toml_file(filename)
	if (!result["success"])
		log_storyteller("Failed to load TOML: [filename] - [result["content"]]. Using built-in default.")
		loaded["default"] = new /datum/storyteller_profile
		storyteller_profiles = loaded
		return

	var/list/decoded = json_decode(result["content"])
	if (!islist(decoded))
		log_storyteller("Failed to parse storyteller config as list. Using built-in default.")
		loaded["default"] = new /datum/storyteller_profile
		storyteller_profiles = loaded
		return

	var/valid = 0
	for (var/profile_id in decoded)
		var/list/cfg = decoded[profile_id]
		if(!islist(cfg))
			log_storyteller("Profile [profile_id]: expected table, got [istype(cfg)]. Skipped.")
			continue

		// поддержка твоего синтаксиса "chaos_curve = 20, 20, 40, ..." (как строка)
		// rustg TOML обычно даёт массивы, но если это строка — наши to_list_* всё разрулят.

		var/datum/storyteller_profile/P = build_profile_from_cfg("[profile_id]", cfg)
		if(P)
			loaded["[profile_id]"] = P
			valid++

	if(!valid)
		log_storyteller("No valid profiles loaded. Using built-in default.")
		loaded["default"] = new /datum/storyteller_profile

	storyteller_profiles = loaded
	log_world("Storyteller: profiles loaded: [valid], total in map: [length(storyteller_profiles)].")

/datum/controller/subsystem/storyteller/proc/select_storyteller_profile()
	if (!storyteller_profiles || !length(storyteller_profiles))
		return null

	var/list/candidates = list()
	for (var/id in storyteller_profiles)
		var/datum/storyteller_profile/P = storyteller_profiles[id]
		if (P && P.allow_auto)
			candidates += id

	if (!length(candidates))
		return null

	var/selected_id = pick(candidates)
	var/datum/storyteller_profile/selected = storyteller_profiles[selected_id]
	set_storyteller_profile(selected_id)
	log_world("Auto-selected storyteller: [selected.name]")

/datum/controller/subsystem/storyteller/proc/get_current_profile()
	// ВОЗВРАЩАЕМ АССОЦ-СПИСОК, как и раньше ожидал твой payload
	if (current_storyteller_profile && storyteller_profiles)
		var/datum/storyteller_profile/P = storyteller_profiles[current_storyteller_profile]
		if(P)
			return get_profile_as_list(P)
	return null

/datum/controller/subsystem/storyteller/proc/get_current_profile_datum()
	if (current_storyteller_profile && storyteller_profiles)
		return storyteller_profiles[current_storyteller_profile.id]
	return null

/datum/controller/subsystem/storyteller/proc/get_all_profiles()
	// Для админок/отладки можно вернуть имена
	var/list/out = list()
	for (var/id in storyteller_profiles)
		var/datum/storyteller_profile/P = storyteller_profiles[id]
		if(P)
			out[id] = get_profile_as_list(P)
	return out

/datum/controller/subsystem/storyteller/proc/set_storyteller_profile(id)
	var/datum/storyteller_profile/P = storyteller_profiles[id]
	if (!P)
		log_storyteller("Attempted to set invalid storyteller profile: [id]", list())
		return FALSE

	current_storyteller_profile = P
	log_storyteller("Storyteller profile manually set to: [current_storyteller_profile.name]", list())
	return TRUE

/datum/controller/subsystem/storyteller/proc/build_profile_from_cfg(id, list/cfg)
	var/datum/storyteller_profile/P = new
	P.id = "[id]"

	// Имя/описание
	P.name = "[cfg["name"] || id]"
	P.description = "[cfg["description"] || ""]"

	// Частота (сек)
	var/f = cfg["frequency"]
	if(!isnum(f)) f = text2num("[f]")
	if(!isnum(f)) f = 60
	P.frequency = clamp(f, 10, 300)

	// Флаги
	P.allow_auto   = !!(cfg["allow_auto"]   ? TRUE : FALSE)

	// Теги и цели
	P.attention_tags = islist(cfg["attention_tags"]) ? cfg["attention_tags"] : list()
	P.ignore_tags = islist(cfg["ignore_tags"]) ? cfg["ignore_tags"] : list()
	P.preferred_targets = islist(cfg["preferred_targets"]) ? cfg["preferred_targets"] : list()

	// Хаос-кривая (0..100, любое количество шагов, дефолт если пусто)
	if(islist(cfg["chaos_curve"]))
		P.chaos_curve = cfg["chaos_curve"]
	else if(istext(cfg["chaos_curve"]))
		P.chaos_curve = splittext(cfg["chaos_curve"], ",")
	else
		P.chaos_curve = list(10, 15, 25, 35, 25, 15)

	// Разброс хаоса (±%, любое количество, дефолт 0)
	if(islist(cfg["chaos_scatter_pct"]))
		P.chaos_scatter_pct = cfg["chaos_scatter_pct"]
	else if(istext(cfg["chaos_scatter_pct"]))
		P.chaos_scatter_pct = splittext(cfg["chaos_scatter_pct"], ",")
	else
		P.chaos_scatter_pct = list(0,0,0,0,0,0)

	// Множители цикла (любое количество, дефолт 1.0)
	if(islist(cfg["chaos_cycle_multipliers"]))
		P.chaos_cycle_multipliers = cfg["chaos_cycle_multipliers"]
	else if(istext(cfg["chaos_cycle_multipliers"]))
		P.chaos_cycle_multipliers = splittext(cfg["chaos_cycle_multipliers"], ",")
	else
		P.chaos_cycle_multipliers = list(1.0)

	if (islist(cfg["phase_plan"]))
		var/list/pp_in = cfg["phase_plan"]
		var/list/pp_out = list()

		for (var/entry in pp_in)
			if (!islist(entry)) continue
			var/list/e = entry

			var/title = istext(e["title"]) ? "[e["title"]]" : null
			var/dur = text2num("[e["duration_min"]]")
			if (!isnum(dur) || dur <= 0) dur = 10

			var/desc = istext(e["description"]) ? "[e["description"]]" : null

			var/list/pool_norm = list()
			if (islist(e["pool"]))
				var/list/pool_in = e["pool"]
				for (var/p in pool_in)
					if (istext(p))
						// Храним строковые typepath — этого достаточно.
						// (если захочешь валидировать: if(text2path(p)) ...)
						pool_norm += "[p]"

			pp_out += list(list(
				"title" = title,
				"duration_min" = dur,
				"description" = desc,
				"pool" = pool_norm
			))

		P.phase_plan = pp_out
	else
		P.phase_plan = list()

	return P
