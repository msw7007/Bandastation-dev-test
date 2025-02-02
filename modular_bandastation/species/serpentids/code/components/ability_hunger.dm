/*
Компонент на органы для работы с запасами химикатов
*/

/datum/component/hunger_organ
	var/obj/item/organ/organ
	var/consuption_count = 0

/datum/component/hunger_organ/Initialize(reagent_id)
	organ = parent

/datum/component/hunger_organ/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ORGAN_ON_LIFE, PROC_REF(hunger_process))
	RegisterSignal(parent, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, PROC_REF(hunger_change_consuption))

/datum/component/hunger_organ/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ORGAN_ON_LIFE)
	UnregisterSignal(parent, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION)

/datum/component/hunger_organ/proc/hunger_process(holder)
	SIGNAL_HANDLER
	if(isnull(organ.owner))
		return TRUE
	var/active = FALSE
	if(istype(organ, /obj/item/organ/liver/serpentid))
		var/obj/item/organ/liver/serpentid/checkorgan = organ
		active = checkorgan.cloak_engaged
	if(istype(organ, /obj/item/organ/eyes/serpentid))
		var/obj/item/organ/eyes/serpentid/checkorgan = organ
		active = checkorgan.active
	if(istype(organ, /obj/item/organ/lungs/serpentid))
		var/obj/item/organ/lungs/serpentid/checkorgan = organ
		active = checkorgan.active_secretion
	if(istype(organ, /obj/item/organ/ears/serpentid))
		var/obj/item/organ/ears/serpentid/checkorgan = organ
		active = checkorgan.active
	if(consuption_count && organ.owner.nutrition > NUTRITION_LEVEL_STARVING)
		organ.owner.adjust_nutrition(-consuption_count)
	else if(active) //Если количества недостаточно - выключить режим
		organ.switch_mode(force_off = TRUE)


/datum/component/hunger_organ/proc/hunger_change_consuption(holder, new_consuption_count)
	SIGNAL_HANDLER
	consuption_count = new_consuption_count
