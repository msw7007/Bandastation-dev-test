/datum/map_template/shuttle/cryo_shuttle
	port_id = "cryo"
	who_can_purchase = null
	suffix = "shuttle"
	name = "СДС Шаттл Мороз"
	var/in_deep_space = TRUE

/datum/map_template/shuttle/cryo_shuttle/LateInitialize()
	areas = list()

	for(var/area/shuttle/cryo_shuttle/cryo_shuttle_area in GLOB.areas)
		areas += cryo_shuttle_area

/datum/map_template/shuttle/cryo_shuttle/proc/get_players_on_shuttle()
    var/list/players_on_shuttle = src.get_contents()  // Получить всех мобов на шатле
    var/list/disconnected_players = list()
	var/list/active_players = list()

    for(var/mob/living/H in players_on_shuttle)
        if(H.client) // Если у моба есть клиент, он активен
            active_players += H
		else
			disconnected_players += H

    return list(disconnected_players, active_players)

/datum/map_template/shuttle/cryo_shuttle/proc/delete_inactive_players_and_save_outfits()
    var/list/deletion_list = get_deletion_list()
    var/list/outfits = list()

    for(var/mob/living/carbon/human/H in deletion_list)
        var/outfit = H.get_outfit()
        outfits[H] = outfit  // Сохраняем аутфит
        H.destroy()  // Удаляем куклу

    return outfits

/datum/map_template/shuttle/cryo_shuttle/proc/add_outfits_to_cargo_shuttle(outfits)
    var/cargo_shuttle = get_cargo_shuttle()

    for(var/mob/living/carbon/human/H in outfits)
        var/outfit = outfits[H]
        cargo_shuttle.cargo += outfit  // Добавляем аутфит в карго

    approve_cargo_shuttle(cargo_shuttle)
    send_cargo_shuttle(cargo_shuttle)

/proc/start_cryo_shuttle_timer(shuttle, port)
    spawn(30 SECONDS)  // Запуск 30-секундного таймера
    if(shuttle.docked == port)  // Проверяем, что шатл все еще в порту
        move_shuttle_to_destination(shuttle, some_other_port)

/area/shuttle/cryo_shuttle
	name = "Cryo Shuttle"
	area_flags = UNIQUE_AREA// SSjob refers to this area for latejoiners
