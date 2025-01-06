/*
=== Перенос ящиков ===
Компонент для переноса ящиков карго на мобах. Срабатывает в случае граб-интента, драг-энд-дропа ящика на модель
*/

/datum/component/gadom_cargo
	var/mob/living/carbon/human/carrier = null
	var/atom/movable/load /// what we're transporting

/datum/component/gadom_cargo/New()
	..()
	carrier = parent

/datum/component/gadom_cargo/RegisterWithParent()
	RegisterSignal(parent, COMSIG_GADOM_LOAD, PROC_REF(try_load_cargo))
	RegisterSignal(parent, COMSIG_GADOM_UNLOAD, PROC_REF(try_unload_cargo))
	RegisterSignal(parent, COMSIG_GADOM_CAN_GRAB, PROC_REF(block_operation))

/datum/component/gadom_cargo/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_GADOM_LOAD)
	UnregisterSignal(parent, COMSIG_GADOM_UNLOAD)
	UnregisterSignal(parent, COMSIG_GADOM_CAN_GRAB)

/datum/component/gadom_cargo/proc/block_operation()
	SIGNAL_HANDLER
	//Понять надо ли брать учитывать этот сигнал при грабе ящиков?
	//return carrier.a_intent == "grab" ? GADOM_CAN_GRAB : FALSE

/datum/component/gadom_cargo/proc/try_load_cargo(datum/component_holder, mob/user, atom/movable/AM)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(pre_load), component_holder, user, AM)

/datum/component/gadom_cargo/proc/pre_load(datum/component_holder, mob/user, mob/AM)
	if(!isliving(user) || user.incapacitated || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || get_dist(user, AM) > 1)
		return

	if(!istype(AM) || isdead(AM) || iseyemob(AM) || istype(AM, /obj/effect/dummy/phased_mob))
		return

	if(!do_after(user, GADOM_BASIC_LOAD_TIMER, FALSE, AM))
		return

	load(AM)


/datum/component/gadom_cargo/proc/load(atom/movable/movable_atom)
	if(load || movable_atom.anchored)
		return

	if(!isturf(movable_atom.loc)) //To prevent the loading from stuff from someone's inventory or screen icons.
		return

	if(isobj(movable_atom))
		if(movable_atom.has_buckled_mobs() || (locate(/mob) in movable_atom)) //can't load non crates objects with mobs buckled to it or inside it.

			return

		if(istype(movable_atom, /obj/structure/closet/crate))
			var/obj/structure/closet/crate/crate = movable_atom
			crate.close() //make sure it's closed

		movable_atom.forceMove(src)

	load = movable_atom
	carrier.update_appearance()

	carrier.update_icon()
	carrier.throw_alert("serpentid_holding", /atom/movable/screen/alert/carrying)

/datum/component/gadom_cargo/proc/try_unload_cargo()
	SIGNAL_HANDLER
	var/dirn = carrier.dir
	if(!load)
		return

	if(QDELETED(load))
		if(load) //if our thing was qdel'd, there's likely a leftover reference. just clear it and remove the overlay. we'll let the bot keep moving around to prevent it abruptly stopping somewhere.
			load = null
			carrier.update_appearance()
		return

	var/atom/movable/cached_load = load //cache the load since unbuckling mobs clears the var.

	if(load) //don't have to do any of this for mobs.
		load.forceMove(carrier.loc)
		load.pixel_y = initial(load.pixel_y)
		load.layer = initial(load.layer)
		SET_PLANE_EXPLICIT(load, initial(load.plane), carrier)
		load = null

	if(dirn) //move the thing to the delivery point.
		cached_load.Move(get_step(carrier.loc, dirn), dirn)

	carrier.update_appearance()
	carrier.clear_alert("serpentid_holding")
