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
	var/obj/item/circuit_component/concert_master/master_component

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
	AddComponent(/datum/component/shell, list(), shell_capacity)

/obj/machinery/jukebox/concertspeaker/activate_music()
	. = ..()
	SEND_SIGNAL(src, COMSIG_INSTRUMENT_START, music_player.selection)

/obj/machinery/jukebox/concertspeaker/stop_music()
	. = ..()
	SEND_SIGNAL(src, COMSIG_INSTRUMENT_END, src)












/datum/jukebox/concertspeaker
    // немного гистерезиса, чтобы якорь не щёлкал на границе
    var/list/last_anchor_by_mob = list() // mob->turf
    var/list/last_d2_by_mob     = list() // mob->num
    var/list/last_switch_time   = list() // mob->time
    var/const/ANCHOR_MIN_SWITCH_DS = 5
    var/const/ANCHOR_MARGIN_D2     = 1

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

/datum/jukebox/concertspeaker/proc/get_anchor_turfs()
	var/list/turfs = list()
	var/obj/machinery/jukebox/concertspeaker/machine = parent

	if(istype(machine) && machine.master_component)
		for(var/obj/item/circuit_component/concert_listener/L in machine.master_component.pult.takers)
			// берём только реально включённые колонки
			if(!L.playing) continue
			var/obj/item/integrated_circuit/C = L.parent
			var/atom/movable/sh = C?.shell
			if(!sh) continue

			if(istype(sh, /obj/structure/concertspeaker))
				var/obj/structure/concertspeaker/S = sh
				if(!S.anchored)
					continue

			var/turf/T = get_turf(sh)
			if(T) turfs += T

	// запасной якорь — сам контроллер
	var/turf/self_t = get_turf(parent)
	if(self_t) turfs += self_t

	return turfs

/datum/jukebox/concertspeaker/proc/pick_anchor_for(mob/listener)
    var/turf/L = get_turf(listener)
    if(!L) return get_turf(parent)

    var/list/anchors = get_anchor_turfs()
    var/turf/best = null
    var/best_d2 = 1.0e30

    for(var/turf/A as anything in anchors)
        if(!A || A.z != L.z) continue
        var/dx = A.x - L.x
        var/dy = A.y - L.y
        var/d2 = dx*dx + dy*dy
        if(d2 < best_d2)
            best_d2 = d2
            best = A

    if(!best) return get_turf(parent)

    // гистерезис
    var/turf/prev = last_anchor_by_mob[listener]
    var/prev_d2 = last_d2_by_mob[listener]
    var/last_sw = last_switch_time[listener] || 0
    if(prev && prev.z == L.z && !isnull(prev_d2))
        if( (best_d2 + ANCHOR_MARGIN_D2) >= prev_d2 && (world.time - last_sw) < ANCHOR_MIN_SWITCH_DS )
            return prev

    last_anchor_by_mob[listener] = best
    last_d2_by_mob[listener]     = best_d2
    last_switch_time[listener]   = world.time
    return best

/// Переопределяем позиционирование — ставим XYZ относительно ближайшего якоря
/datum/jukebox/concertspeaker/update_listener(mob/listener)
    if(isnull(active_song_sound))
        ..()
        return

    active_song_sound.status = listeners[listener] || NONE

    var/turf/sound_turf = pick_anchor_for(listener)
    var/turf/listener_turf = get_turf(listener)

    if(isnull(sound_turf) || isnull(listener_turf))
        active_song_sound.x = 0
        active_song_sound.z = 0

    else if(sound_turf.z != listener_turf.z)
        listeners[listener] |= SOUND_MUTE

    else
        var/new_x = sound_turf.x - listener_turf.x
        var/new_z = sound_turf.y - listener_turf.y

        if((abs(new_x) > x_cutoff || abs(new_z) > z_cutoff))
            listeners[listener] |= SOUND_MUTE
        else if(listeners[listener] & SOUND_MUTE)
            unmute_listener(listener, MUTE_RANGE)

        active_song_sound.x = new_x
        active_song_sound.z = new_z

        var/pref_volume = listener.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_jukebox)
        if(!pref_volume)
            listeners[listener] |= SOUND_MUTE
        else
            unmute_listener(listener, MUTE_PREF)
            active_song_sound.volume = volume * (pref_volume/100)

    SEND_SOUND(listener, active_song_sound)














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
		// Разрешаем вставить только «свой» пульт
		if(I != pult)
			to_chat(user, span_warning("Этот пульт не подходит к данному контроллеру."))
			return TRUE
		I.forceMove(src)
		to_chat(user, span_notice("Пульт вставлен в контроллер."))
		return TRUE
	return ..()

/obj/item/circuit_component/concert_master/register_shell(atom/movable/shell)
	if(!pult)
		return ..()

	. = ..()
	if(istype(shell, /obj/machinery/jukebox/concertspeaker))
		linked_jukebox = shell
		linked_jukebox.master_component = src
		RegisterSignal(linked_jukebox, COMSIG_INSTRUMENT_START, PROC_REF(on_song_start))
		RegisterSignal(linked_jukebox, COMSIG_INSTRUMENT_END,   PROC_REF(on_song_end))

