/obj/machinery/jukebox/concertspeaker
	name = "\proper концертная установка"
	desc = "Концертная колонка, которая используется для воспроизведения концертной записи."
	icon = 'modular_bandastation/objects/icons/obj/machines/jukebox.dmi'
	icon_state = "concertspeaker_unanchored"
	base_icon_state = "concertspeaker"
	req_access = list()
	anchored = TRUE
	density = TRUE
	layer = 2.5
	resistance_flags = NONE
	max_integrity = 250
	integrity_failure = 25
	var/shell_capacity = SHELL_CAPACITY_SMALL
	var/circuit_type = /obj/item/circuit_component/concert_master

/obj/machinery/jukebox/concertspeaker/examine()
	. = ..()
	. += "<span class='notice'>Используйте гаечный ключ, чтобы разобрать для транспортировки и собрать для игры.</span>"

/obj/machinery/jukebox/concertspeaker/wrench_act()
	. = ..()
	icon_state = "[base_icon_state][anchored ? null : "_unanchored"]"

/obj/machinery/jukebox/concertspeaker/update_icon_state()
	. = ..()
	if(machine_stat & (BROKEN))
		icon_state = "[base_icon_state]_broken"
	else
		icon_state = "[base_icon_state][music_player.active_song_sound ? "_active" : null]"

/obj/machinery/jukebox/concertspeaker/Initialize(mapload)
	. = ..()
	music_player = new /datum/jukebox/concertspeaker(src)
	AddComponent(/datum/component/shell, list(new circuit_type), shell_capacity)

/obj/machinery/jukebox/concertspeaker/activate_music()
	. = ..()
	SEND_SIGNAL(src, COMSIG_INSTRUMENT_START, music_player.selection)

/obj/machinery/jukebox/concertspeaker/stop_music()
	. = ..()
	SEND_SIGNAL(src, COMSIG_INSTRUMENT_END, src)

/datum/jukebox/concertspeaker

/datum/jukebox/concertspeaker/load_songs_from_config()
	var/static/list/config_songs
	if(isnull(config_songs))
		config_songs = fill_songs_static_list()
	// returns a copy so it can mutate if desired.
	return config_songs.Copy()

/datum/jukebox/concertspeaker/proc/fill_songs_static_list()
	var/songs_list = list()
	for(var/datum/track/new_track as anything in subtypesof(/datum/track/soundhand))
		songs_list[new_track.song_name] = new new_track (new_track.song_name,new_track.song_path,new_track.song_length,new_track.song_beat)

	if(!length(songs_list))
		var/datum/track/default/default_track = new()
		songs_list[default_track.song_name] = default_track

	return songs_list

// Default track supplied for testing and also because it's a banger
/datum/track/default
	song_path = 'sound/music/lobby_music/title3.ogg'
	song_name = "Lobby Music - Title 3"
	song_length = 3 MINUTES + 52 SECONDS
	song_beat = 1 SECONDS

/obj/item/circuit_component/concert_master
	display_name = "Concert Master"
	desc = "Основная управляющая схема концертной установки. Получает текущий трек и рассылает его колонкам."

	var/datum/port/output/track_name_out
	var/datum/port/output/is_playing
	var/datum/port/output/started_playing
	var/datum/port/output/stopped_playing

	var/obj/machinery/jukebox/concertspeaker/linked_jukebox
	var/obj/item/concert_pult/pult

/obj/item/circuit_component/concert_master/populate_ports()
    track_name_out  = add_output_port("Track Name", PORT_TYPE_STRING)
    is_playing      = add_output_port("Is Playing", PORT_TYPE_NUMBER)
    started_playing = add_output_port("Started Playing", PORT_TYPE_SIGNAL)
    stopped_playing = add_output_port("Stopped Playing", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/concert_master/Initialize(mapload)
	. = ..()
	if(!pult)
		pult = new /obj/item/concert_pult(src)
	pult.forceMove(src)

/obj/item/circuit_component/concert_master/attack_self(mob/user)
	if(!pult)
		to_chat(user, span_warning("Пульт уже извлечён."))
		return
	if(!user.put_in_active_hand(pult))
		pult.forceMove(drop_location())
	to_chat(user, span_notice("Вы извлекли концертный пульт."))

/obj/item/circuit_component/concert_master/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/concert_pult))
		var/obj/item/concert_pult/P = I
		// Разрешаем вставить только «свой» пульт: тот, что был создан внутри мастера
		if(P != pult)
			to_chat(user, span_warning("Этот пульт не подходит к данному контроллеру."))
			return TRUE
		P.forceMove(src)
		to_chat(user, span_notice("Пульт вставлен в контроллер."))
		return TRUE
	return ..()

