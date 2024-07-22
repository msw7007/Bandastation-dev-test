/obj/machinery/computer/shuttle/cryo_shuttle_console
	name = "Cryo Shuttle Console"
	desc = "A console used to call the cryo shuttle."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "req_comp_off"
	base_icon_state = "req_comp"
	density = TRUE
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 0.15
	max_integrity = 1500
	armor_type = /datum/armor/machinery_cryo_shuttle_console
	shuttleId = "cryo_shuttle"
	possible_destinations = "commonmining_home;lavaland_common_away;landing_zone_dock;mining_public;cryo_shuttle"

/datum/armor/machinery_cryo_shuttle_console
	melee = 90
	bullet = 90
	laser = 90
	energy = 90
	fire = 90
	acid = 90

/obj/machinery/computer/shuttle/cryo_shuttle_console/Initialize(mapload)
	. = ..()
	find_and_hang_on_wall()

