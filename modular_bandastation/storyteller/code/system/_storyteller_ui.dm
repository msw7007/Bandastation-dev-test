// ============================
// Storyteller Admin Panel (tgui)
// стилистика как у /datum/force_event
// ============================

/proc/st2_cmp_desc(a, b)
	if(!islist(a) || !islist(b)) return 0
	var/sa = a["score"] || 0
	var/sb = b["score"] || 0
	return sb - sa

// ---- Админ-верб, аналогично Force Event ----

ADMIN_VERB(storyteller_panel, R_FUN, "Storyteller (Panel)", "Open Storyteller control panel.", ADMIN_CATEGORY_EVENTS)
	user.holder.storyteller_panel()

/datum/admins/proc/storyteller_panel()
	if(!check_rights(R_FUN))
		return
	if(!SSstoryteller?.is_active())
		to_chat(usr, span_warning("Storyteller is not active."), confidential = TRUE)
		return
	var/datum/storyteller_panel/ui = new(usr)
	ui.ui_interact(usr)

// ---- Сам датум панели ----

/datum/storyteller_panel

/datum/storyteller_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Storyteller") // имя интерфейса в tgui
		ui.open()

/datum/storyteller_panel/ui_state(mob/user)
	return ADMIN_STATE(R_FUN)

// Отдаём редко меняющиеся штуки (профили и т.п.)
/datum/storyteller_panel/ui_static_data(mob/user)
	var/list/data = list()
	data["inactive"] = !SSstoryteller?.is_active()
	if (data["inactive"])
		return data

	data["profiles"] = SSstoryteller.get_all_profiles() || list()

	// ВСЕ доступные ID с названиями (без фильтров по популяции; это справочник)
	data["all_events"] = SSstoryteller.collect_available_events(TRUE) || list()
	return data

