/*
===Модуль хитина (карапаса)
Цепляется на конечность (в идеале торс).area
Опреедляет возможности тела серпентида, которые зависят от общего состояния хитина всех конечностей
*/

#define CARAPACE_SHELL_ARMORED_BRUTE 0.6
#define CARAPACE_SHELL_ARMORED_BURN 0.8
#define CARAPACE_SHELL_BROKEN_BRUTE 1
#define CARAPACE_SHELL_BROKEN_BURN 1

/datum/component/carapace_shell
	var/mob/living/carbon/human/H
	var/state_1_threshold
	var/state_2_threshold
	var/state_3_threshold
	var/armored_cold_threshold
	var/armored_heat_threshold
	var/armored_temp_progression
	var/self_repair_cooldown
	var/broken_stage = 0
	var/last_time_action = 0

/datum/component/carapace_shell/Initialize(mob/living/carbon/human/caller, treshold_1 = 30, treshold_2 = 60, treshold_3 = 90, threshold_cold = 0, threshold_heat = 400, temp_progression = 30, heal_cooldown = 10 MINUTES)
	if(!istype(caller))
		return
	H = caller

	state_1_threshold = treshold_1
	state_2_threshold = treshold_2
	state_3_threshold = treshold_3
	armored_cold_threshold = threshold_cold
	armored_heat_threshold = threshold_heat
	armored_temp_progression = temp_progression
	self_repair_cooldown = heal_cooldown
	//Выдача настроек при иницилазации карапаса
	stage_1_repair()
	stage_2_repair()
	stage_3_repair()
	broken_stage = 0

/datum/component/carapace_shell/RegisterWithParent()
	RegisterSignal(H, COMSIG_LIVING_LIFE, PROC_REF(process_shell))
	RegisterSignal(H, COMSIG_SURGERY_STOP, PROC_REF(check_surgery_perform))
	RegisterSignal(H, COMSIG_SURGERY_REPAIR, PROC_REF(surgery_carapace_shell_repair))
	RegisterSignal(H, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(update_attacked_time))

/datum/component/carapace_shell/UnregisterFromParent()
	UnregisterSignal(H, COMSIG_LIVING_LIFE)
	UnregisterSignal(H, COMSIG_SURGERY_STOP)
	UnregisterSignal(H, COMSIG_SURGERY_REPAIR)
	UnregisterSignal(H, COMSIG_MOB_APPLY_DAMAGE)

/datum/component/carapace_shell/proc/stage_1_break()
	H.dna.species.brute_mod = CARAPACE_SHELL_BROKEN_BRUTE
	H.dna.species.burn_mod = CARAPACE_SHELL_BROKEN_BURN
	REMOVE_TRAIT(H, TRAIT_PIERCEIMMUNE, "carapace_state")
	H.throw_alert("carapace_break", /atom/movable/screen/alert/carapace/break_armor)
	broken_stage++

/datum/component/carapace_shell/proc/stage_1_repair()
	H.dna.species.brute_mod = CARAPACE_SHELL_ARMORED_BRUTE
	H.dna.species.burn_mod = CARAPACE_SHELL_ARMORED_BURN
	ADD_TRAIT(H, TRAIT_PIERCEIMMUNE, "carapace_state")
	H.clear_alert("carapace_break")
	broken_stage--

/datum/component/carapace_shell/proc/stage_2_break()
	H.throw_alert("carapace_break", /atom/movable/screen/alert/carapace/break_cloak)
	broken_stage++

/datum/component/carapace_shell/proc/stage_2_repair()
	broken_stage--

