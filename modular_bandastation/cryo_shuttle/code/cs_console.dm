/obj/machinery/computer/shuttle/cryo_console
	name = "Cryo Shuttle Call Console"
	desc = "A console used to call the cryo shuttle."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "req_comp_off"
	base_icon_state = "req_comp"
	density = TRUE
	active_power_usage = 0
	max_integrity = 1500
	armor_type = /datum/armor/machinery_cryo_shuttle_console
	shuttleId = "cryo_shuttle"
	possible_destinations = "cryo_shuttle;cryo_shuttle_deep"

/obj/machinery/computer/shuttle/cryo_console_shuttle
	name = "Cryo Shuttle Console"
	desc = "A console used to launch the cryo shuttle."
	density = TRUE
	active_power_usage = 0
	max_integrity = 1500
	armor_type = /datum/armor/machinery_cryo_shuttle_console
	shuttleId = "cryo_shuttle"
	possible_destinations = "cryo_shuttle;cryo_shuttle_deep"

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