/obj/item/circuit_component/concert_master/register_shell(atom/movable/shell)
	if(!pult)
		return ..()

	. = ..()
	if(istype(shell, /obj/machinery/jukebox/concertspeaker))
		linked_jukebox = shell
		RegisterSignal(linked_jukebox, COMSIG_INSTRUMENT_START, PROC_REF(on_song_start))
		RegisterSignal(linked_jukebox, COMSIG_INSTRUMENT_END,   PROC_REF(on_song_end))

/obj/item/circuit_component/concert_master/unregister_shell(atom/movable/shell)
	if(linked_jukebox)
		UnregisterSignal(linked_jukebox, list(COMSIG_INSTRUMENT_START, COMSIG_INSTRUMENT_END))
	linked_jukebox = null
	return ..()

/obj/item/circuit_component/concert_master/proc/on_song_start(datum/source, datum/track/starting_song)
	SIGNAL_HANDLER
	if(!starting_song)
		return
	track_name_out.set_output(starting_song.song_name)
	is_playing.set_output(TRUE)
	started_playing.set_output(COMPONENT_SIGNAL)

	for(var/obj/item/circuit_component/concert_listener/L in get_takers())
		L.selected_song = starting_song
		L.play_track()

/obj/item/circuit_component/concert_master/proc/on_song_end()
	SIGNAL_HANDLER
	track_name_out.set_output("")
	is_playing.set_output(FALSE)
	stopped_playing.set_output(COMPONENT_SIGNAL)

	for(var/obj/item/circuit_component/concert_listener/L in get_takers())
		L.selected_song = null
		L.stop_playback()

/obj/item/circuit_component/concert_master/proc/get_takers()
	if(!pult)
		return list()
	return pult.get_live_takers()



/obj/item/concert_pult
	name = "Concert Pult"
	desc = "Пульт линковки концертных устройств."
	icon = 'icons/obj/devices/remote.dmi'
	icon_state = "shuttleremote"

	var/list/taker_refs // weakrefs на выданные листенеры

/obj/item/concert_pult/Initialize(mapload)
	. = ..()
	taker_refs = list()

// — вспомогательные —
/obj/item/concert_pult/proc/find_circuit(atom/A)
	if(istype(A, /obj/item/integrated_circuit)) return A
	if(ismob(A) || istype(A, /obj/item) || istype(A, /obj/structure))
		for(var/obj/item/integrated_circuit/C in A.contents)
			return C
	return null

/obj/item/concert_pult/proc/prune_refs()
	for(var/W in taker_refs.Copy())
		var/obj/item/circuit_component/concert_listener/L = W:resolve()
		if(!L || QDELETED(L))
			taker_refs -= W

/obj/item/concert_pult/proc/get_live_takers()
	prune_refs()
	var/list/live = list()
	for(var/W in taker_refs)
		var/obj/item/circuit_component/concert_listener/L = W:resolve()
		if(L) live += L
	return live

/obj/item/concert_pult/proc/find_linked_listener_in_circuit(obj/item/integrated_circuit/circ)
	for(var/obj/item/circuit_component/concert_listener/L in circ.attached_components)
		return L
	return null

// — основной тоггл —
/obj/item/concert_pult/proc/try_toggle_on(atom/target, mob/user)
	var/obj/item/integrated_circuit/circ = find_circuit(target)
	if(!circ)
		to_chat(user, span_warning("Здесь нет интегральной схемы."))
		return

	// toggle: если есть наш listener — удаляем, иначе ставим
	var/obj/item/circuit_component/concert_listener/existing = find_linked_listener_in_circuit(circ)
	if(existing)
		circ.remove_component(existing)
		qdel(existing)
		prune_refs()
		to_chat(user, span_notice("Отвязано. Всего: [length(get_live_takers())]."))
		return

	prune_refs()
	if(length(taker_refs) >= 16)
		to_chat(user, span_warning("Достигнут предел связей."))
		return

	var/obj/item/circuit_component/concert_listener/L = new
	circ.add_component(L)
	taker_refs += WEAKREF(L)
	to_chat(user, span_notice("Привязано. Всего: [length(taker_refs)]."))

/obj/item/integrated_circuit/attackby(obj/item/I, mob/user, params)
    if(istype(I, /obj/item/concert_pult))
        var/obj/item/concert_pult/P = I
        P.try_toggle_on(src, user)
        return TRUE
    return ..()
