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

	// Антаги
	state["living_antags"] = length(GLOB.current_living_antags)

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
