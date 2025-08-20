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