// Живые данные на каждый апдейт
/datum/storyteller_panel/ui_data(mob/user)
	var/list/data = list()
	data["inactive"] = !SSstoryteller?.is_active()
	if (data["inactive"])
		return data

	var/datum/storyteller_profile/profile = SSstoryteller.get_current_profile_datum()
	data["profile"] = SSstoryteller.get_profile_as_list(profile)

	SSstoryteller.get_chaos_cached()
	var/list/target = SSstoryteller.compute_target_chaos_and_budget() || list()
	data["target"] = target
	data["chaos"] = SSstoryteller.chaos_cache || list()

	// Метрики станции
	var/list/st_state = SSstoryteller.cached_state || list()
	data["metrics"] = list(
		"players_total" = st_state?["state"]?["players_total"] || 0,
		"players_alive" = st_state?["state"]?["players_alive"] || 0,
		"deaths_recent" = st_state?["state"]?["deaths_recent"] || 0,
		"air_alarms"    = st_state?["state"]?["air_alarms"] || 0,
		"violence"      = st_state?["state"]?["violence_score"] || 0,
		"credits_total" = st_state?["state"]?["station_credits"]?["total"] || 0,
		"antags"        = st_state?["antags"]?["count"] || 0,
		"events_known"  = length(st_state?["events"] || list()),
		"custom_goals"  = length(SSstoryteller?.custom_storyteller_goals || list())
	)

	// Отделы (ключи «players» и «avg_exp», чтобы UI не путался)
	var/list/depts = st_state?["state"]?["departments"] || list()
	var/list/dept_out = list()
	for (var/dep in depts)
		var/list/row = depts[dep]
		if (!islist(row)) continue
		dept_out["[dep]"] = list(
			"players" = (row?["players"] || row?["count"] || 0),
			"avg_exp" = (row?["avg_exp"] || 0)
		)
	data["departments"] = dept_out

	// Фаза (для компактного блока в UI)
	var/list/phase = SSstoryteller.get_current_phase_info()
	var/phase_total = length(SSstoryteller?.story_context || list())
	data["phase_plan"] = islist(profile?.phase_plan) ? profile.phase_plan.Copy() : list()

	data["phase"] = list(
		"index" = phase?["index"] || -1,
		"title" = phase?["title"] || "",
		"description" = phase?["description"] || "",
		"duration_min" = phase?["duration_min"] || 0,
		"pool_count" = length(phase?["pool"] || list())
	)
	data["phase_total"] = phase_total

	// Кандидаты + локальный скоринг для отображения (как раньше)
	var/list/att = islist(profile.attention_tags) ? profile.attention_tags : list()
	var/list/ign = islist(profile.ignore_tags) ? profile.ignore_tags : list()
	var/list/pref = islist(profile.preferred_targets) ? profile.preferred_targets : list()

	var/list/cands = SSstoryteller.collect_available_events(!SSticker.HasRoundStarted()) || list()
	var/budget = target?["budget"] || 0
	var/list/scored = list()

	// Сет для быстрого чек-буста «в пуле фазы»
	var/list/phase_pool = list()
	if (islist(phase?["pool"]))
		for (var/P in phase["pool"])
			phase_pool["[P]"] = TRUE

	for (var/list/E in cands)
		var/id = "[E["id"]]"
		var/type = "[E["type"]]"
		var/name = E["name"] || id
		var/weight = max(0.1, E["weight"] || 1)
		var/impact = max(1, E["chaos_impact"] || 1)

		// мета-кд
		var/list/meta = SSstoryteller.get_event_metadata(id) || list()
		var/cooldown = (meta["cooldown"] || 300) SECONDS

		// рантайм для «на кд»
		var/list/rt = SSstoryteller.event_runtime?[id]
		var/on_cd = FALSE
		var/cd_left = 0
		if (islist(rt))
			var/left = cooldown - (world.time - (rt["last_ts"] || 0))
			if (left > 0)
				on_cd = TRUE
				cd_left = round(left / 10)

		// вкусы профиля
		var/taste = 0
		var/list/tags = list()
		if (islist(E["tags"])) tags = E["tags"]
		else if (istext(E["tags"])) tags = splittext(E["tags"], ",")

		for (var/t in tags)
			var/tt = lowertext("[t]")
			if (tt in att) taste += 1
			if (tt in ign) taste -= 2

		var/dep = "[E["target_departs"] || ""]"
		if (dep && (dep in pref)) taste += 1

		// базовый скор для отображения
		var/score = weight + taste
		if (budget < 0)
			score = score / (1 + impact / 10.0)
		else
			score = score * (1 + min(0.5, budget / 100.0)) + (impact * 0.1)

		if (islist(rt))
			var/times = rt["times"] || 0
			score = score / (1 + times * 0.25)

		var/in_phase_pool = (phase_pool[id] ? TRUE : FALSE)

		scored += list(list(
			"id" = id,
			"type" = type,
			"name" = name,
			"dept" = E["target_departs"] || "",
			"tags" = tags,
			"weight" = round(weight, 0.1),
			"impact" = impact,
			"score" = round(score, 0.1),
			"cooldown" = round(cooldown / 10),
			"on_cd" = on_cd,
			"cd_left" = cd_left,
			"phase_boosted" = in_phase_pool
		))

	// сортировка по убыванию score
	scored = sortTim(scored, GLOBAL_PROC_REF(st2_cmp_desc))
	data["scored"] = scored

	// История (до 50)
	var/list/hist = SSstoryteller.get_storyteller_history() || list()
	var/cnt = length(hist)
	if (cnt > 50)
		hist = hist.Copy(cnt - 49, cnt + 1)
	data["history"] = hist

	data["globals"] = list("cooldown_default_sec" = SSstoryteller.storytell_llm_frequency)

	return data

