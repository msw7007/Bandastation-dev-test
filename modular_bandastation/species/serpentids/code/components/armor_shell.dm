/*
===Модуль хитина (карапаса)
Цепляется на конечность (в идеале торс).area
Опреедляет возможности тела серпентида, которые зависят от общего состояния хитина всех конечностей
*/

#define CARAPACE_SURGERY_REPAIR_VALUE rand(1,10)
#define CARAPACE_MODIFIER_DAMAGE_SOLID_BURN 0.8
#define CARAPACE_MODIFIER_DAMAGE_BROKEN_BURN 1.3
#define CARAPACE_MODIFIER_DAMAGE_SOLID_BRUTE 0.6
#define CARAPACE_MODIFIER_DAMAGE_BROKEN_BRUTE 1.1

/datum/component/carapace_shell
	var/mob/living/carbon/human/H
	var/heal_cooldown = 0 SECONDS

/datum/component/carapace_shell/Initialize(mob/living/carbon/human/caller, heal_cooldown = 10 MINUTES)
	if(!istype(caller))
		return
	H = caller
	var/list/trait_list = list()
	var/list/wound_list = subtypesof(/datum/wound/carapace_damaged)
	for(var/datum/wound/carapace_damaged/check_wound in wound_list)
		trait_list += check_wound.wound_traits

	for(var/trait_macro in trait_list)
		ADD_TRAIT(H, trait_macro, "armor")

	update_damage_modifiers(H)

/datum/component/carapace_shell/RegisterWithParent()
	RegisterSignal(H, COMSIG_SURGERY_REPAIR, PROC_REF(surgery_carapace_shell_repair))
	RegisterSignal(H, COMSIG_CARAPACE_CHECK, PROC_REF(update_damage_modifiers))
	RegisterSignal(H, COMSIG_HAVE_CARAPACE, PROC_REF(check_have_carapace))

/datum/component/carapace_shell/UnregisterFromParent()
	UnregisterSignal(H, COMSIG_SURGERY_REPAIR)
	UnregisterSignal(H, COMSIG_CARAPACE_CHECK)
	UnregisterSignal(H, COMSIG_HAVE_CARAPACE)

/datum/component/carapace_shell/proc/check_have_carapace(carapace_holder)
	SIGNAL_HANDLER
	return . = TRUE

//Прок на запуск ремонта
/datum/component/carapace_shell/proc/surgery_carapace_shell_repair(carapace_holder)
	SIGNAL_HANDLER
	var/datum/wound/carapace_damaged/carapace_wound = check_and_get_wound(carapace_holder)
	if(!(carapace_wound))
		return

	carapace_wound.carapace_damage_value -= CARAPACE_SURGERY_REPAIR_VALUE

/datum/component/carapace_shell/proc/check_and_get_wound(carapace_holder)
	var/datum/wound/carapace_damaged/carapace_wound
	var/mob/living/carbon/human/checked = carapace_holder
	var/obj/item/bodypart/limb = checked.get_bodypart("chest")
	for(var/datum/wound/carapace_damaged/check_wound in limb.wounds)
		if(ispath(check_wound, /datum/wound/carapace_damaged))
			carapace_wound = check_wound

	return carapace_wound

/datum/component/carapace_shell/proc/update_damage_modifiers(carapace_holder)
	SIGNAL_HANDLER
	var/datum/wound/carapace_damaged/severe/carapace_wound = check_and_get_wound(carapace_holder)
	var/mob/living/carbon/body_owner = carapace_holder

	for(var/obj/item/bodypart/check_part in body_owner.bodyparts)
		if(check_part.encased == CARAPACE_ENCASE_WORD)
			check_part.burn_modifier = carapace_wound ? CARAPACE_MODIFIER_DAMAGE_BROKEN_BURN : CARAPACE_MODIFIER_DAMAGE_SOLID_BURN
			check_part.brute_modifier = carapace_wound ? CARAPACE_MODIFIER_DAMAGE_BROKEN_BRUTE : CARAPACE_MODIFIER_DAMAGE_SOLID_BRUTE
