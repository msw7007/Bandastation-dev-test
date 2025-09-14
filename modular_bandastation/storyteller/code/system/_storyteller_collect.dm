#define STORYTELLER_CHAOS_DEATH 8
#define STORYTELLER_CHAOS_VIOLENCE 20
#define STORYTELLER_CHAOS_ALARMS 12
#define STORYTELLER_CHAOS_REFRESH 120
#define STORYTELLER_CHAOS_HISTORY_LIMIT 30
#define STORYTELLER_CHAOS_ALPHA 0.3

// Внутри /datum/controller/subsystem/storyteller
var/list/chaos_injections = list() // key=id (строка), value=list("until"=ts, "value"=число)

/datum/controller/subsystem/storyteller/proc/add_chaos_injection(id, value = 5, duration = 5 MINUTES)
	if(!istext(id) || !length(id)) return
	if(value <= 0 || duration <= 0) return
	chaos_injections[id] = list("until" = world.time + duration, "value" = value)
	log_storyteller("Chaos injection: [id] +[value] for [round(duration/10)]ds")

/datum/controller/subsystem/storyteller/proc/get_active_chaos_injection_sum()
	var/sum = 0
	if(!islist(chaos_injections) || !chaos_injections.len) return sum

	// очистим истёкшие и просуммируем активные
	for(var/id in chaos_injections.Copy())
		var/list/ent = chaos_injections[id]
		if(!islist(ent)) { chaos_injections -= id; continue }
		if(world.time >= (ent["until"] || 0))
			chaos_injections -= id
		else
			sum += max(0, ent["value"] || 0)
	return sum

/datum/controller/subsystem/storyteller/proc/smooth_chaos(var/raw_score)
	var/prev = chaos_cache?["smooth"] || 0
	var/new_record  = round((1 - STORYTELLER_CHAOS_ALPHA) * prev + STORYTELLER_CHAOS_ALPHA * raw_score, 0.1)
	return clamp(new_record, 0, 100)

/datum/controller/subsystem/storyteller/proc/get_round_time_marks()
	var/minutes = world.time / (1 MINUTES)
	var/hours   = minutes / 60
	return list("minutes" = minutes, "hours" = hours)

/// Линейная интерполяция между предыдущим и текущим шагом массива с шагом 10 минут
/// series: list чисел (длина N, N>=1). Каждый элемент — значение для 10-минутного окна.
/// minute_now: текущая минута раунда (целое/вещественное).
/datum/controller/subsystem/storyteller/proc/interp_step10_series(list/series, minute_now)
	if(!islist(series) || !series.len)
		return 0

	var/N = series.len
	var/period_minutes = N * 10
	// минутная позиция внутри периода
	var/min_in_period = minute_now % period_minutes

	// индекс текущего 10-минутного шага (0..N-1), floor без дроби
	var/ten = 10
	var/whole = min_in_period - (min_in_period % ten) // убрали остаток
	var/b = whole / ten                     // текущий шаг
	var/p = (b - 1 + N) % N                // предыдущий шаг (с обёрткой)

	// доля прогресса внутри текущего шага (0..1)
	var/f = (min_in_period % ten) / 10.0

	// значения в шагах
	var/val_prev = series[p + 1]
	var/val_curr = series[b + 1]

	// линейная интерполяция между prev→curr
	return val_prev + (val_curr - val_prev) * f

