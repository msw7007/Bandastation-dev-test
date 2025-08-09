/// The mob has disabled jukeboxes in their preferences
#define MUTE_PREF (1<<1)
/// The mob is out of range of the jukebox
#define MUTE_RANGE (1<<2)

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

#undef MUTE_PREF
#undef MUTE_RANGE
