/obj/structure/concertspeaker
	name = "\proper концертная колонка"
	desc = "Концертная колонка для синронизации с концертной установкой."
	icon = 'modular_bandastation/objects/icons/obj/machines/jukebox.dmi'
	icon_state = "concertspeaker_unanchored"
	base_icon_state = "concertspeaker"
	anchored = FALSE
	density = FALSE
	layer = 2.5
	resistance_flags = NONE
	max_integrity = 250
	integrity_failure = 25
	var/active = FALSE
	var/stat = 0
	var/code = 0
	var/frequency = 1400
	var/receiving = TRUE
	var/shell_capacity = SHELL_CAPACITY_SMALL
	var/circuit_type = /obj/item/circuit_component/concert_listener

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
		layer = 2.5
		update_icon()

	icon_state = "[base_icon_state][anchored ? null : "_unanchored"]"
	playsound(src, 'sound/items/deconstruct.ogg', 50, 1)

	return TRUE

/obj/structure/concertspeaker/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/shell, list(new circuit_type), shell_capacity)

/obj/structure/concertspeaker/proc/signal_callback()
	active = !active
	update_icon()

/obj/item/circuit_component/concert_listener
	display_name = "Concert Speaker Receiver"
	desc = "Получает название трека и воспроизводит его при сигнале запуска."

	var/datum/port/input/track_name_in
	var/datum/port/input/play
	var/datum/port/output/is_playing
	var/datum/port/output/started_playing
	var/datum/port/output/stopped_playing

	var/datum/track/selected_song
	var/sound/channel/song_channel
	var/playing = FALSE

/obj/item/circuit_component/concert_listener/populate_ports()
	track_name_in = add_input_port("Track Name", PORT_TYPE_STRING, trigger = PROC_REF(set_track))
	play = add_input_port("Play", PORT_TYPE_SIGNAL, trigger = PROC_REF(play_track))
	is_playing = add_output_port("Is Playing", PORT_TYPE_NUMBER)
	started_playing = add_output_port("Started Playing", PORT_TYPE_SIGNAL)
	stopped_playing = add_output_port("Stopped Playing", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/concert_listener/proc/set_track(datum/port/input/port, val)
	selected_song = get_track_by_name(val)

/obj/item/circuit_component/concert_listener/proc/get_track_by_name(trackname)
	for(var/datum/track/soundhand/T as anything in subtypesof(/datum/track/soundhand))
		var/datum/track/real = new T()
		if(real.song_name == trackname)
			return real
	return null

/obj/item/circuit_component/concert_listener/proc/play_track()
	if(!selected_song || playing)
		return

	// Играем трек
	playsound(src, selected_song.song_path, 50, TRUE)
	playing = TRUE
	is_playing.set_output(TRUE)
	started_playing.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/concert_listener/proc/stop_playback()
	playing = FALSE
	is_playing.set_output(FALSE)
	stopped_playing.set_output(COMPONENT_SIGNAL)
