/obj/item/bodypart/chest/serpentid
	icon_greyscale = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	icon_state = "serpentid_chest"
	limb_id = SPECIES_SERPENTID
	is_dimorphic = TRUE
	wing_types = list(/obj/item/organ/wings/functional/dragon)
	var/min_broken_damage = 40
	//icon =
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_KIDNEYS
	var/obj/item/holder_l = null
	var/radial_action_state = "serpentid_stealth"
	var/radial_action_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	var/blades_active = FALSE
	var/activation_in_progress = FALSE
	/// Sound played when extending
	var/extend_sound = 'sound/vehicles/mecha/mechmove03.ogg'
	/// Sound played when retracting
	var/retract_sound = 'sound/vehicles/mecha/mechmove03.ogg'

/obj/item/bodypart/chest/serpentid/get_butt_sprite()
	return BUTT_SPRITE_SERPENTID

/obj/item/bodypart/chest/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/carapace, FALSE, min_broken_damage)
	AddComponent(/datum/component/carapace_shell, owner)

/datum/action/item_action/organ_action/toggle/switch_blades
	name = "Switch Threat Mode"
	desc = "Switch your stance to show other your intentions"
	button_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	button_icon_state = "serpentid_hand_act"

/obj/item/bodypart/chest/serpentid/ui_action_click()
	if(activation_in_progress)
		return
	if(!holder_l && !length(contents))
		to_chat(owner, span_warning("Вы не можете поднять клинки"))
		return
	var/extended = holder_l && !(holder_l in src)
	if(extended)
		if(!activation_in_progress)
			activation_in_progress = TRUE
			Retract()
	else if(!activation_in_progress)
		activation_in_progress = TRUE
		if(do_after(owner, 2 SECONDS, FALSE, owner))
			holder_l = null
			Extend()
	activation_in_progress = FALSE

/obj/item/bodypart/chest/serpentid/update_overlays()
	. = .. ()
	if(owner)
		var/icon/blades_icon = new/icon("icon" = icon, "icon_state" = icon_state)
		var/obj/item/bodypart/chest/torso = owner.get_bodypart("chest")
		var/body_color = torso.color
		blades_icon.Blend(body_color, ICON_ADD)

/obj/item/bodypart/chest/serpentid/proc/Extend()
	if(!(contents[1] in src))
		return

	holder_l = contents[1]
	holder_l.resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	holder_l.slot_flags = null
	holder_l.w_class = WEIGHT_CLASS_HUGE

	for(var/arm_slot in list(BODY_ZONE_L_ARM,BODY_ZONE_R_ARM))
		var/obj/item/arm_item = owner.get_item_by_slot(arm_slot)

		if(arm_item)
			if(istype(arm_item, /obj/item/offhand))
				var/obj/item/offhand_arm_item = owner.get_active_hand()
				to_chat(owner, "<span class='warning'>Your hands are too encumbered wielding [offhand_arm_item] to deploy [src]!</span>")
				return
			else if(!owner.dropItemToGround(arm_item))
				to_chat(owner, "<span class='warning'>Your [arm_item] interferes with [src]!</span>")
				return
			else
				to_chat(owner, "<span class='notice'>You drop [arm_item] to activate [src]!</span>")

	if(!owner.put_in_l_hand(holder_l))
		return

	blades_active = TRUE
	playsound(get_turf(owner), extend_sound, 50, TRUE)
	icon_state = "blades_1"
	update_icon(UPDATE_OVERLAYS)
	return TRUE

/obj/item/bodypart/chest/serpentid/proc/Retract()
	holder_l.forceMove(src)
	holder_l = null
	blades_active = FALSE
	playsound(get_turf(owner), retract_sound, 50, TRUE)
	icon_state = "blades_0"
	update_icon(UPDATE_OVERLAYS)