/// Главный расчёт: целевой хаос и бюджет
/// Возвращает:
///  - target_base       — интерполированная кривая без разброса/множителя
///  - scatter_now       — интерполированный разброс (абсолютный)
///  - rand_offset       — случайное число в [-scatter; +scatter]
///  - cycle_mult        — множитель по часам
///  - target_final      — clamp( (target_base + rand_offset) * cycle_mult, 0..100 )
///  - current           — сглаженный текущий хаос (из кэша)
///  - budget            — target_final - current
///  - minutes, hours    — удобные метки
/datum/controller/subsystem/storyteller/proc/compute_target_chaos_and_budget()
	var/datum/storyteller_profile/P = get_current_profile_datum()
	if(!P) return null

	// метки времени раунда
	var/list/T = get_round_time_marks()
	var/minutes = T["minutes"]
	var/hours   = T["hours"]

	// интерполированный таргет по кривой (10-минутные шаги)
	var/target_base = interp_step10_series(P.chaos_curve, minutes)

	// интерполированный разброс (абсолютные значения!)
	var/scatter_now = 0
	if(P.chaos_scatter_pct && P.chaos_scatter_pct.len) // имя поля оставляем, семантика — абсолют
		scatter_now = max(0, interp_step10_series(P.chaos_scatter_pct, minutes))

	// случайный оффсет в диапазоне [-scatter; +scatter]
	var/rand_offset = (rand(-1000, 1000) / 1000.0) * scatter_now

	// цикловой множитель: берём по номеру часа, иначе последний
	var/cycle_mult = 1.0
	if(P.chaos_cycle_multipliers && P.chaos_cycle_multipliers.len)
		var/idx = min(hours + 1, P.chaos_cycle_multipliers.len)
		cycle_mult = P.chaos_cycle_multipliers[idx]

	// итоговая цель и бюджет
	var/target_final = clamp( (target_base + rand_offset) * cycle_mult, 0, 100)
	var/current = chaos_cache?["smooth"] || 0
	var/budget  = target_final - current

	return list(
		"minutes"       = minutes,
		"hours"         = hours,
		"target_base"   = round(target_base, 0.1),
		"scatter_now"   = round(scatter_now, 0.1),
		"rand_offset"   = round(rand_offset, 0.1),
		"cycle_mult"    = cycle_mult,
		"target_final"  = round(target_final, 0.1),
		"current"       = round(current, 0.1),
		"budget"        = round(budget, 0.1)
	)

/datum/controller/subsystem/storyteller/proc/get_chaos_cached(var/force = FALSE)
	var/pause_timer = STORYTELLER_CHAOS_REFRESH SECONDS
	if (force || (world.time - last_chaos_calc >= pause_timer))
		var/list/raw = compute_raw_chaos(cached_state)                  // <— твоя функция
		var/raw_score = islist(raw) ? (raw["score"] || 0) : (raw+0)
		var/new_smooth = smooth_chaos(raw_score)

		chaos_cache["raw"] = raw_score
		chaos_cache["smooth"] = new_smooth
		chaos_cache["parts"] = islist(raw) ? (raw["parts"] || list()) : list()
		chaos_cache["ts"] = world.time
		last_chaos_calc = world.time

		chaos_history += list(list("ts" = world.time, "score" = new_smooth))
		if (chaos_history.len > STORYTELLER_CHAOS_HISTORY_LIMIT)
			chaos_history.Cut(1, chaos_history.len - STORYTELLER_CHAOS_HISTORY_LIMIT + 1)

	return chaos_cache

