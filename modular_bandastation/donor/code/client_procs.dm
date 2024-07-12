#define MAX_SAVE_SLOTS_SS220 5

/datum/controller/subsystem/dbcore/NewQuery(sql_query, arguments, allow_during_shutdown=FALSE, disable_replace = FALSE)
	//If the subsystem is shutting down, disallow new queries
	if(!allow_during_shutdown && shutting_down)
		CRASH("Attempting to create a new db query during the world shutdown")

	if(!isnull(GLOB.whitelist))
		return ..()

	if(disable_replace)
		return ..()

	if(IsAdminAdvancedProcCall())
		log_admin_private("ERROR: Advanced admin proc call led to sql query: [sql_query]. Query has been blocked")
		message_admins("ERROR: Advanced admin proc call led to sql query. Query has been blocked")
		return FALSE
	return new /datum/db_query(connection, sql_query, arguments)

/client/proc/CheckAutoDonatorLevel(client/C)
	var/list/big_worker = list("Администратор", "Старший Администратор", "Старший Разработчик", "Разработчик", "Бригадир мапперов", "Маппер")

	if(C.holder)
		C.donator_level = (C.holder.ranks in big_worker) ? BIG_WORKER_TIER : LITTLE_WORKER_TIER
		return

	var/is_wl = isnull(GLOB.whitelist) ? TRUE : FALSE

	var/datum/db_query/rank_ckey_read = SSdbcore.NewQuery(
		"SELECT admin_rank FROM [is_wl ? "admin" : "admin_wl"] WHERE ckey=:ckey",
			list("ckey" = C.ckey), disable_replace = is_wl)

	if(!rank_ckey_read.warn_execute())
		qdel(rank_ckey_read)
		return

	while(rank_ckey_read.NextRow())
		C.donator_level = (rank_ckey_read.item[1] in big_worker) ? BIG_WORKER_TIER : LITTLE_WORKER_TIER

	qdel(rank_ckey_read)

/client/proc/process_result(datum/db_query/Q, client/C)
	if(is_guest_key(C.ckey))
		return

	CheckAutoDonatorLevel(C)

	while(Q.NextRow())
		var/total = Q.item[1]
		var/donator_level = 0
		switch(total)
			if(220 to 439)
				donator_level = 1
			if(440 to 999)
				donator_level = 2
			if(1000 to 2219)
				donator_level = 3
			if(2220 to 9999)
				donator_level = 4
			if(10000 to INFINITY)
				donator_level = DONATOR_LEVEL_MAX

		switch(C.donator_level)
			if(LITTLE_WORKER_TIER)
				C.donator_level = LITTLE_WORKER_TTS_LEVEL > donator_level ? C.donator_level : donator_level
			if(BIG_WORKER_TIER)
				C.donator_level = BIG_WORKER_TTS_LEVEL > donator_level ? C.donator_level : donator_level
			else
				C.donator_level = donator_level


	C.donor_loadout_points()
	C.donor_character_slots()

/client/proc/get_query(client/C)
	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT CAST(SUM(amount) as UNSIGNED INTEGER) FROM budget
		WHERE ckey=:ckey
			AND is_valid=true
			AND date_start <= NOW()
			AND (NOW() < date_end OR date_end IS NULL)
		GROUP BY ckey
	"}, list("ckey" = C.ckey))

	return query

/client/proc/donor_loadout_points()
	if(!prefs)
		return

	prefs.max_gear_slots = 4

	switch(donator_level)
		if(1)
			prefs.max_gear_slots += 2
		if(2)
			prefs.max_gear_slots += 3
		if(3)
			prefs.max_gear_slots += 5
		if(4)
			prefs.max_gear_slots += 8
		if(5)
			prefs.max_gear_slots += 12
		if(LITTLE_WORKER_TIER)
			prefs.max_gear_slots += 1
		if(BIG_WORKER_TIER)
			prefs.max_gear_slots += 4

/client/proc/donor_character_slots()
	if(!prefs)
		return

	prefs.max_save_slots = MAX_SAVE_SLOTS_SS220 + 5 * donator_level

	switch(donator_level)
		if(LITTLE_WORKER_TIER)
			prefs.max_save_slots = 7
		if(BIG_WORKER_TIER)
			prefs.max_save_slots = 10

	prefs.max_save_slots = prefs.max_save_slots

#undef MAX_SAVE_SLOTS_SS220

/client/proc/is_donor_allowed(required_donator_level)
	switch(donator_level)
		if(LITTLE_WORKER_TIER)
			if(required_donator_level > LITTLE_WORKER_LEVEL)
				return FALSE
		if(BIG_WORKER_TIER)
			if(required_donator_level > BIG_WORKER_LEVEL)
				return FALSE
	return required_donator_level <= donator_level
