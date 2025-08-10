// Reasons for appling STATUS_MUTE to a mob's sound status
/// The mob is deaf
#define MUTE_DEAF (1<<0)
/// The mob has disabled jukeboxes in their preferences
#define MUTE_PREF (1<<1)
/// The mob is out of range of the jukebox
#define MUTE_RANGE (1<<2)

/datum/jukebox/concertspeaker
	var/list/last_anchor_by_mob = list() // mob->turf
	var/list/last_d2_by_mob     = list() // mob->num
	var/list/last_switch_time   = list() // mob->time
	var/const/ANCHOR_MIN_SWITCH_DS = 5
	var/const/ANCHOR_MARGIN_D2     = 1
	var/anchor_scan_timer_id

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
		for(var/obj/item/circuit_component/concert_listener/L in machine.master_component.remote.takers)
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

/datum/jukebox/concertspeaker/proc/register_near_anchor_mobs()
    var/list/anchors = get_anchor_turfs()
    if(!length(anchors))
        anchors += get_turf(parent)

    var/list/seen = list()
    for(var/turf/T as anything in anchors)
        if(!T) continue
        for(var/mob/M as anything in hearers(sound_range, T))
            if(seen[M]) continue
            seen[M] = TRUE
            if(!(M in listeners))
                register_listener(M)

/datum/jukebox/concertspeaker/start_music()
    ..()
    register_near_anchor_mobs()
    if(!anchor_scan_timer_id)
        anchor_scan_timer_id = addtimer(CALLBACK(src, PROC_REF(periodic_anchor_scan)), 2 SECONDS, TIMER_LOOP)

/datum/jukebox/concertspeaker/proc/periodic_anchor_scan()
    if(isnull(active_song_sound))
        if(anchor_scan_timer_id)
            deltimer(anchor_scan_timer_id)
            anchor_scan_timer_id = null
        return
    register_near_anchor_mobs()

/datum/jukebox/concertspeaker/Destroy()
    if(anchor_scan_timer_id)
        deltimer(anchor_scan_timer_id)
        anchor_scan_timer_id = null
    return ..()

/datum/jukebox/concertspeaker/unmute_listener(mob/listener, reason)
    reason = ~reason

    if((reason & MUTE_DEAF) && HAS_TRAIT(listener, TRAIT_DEAF))
        return FALSE

    var/pref_volume = listener.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_jukebox)
    if((reason & MUTE_PREF) && !pref_volume)
        return FALSE

    if(reason & MUTE_RANGE)
        var/turf/sound_turf = pick_anchor_for(listener)
        var/turf/listener_turf = get_turf(listener)
        if(isnull(sound_turf) || isnull(listener_turf))
            return FALSE
        if(sound_turf.z != listener_turf.z)
            return FALSE

        var/dx = sound_turf.x - listener_turf.x
        var/dy = sound_turf.y - listener_turf.y
        if(abs(dx) > x_cutoff || abs(dy) > z_cutoff)
            return FALSE

    listeners[listener] &= ~SOUND_MUTE
    return TRUE

#undef MUTE_DEAF
#undef MUTE_PREF
#undef MUTE_RANGE

/datum/track/soundhand/a1
	song_path = 'sound/music/soundhand/A1.ogg'
	song_name = "А1 Галактика (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a2
	song_path = 'sound/music/soundhand/A2.ogg'
	song_name = "А2 Умирай от любви (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a3
	song_path = 'sound/music/soundhand/A3.ogg'
	song_name = "А3 Тонкая нить"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a4
	song_path = 'sound/music/soundhand/A4.ogg'
	song_name = "А4 Кошмар (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a5
	song_path = 'sound/music/soundhand/A5.ogg'
	song_name = "А5 К мечте (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a6
	song_path = 'sound/music/soundhand/A6.ogg'
	song_name = "А6 Черный пес"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a7
	song_path = 'sound/music/soundhand/A7.ogg'
	song_name = "А7 Эйфория"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a8
	song_path = 'sound/music/soundhand/A8.ogg'
	song_name = "А8 Война (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a9
	song_path = 'sound/music/soundhand/A9.ogg'
	song_name = "А9 Занавес (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/a10
	song_path = 'sound/music/soundhand/A10.ogg'
	song_name = "А10 Беспорядок"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b1
	song_path = 'sound/music/soundhand/B1.ogg'
	song_name = "Б1 Вступление (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b2
	song_path = 'sound/music/soundhand/B2.ogg'
	song_name = "Б2 Деструктивный творец (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b3
	song_path = 'sound/music/soundhand/B3.ogg'
	song_name = "Б3 Конец"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b4
	song_path = 'sound/music/soundhand/B4.ogg'
	song_name = "Б4 Не Верю (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b5
	song_path = 'sound/music/soundhand/B5.ogg'
	song_name = "Б5 Передача (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b6
	song_path = 'sound/music/soundhand/B6.ogg'
	song_name = "Б6 Я буду таким как есть (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b7
	song_path = 'sound/music/soundhand/B7.ogg'
	song_name = "Б7 Угнетенный"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b8
	song_path = 'sound/music/soundhand/B8.ogg'
	song_name = "Б8 Пламя"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b9
	song_path = 'sound/music/soundhand/B9.ogg'
	song_name = "Б9 Завершение (Анумати)"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS

/datum/track/soundhand/b10
	song_path = 'sound/music/soundhand/B10.ogg'
	song_name = "Б10 Кадуцей"
	song_length = 5 MINUTES
	song_beat = 1 SECONDS
