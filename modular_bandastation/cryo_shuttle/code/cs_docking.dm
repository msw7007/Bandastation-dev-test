/obj/docking_port/mobile/arrivals/proc/check_dolls()
	var/inactive_players = list()
	var/candidate_list = list()
	for(var/mob/living/mob as anything in GLOB.mob_list)
		if (get_area(mob) in areas)
			candidate_list += mob

	for(var/mob/living/candidate as anything in candidate_list)
		if(!candidate.client && !istype(candidate, /mob/dead/observer))
			inactive_players += candidate

	for(var/mob/living/clear_candidate in inactive_players)
		delete_inactive_player(clear_candidate)

/obj/docking_port/mobile/arrivals/proc/delete_inactive_player(target)
	var/list/thing_list = list()
	var/mob/living/mob = target
	for(var/obj/thing in mob.contents)
		if (!istype(thing, /obj/item/bodypart) && !istype(thing, /obj/item/implant))
			thing_list += thing.type

	var/datum/supply_pack/misc/new_crate = new()
	new_crate.name = "Возврат предметов - " + mob.name
	new_crate.contains = thing_list
	new_crate.crate_name = "Возврат предметов - " + mob.name
	new_crate.cost = 0
	new_crate.hidden = TRUE
	new_crate.special = TRUE
	mob.ckey = ""
	qdel(mob)

	var/datum/supply_order/order = new(pack = new_crate,orderer = "Нанотрейзен",orderer_rank = "Automated",orderer_ckey = "system",reason = "Возвращение вещей ушедших со смены",charge_on_purchase = FALSE,can_be_cancelled = FALSE)
	SSshuttle.shopping_list += order

/obj/docking_port/mobile/arrivals/initiate_docking(obj/docking_port/stationary/S1, force=FALSE)
	var/docked = S1 == assigned_transit
	sound_played = FALSE
	if(docked) //about to launch
		if(!force_depart)
			var/cancel_reason
			if(PersonCheck())
				cancel_reason = "lifeform dectected on board"
			else if(NukeDiskCheck())
				cancel_reason = "critical station device detected on board"
			if(cancel_reason)
				mode = SHUTTLE_IDLE
				if(console)
					console.say("Launch cancelled, [cancel_reason].")
				return
		force_depart = FALSE
	. = ..()
	check_dolls()
	if(!. && !docked && !damaged)
		if(console)
			console.say("Welcome to your new life, employees!")
		for(var/L in queued_announces)
			var/datum/callback/C = L
			C.Invoke()
		LAZYCLEARLIST(queued_announces)

/obj/machinery/computer/shuttle/cryo_console
	name = "консоль вызова шаттла прибытия"
	desc = "Консоль для вызова шаттла прибытия в случае необходимости покинуть станцию."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "req_comp_off"
	base_icon_state = "req_comp"
	density = FALSE
	interaction_flags_atom = INTERACT_ATOM_ATTACK_HAND
	active_power_usage = 0
	max_integrity = 1500
	armor_type = /datum/armor/machinery_cryo_shuttle_console

/datum/armor/machinery_cryo_shuttle_console
	melee = 90
	bullet = 90
	laser = 90
	energy = 90
	fire = 90
	acid = 90

/obj/machinery/computer/shuttle/cryo_console/Initialize(mapload)
	. = ..()
	find_and_hang_on_wall()

/obj/machinery/computer/shuttle/cryo_console/interact(mob/user)
	SSshuttle.arrivals.SendToStation()
