/datum/controller/subsystem/events
	var/list/event_weights = list()

/datum/controller/subsystem/events/fire(resumed = FALSE)
	// Если управление отдано LLM, то не вызываем checkEvent(),
	// а просто обрабатываем уже активные события
	if(SSstoryteller.is_active())
		src.currentrun = running.Copy()

		var/list/currentrun = src.currentrun
		while(currentrun.len)
			var/datum/thing = currentrun[currentrun.len]
			currentrun.len--
			if(thing)
				thing.process(wait * 0.1)
			else
				running.Remove(thing)
			if (MC_TICK_CHECK)
				return
		return

	// Обычная логика, если LLMвыключен
	if(!resumed)
		checkEvent()
		src.currentrun = running.Copy()

	var/list/currentrun = src.currentrun

	while(currentrun.len)
		var/datum/thing = currentrun[currentrun.len]
		currentrun.len--
		if(thing)
			thing.process(wait * 0.1)
		else
			running.Remove(thing)
		if (MC_TICK_CHECK)
			return

/datum/controller/subsystem/events/proc/get_available_events(is_roundstart = FALSE)
	var/list/available = list()
	var/players_amt = get_active_player_count(alive_check = TRUE, afk_check = TRUE, human_check = TRUE)

	// Обновляем и растим вес каждого события
	for (var/datum/round_event_control/E in control)
		if (is_roundstart)
			E.earliest_start = 0 MINUTES
		else
			E.earliest_start = initial(E.earliest_start)

		if (!E.can_spawn_event(players_amt))
			continue

		// Инициализация веса, если ещё не задан
		if (!event_weights[E.type])
			event_weights[E.type] = max(E.weight, 1)

		// Постепенный рост (до x2 от базового веса)
		var/max_weight = max(E.weight, 1) * 1.25
		event_weights[E.type] = min(event_weights[E.type] * 1.05, max_weight)

		// Добавляем в список для ЛЛМ
		available += list(list(
			"id" = "[E.type]", // уникальный идентификатор
			"name" = E.name,
			"weight" = round(event_weights[E.type], 0.1),
			"target_roles" = "engineers",
			"target_departs" = "engineering",
			"tags" = "space",
			"type" = "event"
		) + (SSstoryteller.get_event_metadata("[E.type]") || list()))

	return available

/datum/controller/subsystem/events/TriggerEvent(datum/round_event_control/event_to_trigger)
	. = ..()

	if(. == EVENT_READY && SSstoryteller.is_active())
		if(event_to_trigger.type in event_weights)
			event_weights[event_to_trigger.type] = max(event_weights[event_to_trigger.type] / 5, 1)

		SSstoryteller.log_storyteller_decision(event_to_trigger.name)
