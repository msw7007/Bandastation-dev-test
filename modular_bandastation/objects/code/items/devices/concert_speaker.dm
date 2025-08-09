/obj/structure/concertspeaker
	name = "\proper концертная колонка"
	desc = "Концертная колонка для синронизации с концертной установкой."
	icon = 'modular_bandastation/objects/icons/obj/machines/jukebox.dmi'
	icon_state = "concertspeaker_unanchored"
	base_icon_state = "concertspeaker"
	anchored = FALSE
	density = FALSE
	layer = 4
	resistance_flags = NONE
	max_integrity = 250
	integrity_failure = 25
	var/active = FALSE
	var/stat = 0
	var/code = 0
	var/frequency = 1400
	var/receiving = TRUE
	var/shell_capacity = SHELL_CAPACITY_SMALL

/obj/structure/concertspeaker/examine()
	. = ..()
	. += "<span class='notice'>Используйте гаечный ключ, чтобы разобрать для транспортировки и собрать для игры.</span>"

/obj/structure/concertspeaker/update_icon_state()
	. = ..()
	if(stat & (BROKEN))
		icon_state = "[base_icon_state]_broken"
	else
		icon_state = "[base_icon_state][active ? "_active" : null]"

/obj/structure/concertspeaker/wrench_act(mob/living/user, obj/item/I)
	if(resistance_flags & INDESTRUCTIBLE)
		return

	if(!anchored && !isinspace())
		to_chat(user, span_notice("You secure [name] to the floor."))
		anchored = TRUE
		density = TRUE
		layer = 5
		update_icon()
	else if(anchored)
		to_chat(user, span_notice("You unsecure and disconnect [src]."))
		anchored = FALSE
		density = FALSE
		layer = initial(layer)
		update_icon()
		src.force_stop_all_listeners()

	icon_state = "[base_icon_state][anchored ? null : "_unanchored"]"
	playsound(src, 'sound/items/deconstruct.ogg', 50, 1)

	return TRUE

/obj/structure/concertspeaker/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/shell, list(), shell_capacity)

/obj/structure/concertspeaker/proc/signal_callback()
	active = !active
	update_icon()

/obj/structure/concertspeaker/proc/force_stop_all_listeners()
	// Ищем все интегралки в оболочке и гасим ресиверы
	for(var/obj/item/integrated_circuit/C in src)
		for(var/obj/item/circuit_component/concert_listener/L in C.attached_components)
			L.stop_playback()


















/obj/item/circuit_component/concert_listener
	display_name = "Concert Speaker Receiver"
	desc = "Компонент, который получает с систему управления концертом информацию о текущем треке. Разработано Саундхенд."

	var/datum/port/output/is_playing
	var/datum/port/output/started_playing
	var/datum/port/output/stopped_playing

	var/playing = FALSE

/obj/item/circuit_component/concert_listener/populate_ports()
	is_playing = add_output_port("Is Playing", PORT_TYPE_NUMBER)
	started_playing = add_output_port("Started Playing", PORT_TYPE_SIGNAL)
	stopped_playing = add_output_port("Stopped Playing", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/concert_listener/proc/play_track()
	if(playing || !parent) return

	var/obj/item/integrated_circuit/C = parent
	var/atom/movable/sh = C?.shell
	if(istype(sh, /obj/structure/concertspeaker))
		var/obj/structure/concertspeaker/S = sh
		if(!S.anchored)
			return

	playing = TRUE
	is_playing.set_output(TRUE)
	started_playing.set_output(COMPONENT_SIGNAL)
	update_parent()

/obj/item/circuit_component/concert_listener/proc/stop_playback()
	if(!playing || !parent) return
	playing = FALSE
	is_playing.set_output(FALSE)
	stopped_playing.set_output(COMPONENT_SIGNAL)
	update_parent()

/obj/item/circuit_component/concert_listener/proc/update_parent()
	var/obj/item/integrated_circuit/C = parent
	var/atom/movable/shell = C?.shell
	if(istype(shell, /obj/structure/concertspeaker))
		var/obj/structure/concertspeaker/S = shell
		S.active = (playing && S.anchored)
		S.update_icon()

	if(istype(C, /obj/machinery/jukebox/concertspeaker))
		var/obj/machinery/jukebox/concertspeaker/J = C
		J.music_player?.update_all()

/datum/supply_pack/concert_speaker
	access = NONE
	group = "Imports"
	goody = TRUE
	cost = CARGO_CRATE_VALUE
	crate_name = "Контейнер Колонки Саундхенд"
	crate_type = /obj/structure/closet/crate
	discountable = SUPPLY_PACK_NOT_DISCOUNTABLE
	name = "Колонка Саундхенд"
	desc = "Контейнер содержит колонку Саундхенд."
	contains = list(/obj/structure/concertspeaker)