/datum/controller/subsystem/storyteller/proc/compute_raw_chaos(var/list/payload)
	var/list/state = payload?["state"] || list()
	var/list/players = payload?["players"] || list()
	var/list/antags = payload?["antags"] || list()

	var/players_alive = state?["players_alive"] || 0
	var/pop = max(players_alive, 1)

	var/deaths_recent = state?["deaths_recent"] || 0
	var/violence_raw  = state?["violence_score"] || 0
	var/air_alarms    = state?["air_alarms"] || 0
	var/alert_level   = "[state?["alert_level"]]"

	var/crit_count = 0
	if (islist(players))
		for (var/list/P in players)
			if (P?["status"] == "crit")
				crit_count++

	var/antag_alive = 0
	if (islist(antags?["list"]))
		for (var/list/A in antags["list"])
			if (A?["is_alive"]) antag_alive++

	var/s_deaths   = clamp(deaths_recent * STORYTELLER_CHAOS_DEATH, 0, 100)                     	// 1 смерть за 5 мин ≈ +12
	var/s_violence = clamp(((violence_raw / pop) * STORYTELLER_CHAOS_VIOLENCE) * 100.0, 0, 100)  	// ~40 HP дефицита на живого = потолок
	var/s_alarms   = clamp(air_alarms * STORYTELLER_CHAOS_ALARMS, 0, 100)                         	// 12–13 тревог ≈ потолок
	var/s_alert    = (alert_level == "red") ? 25 : (alert_level == "blue") ? 10 : 0
	var/s_crit     = clamp((crit_count / pop) * 100.0, 0, 100)             							// 10% экипажа в крите → +10
	var/s_antag    = clamp((antag_alive / pop) * 100.0, 0, 100)            							// доля живых антагов (вклад ниже весом)

	var/w_deaths   = 0.30
	var/w_violence = 0.30
	var/w_alarms   = 0.15
	var/w_alert    = 0.10
	var/w_crit     = 0.10
	var/w_antag    = 0.50

	var/raw = (s_deaths * w_deaths)	+ (s_violence * w_violence)	+ (s_alarms * w_alarms)	+ (s_alert * w_alert) + (s_crit * w_crit) + (s_antag * w_antag)
	raw = clamp(round(raw, 0.1), 0, 100)

	var/inj = get_active_chaos_injection_sum()
	if(inj > 0)
		raw = clamp(raw + min(20, inj), 0, 100)

	return list(
		"score" = raw,
		"parts" = list(
			"deaths_recent" = s_deaths,
			"violence"      = s_violence,
			"air_alarms"    = s_alarms,
			"alert_level"   = s_alert,
			"crit_ratio"    = s_crit,
			"antag_ratio"   = s_antag,
			"pop_alive"     = players_alive
		)
	)

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
	state["departments"] = get_department_data()

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

	for(var/mob/living/carbon/human/H in GLOB.player_list)
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

	for (var/mob/living/carbon/human/H in GLOB.player_list)
		if (!H?.client || !H?.mind || !H.mind.assigned_role)
			continue

		// 1) определить отдел (fallback -> "Other")
		var/department = map_role_to_department(H.mind.assigned_role)

		// 2) лениво создать запись для отдела
		if (!islist(dept_summary[department]))
			dept_summary[department] = list(
				"players" = 0,
				"avg_exp" = 0
			)

		var/list/D = dept_summary[department]

		// 3) опыт (часы) -> прогресс 0..1
		var/hours = 0
		var/tmp_hours = H.client?.calc_exp_type(H.mind.assigned_role)
		if (isnum(tmp_hours)) hours = tmp_hours
		var/progress = clamp(hours / 300, 0, 1)

		// 4) инкременты
		D["players"] = (D["players"] || 0) + 1
		D["avg_exp"] = (D["avg_exp"] || 0) + progress

	// 5) финализация: среднее и опционально "strength"
	for (var/dept in dept_summary)
		var/list/D = dept_summary[dept]
		var/count = D["players"] || 0
		if (count > 0)
			D["avg_exp"] = D["avg_exp"] / count
		// strength = 0..100, можно подстроить формулу под свои нужды
		D["avg_exp"] = round((D["avg_exp"] || 0) * 100)

	return dept_summary

/datum/controller/subsystem/storyteller/proc/map_role_to_department(role)
	var/datum/job/J = null
	if (istype(role, /datum/job))
		J = role
	else if (istype(role, /datum/mind))
		J = SSjob.get_job(role)

	if (!J)
		return "Other"

	var/flags = J.departments_bitflags
	if (flags & DEPARTMENT_BITFLAG_MEDICAL)
		return "Medical"
	if (flags & DEPARTMENT_BITFLAG_ENGINEERING)
		return "Engineering"
	if (flags & DEPARTMENT_BITFLAG_SECURITY)
		return "Security"
	if (flags & DEPARTMENT_BITFLAG_SCIENCE)
		return "Science"
	if (flags & DEPARTMENT_BITFLAG_CARGO)
		return "Supply"
	if (flags & DEPARTMENT_BITFLAG_SERVICE)
		return "Service"
	if (flags & DEPARTMENT_BITFLAG_COMMAND)
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

	for (var/datum/antagonist/A in GLOB.antagonists)
		if (!A.owner)
			continue

		var/mob/M = A.owner.current
		var/is_alive = (istype(M) && M.stat != DEAD)
		var/status = "unknown"
		if (istype(M))
			if (M.stat == DEAD)
				status = "dead"
			else if (M.stat == UNCONSCIOUS)
				status = "crit"
			else
				status = "alive"

		var/assigned = A.owner?.assigned_role
		var/department = map_role_to_department(assigned || "")

		var/list/objectives = list()
		for (var/datum/objective/O in A.objectives)
			if (O?.explanation_text)
				objectives += "[O.explanation_text]"

		var/list/info = list(
			"ckey" = A.owner.key,
			"role" = A.name,
			"job" = assigned,
			"department" = department,
			"is_alive" = is_alive,
			"status" = status,
			"objectives" = objectives
		)

		entries += list(info)

	antags["count"] = length(entries)
	antags["list"] = entries
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