/obj/item/circuit_component/concert_master/unregister_shell(atom/movable/shell)
	if(linked_jukebox)
		UnregisterSignal(linked_jukebox, list(COMSIG_INSTRUMENT_START, COMSIG_INSTRUMENT_END))
		linked_jukebox.master_component = null
	linked_jukebox = null
	return ..()

/obj/item/circuit_component/concert_master/proc/on_song_start(datum/source, datum/track/starting_song)
	SIGNAL_HANDLER
	if(!starting_song)
		return
	track_name_out.set_output(starting_song.song_name)
	is_playing.set_output(TRUE)
	started_playing.set_output(COMPONENT_SIGNAL)

	for(var/obj/item/circuit_component/concert_listener/L in pult.takers)
		//L.selected_song = starting_song
		L.play_track()

/obj/item/circuit_component/concert_master/proc/on_song_end()
	SIGNAL_HANDLER
	track_name_out.set_output("")
	is_playing.set_output(FALSE)
	stopped_playing.set_output(COMPONENT_SIGNAL)

	for(var/obj/item/circuit_component/concert_listener/L in pult.takers)
		//L.selected_song = null
		L.stop_playback()








/obj/item/concert_pult
	name = "Concert Pult"
	desc = "Пульт линковки концертных устройств."
	icon = 'icons/obj/devices/remote.dmi'
	icon_state = "shuttleremote"

/obj/item/concert_pult
    // Было: var/list/taker_refs // weakrefs
    // Станет: нормальная хеш-таблица сильных ссылок
    var/list/obj/item/circuit_component/concert_listener/takers

/obj/item/concert_pult/Initialize(mapload)
    . = ..()
    takers = list()

// — вспомогательные —
/obj/item/concert_pult/proc/add_taker(obj/item/circuit_component/concert_listener/L)
	if(!L || takers[L])
		return
	takers += L

/obj/item/concert_pult/proc/remove_taker(obj/item/circuit_component/concert_listener/L)
	if(!L || !takers[L])
		return
	takers -= L

/obj/item/concert_pult/proc/on_component_removed(datum/source, obj/item/circuit_component/removed)
	SIGNAL_HANDLER
	if(istype(removed, /obj/item/circuit_component/concert_listener))
		remove_taker(removed)

/obj/item/concert_pult/proc/find_linked_listener_in_circuit(obj/item/integrated_circuit/circ)
    for(var/obj/item/circuit_component/concert_listener/L in circ.attached_components)
        return L
    return null

/obj/item/concert_pult/proc/try_toggle_on(atom/target, mob/user)
    var/obj/item/integrated_circuit/circ = find_circuit(target)
    if(!circ)
        to_chat(user, span_warning("Здесь нет интегральной схемы."))
        return

    var/obj/item/circuit_component/concert_listener/existing = find_linked_listener_in_circuit(circ)
    if(existing)
        circ.remove_component(existing)
        remove_taker(existing)
        qdel(existing)
        to_chat(user, span_notice("Отвязано. Всего: [length(takers)]."))
        return

    if(length(takers) >= 16)
        to_chat(user, span_warning("Достигнут предел связей."))
        return

    var/obj/item/circuit_component/concert_listener/L = new
    circ.add_component(L)
    add_taker(L)
    to_chat(user, span_notice("Привязано. Всего: [length(takers)]."))

/obj/item/concert_pult/proc/find_circuit(atom/A)
	if(istype(A, /obj/item/integrated_circuit)) return A
	if(ismob(A) || istype(A, /obj/item) || istype(A, /obj/structure))
		for(var/obj/item/integrated_circuit/C in A.contents)
			return C
	return null

/obj/item/integrated_circuit/attackby(obj/item/I, mob/user, params)
    if(istype(I, /obj/item/concert_pult))
        var/obj/item/concert_pult/P = I
        P.try_toggle_on(src, user)
        return TRUE
    return ..()

/obj/item/circuitboard/machine/concert_controller
	name = "Circuit Board (Concert Controller)"
	desc = "Плата концертного контроллера."
	build_path = /obj/machinery/jukebox/concertspeaker
	req_components = list(
		/obj/item/stack/sheet/glass = 1,
		/obj/item/stack/cable_coil  = 5,
		/obj/item/stack/sheet/plastic = 1
		)

/datum/supply_pack/concert_controller
	access = NONE
	group = "Imports"
	goody = TRUE
	cost = CARGO_CRATE_VALUE * 5
	crate_name = "Контейнер Установки Саундхенд"
	crate_type = /obj/structure/closet/crate
	discountable = SUPPLY_PACK_NOT_DISCOUNTABLE
	name = "Установка Саундхенд"
	desc = "Контейнер содержит плату для сборки концертной установки Саундхенд. Материалы в поставку не входят."
	contains = list(
		/obj/item/circuitboard/machine/concert_controller,
		/obj/item/circuit_component/concert_master
		)
