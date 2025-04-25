//Проки на обработку при поднятом клинке
/datum/species/serpentid/spec_attack_hand(mob/living/carbon/human/owner, mob/living/carbon/human/target, datum/martial_art/attacker_style, modifiers)
	if(!istype(owner))
		return
	var/obj/item/bodypart/chest/serpentid/chest = owner.get_bodypart("chest")
	if(chest)
		if(!istype(owner))
			return

		if(!chest.blades_active)
			return

		CHECK_DNA_AND_SPECIES(owner)
		CHECK_DNA_AND_SPECIES(target)

		if(!istype(owner)) //sanity check for drones.
			return
		if(owner.mind)
			attacker_style = GET_ACTIVE_MARTIAL_ART(owner)
		if((owner != target) && target.check_block(owner, 0, owner.name, attack_type = UNARMED_ATTACK))
			log_combat(owner, target, "attempted to touch")
			target.visible_message(span_warning("[owner] attempts to touch [target]!"), \
							span_danger("[owner] attempts to touch you!"), span_hear("You hear a swoosh!"), COMBAT_MESSAGE_RANGE, owner)
			to_chat(owner, span_warning("You attempt to touch [target]!"))
			return

		SEND_SIGNAL(owner, COMSIG_MOB_ATTACK_HAND, owner, target, attacker_style)


		if(chest.owner.invisibility != INVISIBILITY_OBSERVER)
			var/obj/item/organ/liver/serpentid/liver= owner.get_organ_by_type(/obj/item/organ/liver/serpentid)
			liver.reset_visibility()

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
			var/obj/item/bodypart/chest/serpentid/chest = H.get_bodypart("chest")
			if(chest && !chest.blades_active)
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
	tool_behaviour = TOOL_CROWBAR

/obj/item/kitchen/knife/combat/serpentblade/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/double_attack)
	ADD_TRAIT(src, TRAIT_NODROP, HAND_REPLACEMENT_TRAIT)

/obj/item/kitchen/knife/combat/serpentblade/attack(mob/living/M, mob/living/user, def_zone)
	. = ..()
	var/mob/living/carbon/human/H = user
	if(H.invisibility == INVISIBILITY_MAXIMUM || H.alpha != 255)
		var/obj/item/organ/liver/serpentid/liver= H.get_organ_by_type(/obj/item/organ/liver/serpentid)
		liver.reset_visibility()
		liver.switch_mode(force_off = TRUE)
