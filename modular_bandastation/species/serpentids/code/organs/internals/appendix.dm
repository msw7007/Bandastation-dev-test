
/obj/item/organ/appendix/serpentid
	name = "food processor"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "kidneys"
	desc = "A large looking appendix."

/obj/item/organ/appendix/serpentid/on_life(seconds_per_tick, times_fired)
	. = ..()
	// Аппендикс ГБС - подавляет ВСЕ болезни. Кроме аппендицита.
