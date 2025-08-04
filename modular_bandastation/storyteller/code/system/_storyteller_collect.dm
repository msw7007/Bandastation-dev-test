/datum/controller/subsystem/storyteller/proc/collect_full_storyteller_data(is_roundstart = FALSE)
	var/list/storyteller_data = list()

	// Состояние станции
	var/list/state = collect_station_state()
	storyteller_data["state"] = state

	// Доступные события и рулсеты
	var/list/events = collect_available_events(is_roundstart)
	storyteller_data["events"] = events

	// Активный профиль storyteller
	var/list/profile = get_current_profile()
	storyteller_data["storyteller_profile"] = profile || list()

	// История принятых решений (пока заглушка)
	storyteller_data["history"] = get_storyteller_history()

	// Цели станции текущие
	storyteller_data["goals"] = get_station_goals()

	// Цели станции доступные из DM
	storyteller_data["dm_goals"] = get_available_goals()

	// Информация об антагонистах
	storyteller_data["antags"] = collect_antag_data()

	// Игроки
	storyteller_data["players"] = collect_players_data()

	// Контекст текущей метаистории
	storyteller_data["story_context"] = get_story_context()

	// Динамика раунда для дополнительного анализа
	storyteller_data["dynamic_history"] = get_dynamic_context()

	return storyteller_data

/datum/controller/subsystem/storyteller/proc/collect_station_state()
	var/list/state = list()

	// Онлайн
	state["players_total"] = length(GLOB.player_list)
	state["players_alive"] = get_active_player_count(afk_check = TRUE)

	// Распределение по отделам
	state["departments"] = get_department_data(5 MINUTES)

	// Хаос
	// Смертность
	state["deaths_recent"] = count_recent_deaths(5 MINUTES)

	// Тревоги (пример)
	state["alert_level"] = SSsecurity_level?.current_security_level || "green"
	state["air_alarms"] = count_active_alarms() || 0

	// Бой
	state["violence_score"] = count_violence_score() || 0

	// Экономика
	state["station_credits"] = count_departments_funds() || 0

	return state


/datum/controller/subsystem/storyteller/proc/collect_available_events(is_roundstart = FALSE)
	var/list/events = list()

	// Собираем из dynamic
	if(SSdynamic)
		events += SSdynamic.get_available_events(is_roundstart)

	// Собираем из events
	if(SSevents)
		events += SSevents.get_available_events(is_roundstart)

	return events

/datum/controller/subsystem/storyteller/proc/count_recent_deaths(var/check_time = 5 MINUTES)
	var/death_cutoff = world.time - check_time
	var/count = 0

	for(var/mob/M in GLOB.dead_player_list)
		if(M.mind?.last_death && M.mind.last_death >= death_cutoff)
			count++

	return count

/datum/controller/subsystem/storyteller/proc/count_active_alarms()
	var/total_alarms = 0

	// Ищем все контроллеры тревог (устанавливаются программами или глобально)
	for(var/datum/station_alert/alert_control in world)
		if(alert_control.listener?.alarms)
			total_alarms += length(alert_control.listener.alarms)

	return total_alarms

/datum/controller/subsystem/storyteller/proc/count_violence_score()
	var/violence_score = 0

	for(var/mob/living/carbon/human/H in GLOB.human_list)
		// Проверяем, получал ли урон недавно
		violence_score += max(0, H.maxHealth - H.health)

	return violence_score

/datum/controller/subsystem/storyteller/proc/count_departments_funds()
	var/total = 0
	var/list/departments = list()

	// Собираем департаменты из экономики
	for(var/datum/bank_account/department/D in SSeconomy.departmental_accounts)
		total += D.account_balance
		departments[D.department_id] = D.account_balance

	// Можно вернуть как просто сумму или детализировано
	return list(
		"total" = total,
		"by_department" = departments
	)

/datum/controller/subsystem/storyteller/proc/get_department_data()
	var/list/dept_summary = list()

	for(var/mob/living/carbon/human/H in GLOB.player_list)
		if(!H.client || !H.mind || !H.mind.assigned_role)
			continue

		// Определяем отдел (надо будет иметь маппинг ролей → отделов)
		var/role = H.mind.assigned_role
		var/department = map_role_to_department(role)
		if(!department)
			department = "Other"

		// Часы наигранные (берём из client.prefs)
		var/hours = 0
		hours = H.client?.calc_exp_type(H.mind.assigned_role)
		// Приводим к 0..1 (0 – новичок, 1 – ветеран)
		var/progress = clamp(hours / 300, 0, 1)

		if(!dept_summary[department])
			dept_summary[department] = list("players" = 0, "avg_exp" = 0)

		dept_summary[department]["players"] += 1
		dept_summary[department]["avg_exp"] += progress

	// Делаем среднее по опыту
	for(var/dept in dept_summary)
		var/count = dept_summary[dept]["players"]
		if(count > 0)
			dept_summary[dept]["avg_exp"] = dept_summary[dept]["avg_exp"] / count

	return dept_summary

