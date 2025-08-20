/datum/storyteller_profile
	// Идентификатор (ключ из TOML)
	var/id = "default"
	// Видимые поля
	var/name = "Storyteller"
	var/description = ""
	var/frequency = 60                // сек между тик-запросами СТ
	var/allow_manual = TRUE
	var/allow_auto = TRUE

	// Поведенческие предпочтения
	var/list/attention_tags = list()  // любит
	var/list/ignore_tags = list()     // игнорит
	var/list/preferred_targets = list() // департаменты приоритета (строки)

	// Хаос-управление
	var/list/chaos_curve = list(10, 15, 25, 35, 25, 15) // 6 бинов по 10 мин, 0..100
	var/list/chaos_scatter_pct = list(0.15,0.15,0.15,0.15,0.15,0.15) // допуск ±%
	var/list/chaos_cycle_multipliers = list(1.0) // помножители по часам; последняя повторяется

/datum/controller/subsystem/storyteller/proc/get_profile_as_list(datum/storyteller_profile/storyteller)
		return list(
			"id" = storyteller.id,
			"name" = storyteller.name,
			"description" = storyteller.description,
			"frequency" = storyteller.frequency,
			"allow_manual" = storyteller.allow_manual,
			"allow_auto" = storyteller.allow_auto,
			"attention_tags" = storyteller.attention_tags.Copy(),
			"ignore_tags" = storyteller.ignore_tags.Copy(),
			"preferred_targets" = storyteller.preferred_targets.Copy(),
			"chaos_curve" = storyteller.chaos_curve.Copy(),
			"chaos_scatter_pct" = storyteller.chaos_scatter_pct.Copy(),
			"chaos_cycle_multipliers" = storyteller.chaos_cycle_multipliers.Copy()
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

	var/selected = pick(candidates)
	current_storyteller_profile = selected
	log_world("Auto-selected storyteller: [selected]")

/datum/controller/subsystem/storyteller/proc/get_current_profile()
	// ВОЗВРАЩАЕМ АССОЦ-СПИСОК, как и раньше ожидал твой payload
	if (current_storyteller_profile && storyteller_profiles)
		var/datum/storyteller_profile/P = storyteller_profiles[current_storyteller_profile]
		if(P)
			return get_profile_as_list(P)
	return null

/datum/controller/subsystem/storyteller/proc/get_current_profile_datum()
	if (current_storyteller_profile && storyteller_profiles)
		return storyteller_profiles[current_storyteller_profile]
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
	if (!P.allow_manual)
		log_storyteller("Attempted to manually select forbidden profile: [id]", list())
		return FALSE

	current_storyteller_profile = id
	log_storyteller("Storyteller profile manually set to: [id]", list())
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
	P.allow_manual = !!(cfg["allow_manual"] ? TRUE : FALSE)
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

	// Быстрая финальная проверка
	if(!P.allow_manual && !P.allow_auto)
		log_storyteller("Profile [id]: both allow_manual and allow_auto are FALSE; enabling allow_manual.")
		P.allow_manual = TRUE

	return P
