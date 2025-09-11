/datum/controller/subsystem/storyteller/proc/locate_mob_by_ckey(var/ckey)
	for(var/mob/living/carbon/human/H in GLOB.alive_player_list)
		if(H.client?.key == ckey)
			return H
	return null

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

/proc/st_cmp_desc(a, b)
	if(!islist(a) || !islist(b))
		return 0
	var/sa = a["score"] || 0
	var/sb = b["score"] || 0
	return sb - sa  // по убыванию score

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

/datum/controller/subsystem/storyteller/proc/log_storyteller(text, list/data)
	logger.Log(LOG_CATEGORY_STORYTELLER, text, data)

/// Возвращает TRUE, если игрок разрешил хотя бы один из переданных кандидатов (по префам),
/// и при этом не забанен/не слишком молодой для этого антага (опционально).
/proc/st_player_allows_any_latejoin(mob/living/carbon/human/H, list/candidates)
	if(!H?.client || !islist(candidates) || !candidates.len)
		return FALSE

	var/datum/preferences/prefs = H.client?.prefs
	var/list/allowed_flags = istype(prefs) ? (prefs.be_special || list()) : list()

	// если вообще ничего не выбрано в префах — считаем, что антаги выключены
	if(!length(allowed_flags))
		return FALSE

	// если глобально забанен от синдиката — можно сразу отказаться
	if(is_banned_from(H.client.ckey, ROLE_SYNDICATE))
		return FALSE

	for(var/list/C in candidates)
		// ожидаем id == "[/datum/dynamic_ruleset/...]"
		var/tp = text2path("[C["id"]]")
		if(!ispath(tp, /datum/dynamic_ruleset))
			continue

		// pref_flag ruleset’а из initial()
		var/pref_flag = initial(tp:pref_flag)
		if(!pref_flag)
			// у некоторых правил может не быть pref_flag — трактуем как «разрешено»
			return TRUE

		// проверка префов
		if(pref_flag in allowed_flags)
			// (опционально) индивидуальный бан конкретного флага
			if(is_banned_from(H.client.ckey, pref_flag))
				continue

			return TRUE

	return FALSE

/datum/controller/subsystem/storyteller/proc/can_player_roll_ruleset(mob/living/carbon/human/player, datum/dynamic_ruleset/R)
	if(!player?.client || !R)
		return FALSE

	var/client/C = player.client

	var/antag_flag = initial(R.pref_flag)
	var/jobban_flag = initial(R.jobban_flag)

	// Глобальный бан
	if(is_banned_from(C.ckey, ROLE_SYNDICATE))
		return FALSE
	// Бан по роли/флагу
	if(antag_flag && is_banned_from(C.ckey, antag_flag))
		return FALSE
	if(jobban_flag && is_banned_from(C.ckey, jobban_flag))
		return FALSE

	// Возрастной порог
	if(antag_flag)
		if(C.get_days_to_play_antag(antag_flag) > 0)
			return FALSE

	// Префы: у игрока должен быть включен соответствующий флаг
	if(antag_flag)
		var/list/prefs = C.prefs?.be_special
		if(!islist(prefs) || !(antag_flag in prefs))
			return FALSE

	return TRUE

/datum/controller/subsystem/storyteller/proc/collect_latejoin_ruleset_candidates(mob/living/carbon/human/player)
	. = list()

	var/population = length(GLOB.alive_player_list)
	var/list/types_to_scan = subtypesof(/datum/dynamic_ruleset/latejoin)

	for(var/ruleset_type in types_to_scan)
		var/datum/dynamic_ruleset/R = new ruleset_type(SSdynamic?.dynamic_config)
		if(!R || !R.name)
			if(R) qdel(R)
			continue

		if(R.ruleset_flags == NONE)
			qdel(R)
			continue

		// Базовая пригодность, вес
		var/ruleset_weight = R.get_weight(population)
		if(ruleset_weight <= 0 || !R.can_be_selected())
			qdel(R)
			continue

		// Префы/баны/возраст — игрок должен иметь право стать именно этим антагом
		if(!can_player_roll_ruleset(player, R))
			qdel(R)
			continue

		// Метаданные (cooldown, no_repeat и проч)
		var/list/meta = get_event_metadata("[R.type]") || list()
		var/cooldown = meta["cooldown"]
		if(isnull(cooldown))
			cooldown = 300 // сек по умолчанию
		// в ТИКИ переведём в момент скоринга/фильтра (там тоже есть защита)

		// Соберём «кандидата»
		var/list/cand = list(
			"id" = "[R.type]",
			"name" = R.name,
			"weight" = round(ruleset_weight, 0.1),
			"target_roles" = "any",
			"tags" = "none",
			"type" = "ruleset",
			"phase" = "latejoin",
			"chaos_impact" = 1,
		) + meta

		. += list(cand)
		qdel(R)

/datum/controller/subsystem/storyteller/proc/player_allows_any_antag(mob/living/carbon/human/player)
	if(!player?.client)
		return FALSE

	var/client/C = player.client
	// бан на все синдикатские роли?
	if(is_banned_from(C.ckey, ROLE_SYNDICATE))
		return FALSE

	// Префы: preferences.be_special — список флагов
	var/list/prefs = C.prefs?.be_special
	if(!islist(prefs) || !prefs.len)
		return FALSE

	// Также проверим возрастной порог для включенных префов
	for(var/antag_flag in prefs)
		var/need_days = C.get_days_to_play_antag(antag_flag) // 0 если порога нет/пройден
		if(need_days <= 0 && !is_banned_from(C.ckey, antag_flag))
			return TRUE

	return FALSE