/datum/controller/subsystem/storyteller/proc/map_role_to_department(role)
	// Простая заглушка (нужен маппинг)
	if(findtext(role, "Engineer"))
		return "Engineering"
	if(findtext(role, "Medical"))
		return "Medical"
	if(findtext(role, "Security"))
		return "Security"
	if(findtext(role, "Cargo"))
		return "Supply"
	if(findtext(role, "Science"))
		return "Science"
	if(findtext(role, "Command"))
		return "Command"
	return "Civilian"

/datum/controller/subsystem/storyteller/proc/collect_players_data()
	var/list/players = list()

	for(var/mob/living/carbon/human/H in GLOB.human_list)
		if(!H.client || !H.mind)
			continue

		var/list/player = list()
		player["ckey"] = H.client.key
		player["job"] = H.mind.assigned_role || "Unassigned"
		player["department"] = map_role_to_department(player["job"])
		player["is_antag"] = (H.mind.antag_datums != null)
		player["status"] = get_mob_status(H)
		player["available_rulesets"] = get_available_rulesets_for(H)

		players += list(player)

	return players

// Помощники
/datum/controller/subsystem/storyteller/proc/get_mob_status(mob/living/M)
	if(M.stat == DEAD)
		return "dead"
	if(M.stat == UNCONSCIOUS)
		return "crit"
	return "alive"

/datum/controller/subsystem/storyteller/proc/get_available_rulesets_for(mob/living/M)
	// Пока заглушка
	return list()

/datum/controller/subsystem/storyteller/proc/collect_antag_data()
	var/list/antags = list()
	var/list/entries = list()

	for(var/datum/antagonist/A in GLOB.antagonists)
		if(!A.owner)
			continue

		var/list/info = list()
		info["ckey"] = A.owner.key
		info["role"] = A.name
		info["objectives"] = list()

		for(var/datum/objective/O in A.objectives)
			info["objectives"] += O.explanation_text

		entries += list(info)

	antags += list("count" = length(entries), "list" = entries)
	return antags

/datum/controller/subsystem/storyteller/proc/get_storyteller_history()
	return history_log

/datum/controller/subsystem/storyteller/proc/get_station_goals()
	var/list/goals = list()

	// Цели, заданные DM
	for(var/datum/station_goal/G in SSstation.get_station_goals())
		goals += list(list(
			"name" = G.name,
			"type" = "[G.type]",
			"completed" = G.completed,
			"requires_space" = G.requires_space,
			"required_crew" = G.required_crew,
			"completion_hint" = ""
		))

	// Цели, сгенерированные Storyteller'ом
	for(var/goal in custom_storyteller_goals)
		if(islist(goal))
			goals += list(goal + list("source" = "storyteller"))

	return goals

/datum/controller/subsystem/storyteller/proc/get_available_goals(goal_budget = 5)
	var/list/available = list()
	var/list/possible = subtypesof(/datum/station_goal)
	var/goal_weights = 0
	var/is_planetary = SSmapping.is_planetary()

	var/list/current_goal_types = list()
	for(var/goal in get_station_goals())
		current_goal_types += goal["type"]

	while(possible.len && goal_weights < goal_budget)
		var/datum/station_goal/type = pick_n_take(possible)
		if(type in current_goal_types)
			continue

		if(type.requires_space && is_planetary)
			continue

		goal_weights += initial(type.weight)
		available += list(list(
			"name" = type.name,
			"type" = "[type]",
			"completed" = FALSE,
			"requires_space" = type.requires_space,
			"required_crew" = type.required_crew,
			"completion_hint" = ""
		))

	return available

/datum/controller/subsystem/storyteller/proc/get_story_context()
	// Контекст метаистории
	return story_context

/datum/controller/subsystem/storyteller/proc/get_dynamic_context()
	// Контекст метаистории
	return dynamic_context