// Экшены с панели (сигнатура как в force_event)
/datum/storyteller_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	if(!check_rights(R_FUN))
		return

	switch(action)
		if("refresh")
			SSstoryteller.update_cached_state(FALSE)
			return TRUE

		if("pulse_local")
			SSstoryteller.update_cached_state(FALSE)
			SSstoryteller.get_chaos_cached()
			var/s = SSstoryteller.decide_and_trigger(FALSE)
			message_admins("[key_name_admin(usr)] pulse_local → [s ? "started" : "no launch"].")
			return TRUE

		if("pulse_llm")
			SSstoryteller.update_cached_state(FALSE)
			SSstoryteller.get_chaos_cached()
			SSstoryteller.make_request("Manual tick", "", FALSE)
			message_admins("[key_name_admin(usr)] pulse_llm requested.")
			return TRUE

		if("trigger")
			var/id = params["id"]
			var/type = params["type"]
			var/force = params["force"] ? TRUE : FALSE
			var/ok = SSstoryteller.trigger_decision(id, null, list("source"="tgui","force"=force), type)
			message_admins("[key_name_admin(usr)] trigger: [type] [id] → [ok ? "OK" : "FAIL"].")
			return TRUE

		if("set_profile")
			var/idp = params["id"]
			if(idp && SSstoryteller.set_storyteller_profile(idp))
				message_admins("[key_name_admin(usr)] set storyteller profile → [idp].")
				return TRUE

		if("finalize_end")
			SSstoryteller.finalize_end_of_round()
			message_admins("[key_name_admin(usr)] requested storyteller finalize_end_of_round().")
			return TRUE

		if("update_profile")
			var/list/changes = params?["changes"]
			if(!islist(changes)) return

			// булевые
			if(!isnull(changes["allow_force_pick"]))  SSstoryteller.current_storyteller_profile.allow_force_pick  = changes["allow_force_pick"] ? TRUE : FALSE

			// числовые (с клампами)
			if(!isnull(changes["frequency"]))
				var/v = text2num(changes["frequency"])
				if(isnum(v)) SSstoryteller.current_storyteller_profile.frequency = clamp(v, 5, 600)

			if(!isnull(changes["deadband"]))
				var/v = text2num(changes["deadband"])
				if(isnum(v)) SSstoryteller.current_storyteller_profile.deadband = clamp(v, 0, 50)

			if(!isnull(changes["min_gap_sec"]))
				var/v = text2num(changes["min_gap_sec"])
				if(isnum(v)) SSstoryteller.current_storyteller_profile.min_gap_sec = clamp(v, 0, 900)

			if(!isnull(changes["drop_shape"]))
				var/v = text2num(changes["drop_shape"])
				if(isnum(v)) SSstoryteller.current_storyteller_profile.drop_shape = clamp(v, 0.1, 3)

			if(!isnull(changes["assist_window"]))
				var/v = text2num(changes["assist_window"])
				if(isnum(v)) SSstoryteller.current_storyteller_profile.assist_window = clamp(v, 0, 50)

			if(!isnull(changes["assist_prob"]))
				var/v = text2num(changes["assist_prob"])
				if(isnum(v)) SSstoryteller.current_storyteller_profile.assist_prob = clamp(v, 0, 100)

			if(!isnull(changes["phase_pool_boost"]))
				var/v = text2num(changes["phase_pool_boost"])
				if(isnum(v)) SSstoryteller.current_storyteller_profile.phase_pool_boost = clamp(v, 0.1, 5)

			// чтобы новая частота/паузы ощущались сразу
			SSstoryteller.last_timer_call = world.time

			message_admins("[key_name_admin(usr)] updated Storyteller profile settings.")
			// Чтобы UI сразу увидел изменения бюджета/хаоса:
			SSstoryteller.update_cached_state(FALSE)
			SSstoryteller.get_chaos_cached(TRUE)
			return TRUE

		if("update_globals")
			var/list/changes = params?["changes"]
			if(!islist(changes)) return

			if(!isnull(changes["cooldown_default_sec"]))
				var/v = text2num(changes["cooldown_default_sec"])
				if(isnum(v)) SSstoryteller.storytell_llm_frequency = clamp(v, 5, 600)

			message_admins("[key_name_admin(usr)] updated Storyteller global settings.")
			SSstoryteller.update_cached_state(FALSE)
			SSstoryteller.get_chaos_cached(TRUE)
			return TRUE

		// Полностью заменить план (bulk save)
		if ("phase_set_plan")
			var/list/new_plan = params["plan"] // ожидаем list фаз [{title=..,duration_min=..,description=.., pool=[...]}]
			var/datum/storyteller_profile/P = SSstoryteller.get_current_profile_datum()
			if (istype(P) && islist(new_plan))
				P.phase_plan = new_plan.Copy()
				message_admins("[key_name_admin(usr)] updated phase_plan ([length(P.phase_plan)] phases).")
				return TRUE

		// Добавить пустую фазу в конец
		if ("phase_add")
			var/datum/storyteller_profile/P = SSstoryteller.get_current_profile_datum()
			if (istype(P))
				if (!islist(P.phase_plan)) P.phase_plan = list()
				P.phase_plan += list(list("title"="Новая фаза","duration_min"=10,"description"="","pool"=list()))
				return TRUE

		// Удалить фазу по индексу (1-based)
		if ("phase_delete")
			var/idx = text2num(params["index"])
			var/datum/storyteller_profile/P = SSstoryteller.get_current_profile_datum()
			if (istype(P) && islist(P.phase_plan) && idx>=1 && idx<=length(P.phase_plan))
				P.phase_plan.Cut(idx, idx+1)
				return TRUE

		// Обновить поля фазы по индексу (title/description/duration_min)
		if ("phase_update")
			var/idx = text2num(params["index"])
			var/list/changes = params["changes"]
			var/datum/storyteller_profile/P = SSstoryteller.get_current_profile_datum()
			if (istype(P) && islist(P.phase_plan) && idx>=1 && idx<=length(P.phase_plan) && islist(changes))
				var/list/ph = P.phase_plan[idx]
				if (changes["title"]) ph["title"] = "[changes["title"]]"
				if (!isnull(changes["description"])) ph["description"] = "[changes["description"]]"
				if (!isnull(changes["duration_min"])) ph["duration_min"] = max(0, round(text2num(changes["duration_min"])))
				return TRUE

		// Добавить id в pool фазы
		if ("phase_pool_add")
			var/idx = text2num(params["index"])
			var/id = params["id"]
			var/datum/storyteller_profile/P = SSstoryteller.get_current_profile_datum()
			if (istype(P) && islist(P.phase_plan) && idx>=1 && idx<=length(P.phase_plan) && id)
				var/list/ph = P.phase_plan[idx]
				if (!islist(ph["pool"])) ph["pool"] = list()
				if (!(id in ph["pool"])) ph["pool"] += id
				return TRUE

		// Удалить id из pool фазы
		if ("phase_pool_remove")
			var/idx = text2num(params["index"])
			var/id = params["id"]
			var/datum/storyteller_profile/P = SSstoryteller.get_current_profile_datum()
			if (istype(P) && islist(P.phase_plan) && idx>=1 && idx<=length(P.phase_plan) && id)
				var/list/ph = P.phase_plan[idx]
				if (islist(ph["pool"]))
					ph["pool"] -= id
				return TRUE

		// Поменять порядок фаз (перемещение idx -> new_idx)
		if ("phase_reorder")
			// ожидаем 0-based индексы из UI
			var/old_idx0 = text2num(params["index"])
			var/new_idx0 = text2num(params["new_index"])
			if (!isnum(old_idx0) || !isnum(new_idx0))
				return

			var/old_pos = old_idx0 + 1 // DM 1-based
			var/new_pos = new_idx0 + 1
			var/datum/storyteller_profile/P = SSstoryteller.get_current_profile_datum()

			if (istype(P) && islist(P.phase_plan))
				var/list/L = P.phase_plan
				if (old_pos >= 1 && old_pos <= L.len && new_pos >= 1 && new_pos <= L.len && old_pos != new_pos)
					var/entry = L[old_pos]
					L.Cut(old_pos, old_pos + 1) // [from, to)
					L.Insert(new_pos, entry)
					return TRUE

	return
