// MARK: Status effects
/datum/status_effect/shadow/stealth
	id = "shadowling_stealth"
	alert_type = null
	status_type = STATUS_EFFECT_UNIQUE
	tick_interval = 1 SECONDS
	duration = -1
	var/time_left = 0
	var/cancel_on_bright = TRUE

/datum/status_effect/shadow/stealth/on_apply()
	. = ..()
	if(!owner)
		return

	for(var/datum/action/cooldown/shadowling/stealth/A in owner.actions)
		A.apply_button_overlay()

	owner.alpha = 80
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(_break_on_move))
	RegisterSignal(owner, COMSIG_ATOM_ATTACKBY, PROC_REF(_break_on_damage))
	RegisterSignal(owner, COMSIG_ATOM_ATTACKBY_SECONDARY, PROC_REF(_break_on_damage))
	RegisterSignal(owner, COMSIG_MOB_SAY, PROC_REF(_break_on_action))

/datum/status_effect/shadow/stealth/on_remove()
	. = ..()
	if(!owner)
		return

	for(var/datum/action/cooldown/shadowling/stealth/A in owner.actions)
		A.apply_button_overlay()

	owner.alpha = initial(owner.alpha)
	owner.invisibility = initial(owner.invisibility)
	UnregisterSignal(owner, list(
		COMSIG_MOVABLE_MOVED,
		COMSIG_ATOM_ATTACKBY,
		COMSIG_ATOM_ATTACKBY_SECONDARY,
		COMSIG_MOB_SAY,
	))

/datum/status_effect/shadow/stealth/tick(seconds_between_ticks)
	. = ..()
	if(!owner)
		return
	if(cancel_on_bright)
		var/turf/T = get_turf(owner)
		if(!T)
			return
		if(T.get_lumcount() >= SHADOWLING_DIM_THRESHOLD)
			owner.remove_status_effect(type)

/datum/status_effect/shadow/stealth/proc/_break_on_move(datum/source)
	SIGNAL_HANDLER
	owner.remove_status_effect(type)

/datum/status_effect/shadow/stealth/proc/_break_on_damage(datum/source, amount, ...)
	SIGNAL_HANDLER
	if(amount > 0)
		owner.remove_status_effect(type)

/datum/status_effect/shadow/stealth/proc/_break_on_action(datum/source, ...)
	SIGNAL_HANDLER
	owner.remove_status_effect(type)

// MARK: Ability
/datum/action/cooldown/shadowling/stealth
	name = "Скрытность"
	desc = "Слиться с тенью. Снимается при движении, уроне или действиях."
	button_icon_state = "shadow_stealth"
	cooldown_time = 6 SECONDS

/datum/action/cooldown/shadowling/stealth/is_action_active(atom/movable/screen/movable/action_button/_btn)
	return owner?.has_status_effect(/datum/status_effect/shadow/stealth) == TRUE

/datum/action/cooldown/shadowling/stealth/DoEffect(mob/living/carbon/human/H, atom/_)
	apply_button_overlay()
	if(H.has_status_effect(/datum/status_effect/shadow/stealth))
		H.remove_status_effect(/datum/status_effect/shadow/stealth)
		to_chat(H, span_notice("Вы выходите из тени."))
		return TRUE

	if(is_dark(H))
		H.apply_status_effect(/datum/status_effect/shadow/stealth)
		to_chat(H, span_notice("Вы растворяетесь в тенях."))
		return TRUE

	H.balloon_alert(H, "слишком светло")
	return FALSE
