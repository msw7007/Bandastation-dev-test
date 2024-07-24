/datum/map_template/shuttle/cryo_shuttle
	port_id = "cryo"
	who_can_purchase = null
	suffix = "shuttle"
	name = "СДС Шаттл Мороз"
	var/in_deep_space = TRUE

/obj/docking_port/mobile/cryo_shuttle
	name = "cryo shuttle"
	shuttle_id = "cryo_shuttle"
	callTime = 100
	movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)

/obj/docking_port/stationary/cryo_shuttle
	name = "Стыковочный порт дальнего шатла"
	shuttle_id = "cryo_shuttle"

/obj/docking_port/stationary/cryo_shuttle_deep
	name = "Точка выхода с сектора"
	shuttle_id = "cryo_shuttle"
	roundstart_template = /datum/map_template/shuttle/cryo_shuttle

/area/shuttle/cryo_shuttle
	name = "Cryo Shuttle"
	area_flags = UNIQUE_AREA// SSjob refers to this area for latejoiners
