#define SHREEK_EAR_DAMAGE_CLOSE 40
#define SHREEK_EAR_DAMAGE_FAR 20
#define SHREEK_GLASS_DAMAGE_BASE 110
#define SHREEK_GLASS_DAMAGE_FALLOFF 15
#define SHREEK_LIGHT_BREAK_CHANCE_BASE 100
#define SHREEK_LIGHT_BREAK_CHANCE_FALLOFF 15
#define SHREEK_LIGHT_BREAK_CHANCE_MIN 20

// MARK: Effects
/obj/effect/temp_visual/circle_wave/shadow_shreek_wave
	color = "#9fd7ff"
	max_alpha = 220
	duration = 0.5 SECONDS
	amount_to_scale = 5

// MARK: Ability
/datum/action/cooldown/shadowling/shreek
	name = "Крик"
	desc = "Ударная волна тьмы вокруг: рядом швыряет и оглушает, до 5 тайлов дезориентирует. Бьёт стёкла и лампы."
	button_icon_state = "shadow_screech"
	check_flags = AB_CHECK_CONSCIOUS
	cooldown_time = 40 SECONDS
	// Shadowling related
	min_req = 1
	max_req = 20
	required_thralls = 40
	var/knock_radius = 2
	var/disorient_radius = 10
	var/static/sfx_activate = 'modular_bandastation/antagonists/sound/shadowlings/abilities/shreek.ogg'

/datum/action/cooldown/shadowling/shreek/DoEffect(mob/living/carbon/human/H, atom/_)
	playsound(get_turf(H), sfx_activate, 70, TRUE)
	new /obj/effect/temp_visual/circle_wave/shadow_shreek_wave(get_turf(H))
	H.visible_message(
		span_boldwarning("[H] издаёт пронзительный нечеловеческий крик!"),
		span_userdanger("Вы издаёте пронзительный крик, и тьма рвётся наружу!")
	)
	var/datum/team/shadow_hive/hive = get_shadow_hive()

	var/list_disorient = range(disorient_radius, H)
	var/list_knock = range(knock_radius, H)
	for(var/mob/living/L in list_disorient)
		if(L == H)
			continue
		if(istype(L, /mob/living/carbon/human) && hive)
			if((L in hive.lings) || (L in hive.thralls))
				continue
		var/dist = get_dist(H, L)
		if(dist <= knock_radius)
			L.adjustOrganLoss(ORGAN_SLOT_EARS, SHREEK_EAR_DAMAGE_CLOSE)
			L.soundbang_act(2, 10 SECONDS, 10)
			L.Knockdown(2 SECONDS)
			L.adjust_dizzy(4)
			knockback_away_from(H, L, 3)
		else
			L.adjustOrganLoss(ORGAN_SLOT_EARS, SHREEK_EAR_DAMAGE_FAR)
			L.soundbang_act(2, 5 SECONDS, 5)
			L.adjust_confusion(6 SECONDS)
			L.adjust_staggered(6 SECONDS)
			L.adjust_dizzy(3)

	for(var/obj/item/I in list_knock)
		if(!isturf(I.loc))
			continue
		if(I.anchored)
			continue
		throw_away_from(H, I, 3, 2)

	for(var/obj/structure/window/W in list_disorient)
		damage_glass_with_falloff(H, W)

	break_wall_lights_with_falloff(H)
	return TRUE

/datum/action/cooldown/shadowling/shreek/proc/damage_glass_with_falloff(mob/living/carbon/human/H, obj/structure/W)
	if(QDELETED(W))
		return
	var/d = clamp(get_dist(H, W), 1, disorient_radius)
	var/damage = max(10, SHREEK_GLASS_DAMAGE_BASE - SHREEK_GLASS_DAMAGE_FALLOFF * d)
	W.take_damage(damage, damage_type = BRUTE, damage_flag = MELEE, sound_effect = TRUE)

/datum/action/cooldown/shadowling/shreek/proc/knockback_away_from(mob/living/source, mob/living/target, range)
	if(!istype(target) || target.anchored)
		return
	var/dir = get_dir(source, target)
	if(!dir)
		dir = pick(NORTH, SOUTH, EAST, WEST)
	var/turf/end = get_turf(target)
	for(var/i in 1 to range)
		var/turf/next = get_step(end, dir)
		if(!next || next.density)
			break
		end = next
	target.throw_at(end, range, 2)

/datum/action/cooldown/shadowling/shreek/proc/throw_away_from(mob/living/source, atom/movable/AM, range, speed)
	if(!istype(AM) || AM.anchored)
		return
	var/dir = get_dir(source, AM)
	if(!dir)
		dir = pick(NORTH, SOUTH, EAST, WEST)
	var/turf/end = get_turf(AM)
	for(var/i in 1 to range)
		var/turf/next = get_step(end, dir)
		if(!next || next.density)
			break
		end = next
	AM.throw_at(end, range, speed)

/datum/action/cooldown/shadowling/shreek/proc/break_wall_lights_with_falloff(mob/living/carbon/human/H)
	for(var/obj/machinery/light/L in range(disorient_radius, H))
		var/d = clamp(get_dist(H, L), 1, disorient_radius)
		var/chance = clamp(SHREEK_LIGHT_BREAK_CHANCE_BASE - (SHREEK_LIGHT_BREAK_CHANCE_FALLOFF * d), SHREEK_LIGHT_BREAK_CHANCE_MIN, SHREEK_LIGHT_BREAK_CHANCE_BASE)
		if(prob(chance))
			L.break_light_tube()