/datum/component/carapace_shell/proc/stage_3_break()
	H.throw_alert("carapace_break", /atom/movable/screen/alert/carapace/break_rig)
	H.dna.species.hazard_high_pressure = HAZARD_HIGH_PRESSURE
	H.dna.species.warning_high_pressure = WARNING_HIGH_PRESSURE
	H.dna.species.warning_low_pressure = WARNING_LOW_PRESSURE
	H.dna.species.hazard_low_pressure = HAZARD_LOW_PRESSURE
	H.dna.species.cold_level_1 = initial(H.dna.species.cold_level_1)
	H.dna.species.cold_level_2 = H.dna.species.cold_level_1 - armored_temp_progression
	H.dna.species.cold_level_3 = H.dna.species.cold_level_2 - armored_temp_progression
	H.dna.species.heat_level_1 = initial(H.dna.species.heat_level_2)
	H.dna.species.heat_level_2 = H.dna.species.heat_level_1 + armored_temp_progression
	H.dna.species.heat_level_3 = H.dna.species.heat_level_2 + armored_temp_progression
	broken_stage++

/datum/component/carapace_shell/proc/stage_3_repair()
	H.dna.species.hazard_high_pressure = INFINITY
	H.dna.species.warning_high_pressure = INFINITY
	H.dna.species.warning_low_pressure = -INFINITY
	H.dna.species.hazard_low_pressure = -INFINITY
	H.dna.species.cold_level_1 = armored_cold_threshold
	H.dna.species.cold_level_2 = H.dna.species.cold_level_1 - armored_temp_progression
	H.dna.species.cold_level_3 = H.dna.species.cold_level_2 - armored_temp_progression
	H.dna.species.heat_level_1 = armored_heat_threshold
	H.dna.species.heat_level_2 = H.dna.species.heat_level_1 + armored_temp_progression
	H.dna.species.heat_level_3 = H.dna.species.heat_level_2 + armored_temp_progression

	broken_stage--

/datum/component/carapace_shell/proc/update_attacked_time()
	SIGNAL_HANDLER
	last_time_action = world.time

//Прок на запуск ремонта
/datum/component/carapace_shell/proc/surgery_carapace_shell_repair()
	SIGNAL_HANDLER
	switch(broken_stage)
		if(1)	stage_1_repair()
		if(2)	stage_2_repair()
		if(3)	stage_3_repair()

//Прок на проверку состояния панциря
/datum/component/carapace_shell/proc/check_surgery_perform()
	SIGNAL_HANDLER
	var/character_damage = H.getBruteLoss() + H.getFireLoss()
	var/can_perform = FALSE
	if(broken_stage > 0)
		can_perform = (broken_stage > 0 && character_damage < state_1_threshold) || (broken_stage > 1 && character_damage < state_2_threshold) || (broken_stage > 2 && character_damage < state_3_threshold)
	return (can_perform ? SURGERY_STOP : FALSE)

//Прок на обновление состояний панциря
/datum/component/carapace_shell/proc/process_shell()
	SIGNAL_HANDLER
	var/character_damage = H.getBruteLoss() + H.getFireLoss()
	var/can_self_repair = world.time - last_time_action > self_repair_cooldown
	//Потеря брони при первом трешхолде
	if(character_damage >= state_1_threshold)
		if(broken_stage < 1)
			stage_1_break()
	else if(can_self_repair && broken_stage < 2)
		stage_1_repair()
		last_time_action = world.time

	//Потеря стелса при втором трешхолде
	if(character_damage >= state_2_threshold)
		if(broken_stage < 2)
			stage_2_break()
	else if(can_self_repair && broken_stage < 3)
		stage_2_repair()
		last_time_action = world.time

	//Потеря рига при третьем трешхолде
	if(character_damage >= state_3_threshold)
		if(broken_stage < 3)
			stage_3_break()
	else if(can_self_repair && broken_stage > 2)
		stage_3_repair()
		last_time_action = world.time

	//Потеря стелса при втором трешхолде
	var/obj/item/organ/internal/kidneys/serpentid/organ = H.get_int_organ("kidneys")
	if(broken_stage >= 2)
		if(istype(organ))
			organ.switch_mode(force_off = TRUE)

#undef CARAPACE_SHELL_ARMORED_BRUTE
#undef CARAPACE_SHELL_ARMORED_BURN
#undef CARAPACE_SHELL_BROKEN_BRUTE
#undef CARAPACE_SHELL_BROKEN_BURN
