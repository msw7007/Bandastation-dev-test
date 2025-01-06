//===Клинки через грудной имплант===
/obj/item/organ/cyberimp/serpentid_blades
	name = "neuronodule of blades"
	desc = "control organ of upper blades"
	icon_state = "chest_implant"
	slot = ORGAN_SLOT_MONSTER_CORE
	zone = BODY_ZONE_CHEST
	actions_types = list(/datum/action/item_action/organ_action/toggle/switch_blades)
	contents = newlist(/obj/item/kitchen/knife/combat/serpentblade,/obj/item/kitchen/knife/combat/serpentblade)
	useable = FALSE
	organ_flags = ORGAN_ORGANIC | ORGAN_EDIBLE | ORGAN_VIRGIN
	var/obj/item/holder_l = null
	var/icon_file = 'modular_bandastation/species/serpentids/icons/r_serpentid.dmi'
	var/new_icon_state = "blades_0"
	var/mutable_appearance/old_overlay
	var/mutable_appearance/new_overlay
	var/overlay_color
	var/blades_active = FALSE
	var/activation_in_progress = FALSE
	/// Sound played when extending
	var/extend_sound = 'sound/vehicles/mecha/mechmove03.ogg'
	/// Sound played when retracting
	var/retract_sound = 'sound/vehicles/mecha/mechmove03.ogg'


/datum/action/item_action/organ_action/toggle/switch_blades
	name = "Switch Threat Mode"
	desc = "Switch your stance to show other your intentions"
	button_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	button_icon_state = "serpentid_hand_act"

/obj/item/organ/cyberimp/serpentid_blades/ui_action_click()
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

/obj/item/organ/cyberimp/serpentid_blades/update_overlays()
	. = .. ()
	if(old_overlay)
		owner.overlays -= old_overlay
	if(owner)
		var/icon/blades_icon = new/icon("icon" = icon_file, "icon_state" = new_icon_state)
		var/obj/item/bodypart/chest/torso = owner.get_bodypart("chest")
		var/body_color = torso.color
		blades_icon.Blend(body_color, ICON_ADD)
		new_overlay = mutable_appearance(blades_icon)
		old_overlay = new_overlay
		owner.overlays += new_overlay

/obj/item/organ/cyberimp/serpentid_blades/proc/Extend()
	if(!(contents[1] in src))
		return
	if(organ_flags & ORGAN_FAILING)
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
	new_icon_state = "blades_1"
	update_icon(UPDATE_OVERLAYS)
	return TRUE

/obj/item/organ/cyberimp/serpentid_blades/proc/Retract()
	if(organ_flags & ORGAN_FAILING)
		return

	holder_l.forceMove(src)
	holder_l = null
	blades_active = FALSE
	playsound(get_turf(owner), retract_sound, 50, TRUE)
	new_icon_state = "blades_0"
	update_icon(UPDATE_OVERLAYS)

//Проки на обработку при поднятом клинке
/datum/species/serpentid/spec_attack_hand(mob/living/carbon/human/owner, mob/living/carbon/human/target, datum/martial_art/attacker_style, modifiers)
	if(!istype(owner))
		return
	var/obj/item/organ/cyberimp/serpentid_blades/blades_implant = owner.get_organ_by_type(/obj/item/organ/cyberimp/serpentid_blades)
	var/obj/item/bodypart/chest/serpentid/chest = owner.get_bodypart("chest")
	if(blades_implant)
		if(!istype(owner))
			return

		if(!blades_implant.blades_active)
			return

		CHECK_DNA_AND_SPECIES(owner)
		CHECK_DNA_AND_SPECIES(target)

		if(!istype(owner)) //sanity check for drones.
			return
		if(owner.mind)
			attacker_style = owner.mind.martial_art
		if((owner != target) && target.check_block(owner, 0, owner.name, attack_type = UNARMED_ATTACK))
			log_combat(owner, target, "attempted to touch")
			target.visible_message(span_warning("[owner] attempts to touch [target]!"), \
							span_danger("[owner] attempts to touch you!"), span_hear("You hear a swoosh!"), COMBAT_MESSAGE_RANGE, owner)
			to_chat(owner, span_warning("You attempt to touch [target]!"))
			return

		SEND_SIGNAL(owner, COMSIG_MOB_ATTACK_HAND, owner, target, attacker_style)

		if(blades_implant.owner.invisibility != INVISIBILITY_OBSERVER)
			chest.reset_visibility()

		if(LAZYACCESS(modifiers, RIGHT_CLICK))
			blades_disarm(owner, target, attacker_style)
			return // dont attack after
		if(owner.combat_mode)
			blades_harm(owner, target, attacker_style)
		else
			help(owner, target, attacker_style)
	else
		. = ..()

//Модификация усиленного граба
/mob/living/grab(mob/living/target)
	if(!istype(target))
		return FALSE
	if(SEND_SIGNAL(src, COMSIG_LIVING_GRAB, target) & (COMPONENT_CANCEL_ATTACK_CHAIN|COMPONENT_SKIP_ATTACK))
		return FALSE
	if(target.check_block(src, 0, "[src]'s grab", UNARMED_ATTACK))
		return FALSE
	if(istype(src, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = src
		if(istype(H.dna.species, /datum/species/serpentid))
			var/obj/item/organ/cyberimp/serpentid_blades/blades_implant = H.get_organ_by_type(/obj/item/organ/cyberimp/serpentid_blades)
			if(blades_implant && !blades_implant.blades_active)
				H.blades_grab(target)
	else
		. = ..()

/mob/living/carbon/human/proc/blades_grab(mob/living/carbon/human/target, datum/martial_art/attacker_style)
	grab(target)
	if(HAS_TRAIT(src, TRAIT_PACIFISM) && !attacker_style?.pacifist_style)
		to_chat(src, span_warning("You don't want to harm [target]!"))
		setGrabState(GRAB_AGGRESSIVE)
		return

	setGrabState(GRAB_NECK)

//Модификация усиленного дизарма
/datum/species/serpentid/proc/blades_disarm(mob/living/carbon/human/user, mob/living/carbon/human/target, datum/martial_art/attacker_style)
	if(user.body_position != STANDING_UP)
		return FALSE
	if(user == target)
		return FALSE
	if(user.loc == target.loc)
		return FALSE
	//Двойной шов
	user.disarm(target)
	user.disarm(target)

//Модификация агрессивного поведения
/datum/species/serpentid/proc/blades_harm(mob/living/carbon/human/user, mob/living/carbon/human/target, datum/martial_art/attacker_style)
	//Переключить на руку с оружием
	var/obj/item/is_blade = user.get_active_held_item()
	if(!istype(is_blade, /obj/item/kitchen/knife/combat/serpentblade))
		user.swap_hand()
	harm(user, target, attacker_style)

// ============ Органы внешние ============
/obj/item/kitchen/knife/combat/serpentblade
	name = "serpentid mantis blade"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "left_blade"
	lefthand_file = null
	righthand_file = null
	desc = "Biological melee weapon. Sharp and durable. It can cut off some heads, or maybe not..."
	force = 20
	armour_penetration = 30
	tool_behaviour = TOOL_SAW

/obj/item/kitchen/knife/combat/serpentblade/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/double_attack)
	ADD_TRAIT(src, TRAIT_NODROP, HAND_REPLACEMENT_TRAIT)
