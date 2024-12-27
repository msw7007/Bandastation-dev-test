/*
=== Органы-токсины ===
Реализует процесс повреждения урона если в орагнизме обнаружен токсинный урон
*/

#define TOX_ORGANS_PROCESS 1

/datum/component/organ_toxin_damage
	var/obj/item/organ/organ = null
	var/toxin_damage_rate
	var/toxin_block_rate

/datum/component/organ_toxin_damage/Initialize(tox_rate = TOX_ORGANS_PROCESS, tox_mult_damage = 1)
	organ = parent
	toxin_damage_rate = tox_rate
	toxin_block_rate = tox_mult_damage

/datum/component/organ_toxin_damage/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ORGAN_TOX_HANDLE, PROC_REF(tox_handle_organ))

/datum/component/organ_toxin_damage/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ORGAN_TOX_HANDLE)

/datum/component/organ_toxin_damage/proc/tox_handle_organ()
	SIGNAL_HANDLER
	if(organ.owner.stat == DEAD)
		return

	if(organ.organ_flags & ORGAN_FAILING)
		return

	if(organ.owner.getToxLoss())
		var/obj/item/organ/liver/liver = organ.owner.organs_slot[ORGAN_SLOT_LIVER]
		var/tox_damage = organ.owner.getToxLoss() * toxin_damage_rate

		if(organ == liver)
			organ.apply_organ_damage(tox_damage * toxin_block_rate, required_organ_flag = ORGAN_ORGANIC)
			organ.owner.heal_damage_type(tox_damage, damagetype = TOX)
		else if(liver.organ_flags & ORGAN_FAILING)
			organ.apply_organ_damage(tox_damage * toxin_block_rate, required_organ_flag = ORGAN_ORGANIC)

#undef TOX_ORGANS_PROCESS
