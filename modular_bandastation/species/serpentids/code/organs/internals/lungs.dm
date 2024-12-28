///Легкие - вырабатывают сальбутамол при наличии глутамата натрия, имеют собственный мешок, из которого дышат, мешок заполняется в безопасной среде
#define SERPENTID_COLD_THRESHOLD_LEVEL_BASE 100
#define SERPENTID_COLD_THRESHOLD_LEVEL_DOWN 40
#define SERPENTID_HEAT_THRESHOLD_LEVEL_BASE 350
#define SERPENTID_HEAT_THRESHOLD_LEVEL_UP 60
#define SERPENTID_LUNGS_SAFE_TIMER 10 SECONDS

/obj/item/organ/lungs/serpentid
	name = "thacheal bag"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	desc = "A large looking lugns with big breating bag."
	icon_state = "lungs"
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	//action_icon = list(/datum/action/item_action/organ_action/toggle/serpentid = 'modular_bandastation/species/serpentids/icons/organs.dmi')
	//action_icon_state = list(/datum/action/item_action/organ_action/toggle/serpentid = "serpentid_abilities")
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_LUNGS
	var/obj/item/tank/internals/oxygen/serpentid_vault = new /obj/item/tank/internals/oxygen/serpentid_vault_tank
	var/chem_to_oxy_mult = 0.1
	var/hand_active = FALSE
	var/active_secretion = FALSE
	var/salbutamol_production = 0.5
	var/last_safe_zone_check = 0
	var/last_danger_air_check = 0
	radial_action_state = "ballon"
	radial_action_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'

/obj/item/organ/lungs/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.05)
	AddComponent(/datum/component/organ_action, radial_action_state, radial_action_icon)
	AddComponent(/datum/component/hunger_organ)

/obj/item/tank/internals/oxygen/serpentid_vault_tank
	name = "serpentid oxygen vault"
	volume = 5

/obj/item/tank/internals/oxygen/serpentid_vault_tank/populate_gas()
	air_contents.assert_gas(/datum/gas/oxygen)
	air_contents.gases[/datum/gas/oxygen][MOLES] = (0.5*ONE_ATMOSPHERE)*volume/(R_IDEAL_GAS_EQUATION*T20C)
	distribute_pressure = 22

/obj/item/organ/lungs/serpentid/proc/switch_mode_on()
	if(owner?.nutrition >= NUTRITION_LEVEL_STARVING)
		active_secretion = TRUE
		chemical_consuption = initial(chemical_consuption)
		last_safe_zone_check = world.time
	else
		switch_mode_off()

/obj/item/organ/lungs/serpentid/proc/switch_mode_off()
	active_secretion = FALSE
	chemical_consuption = 0

/obj/item/organ/lungs/serpentid/switch_mode(force_off = FALSE)
	. = ..()
	if(!force_off && !(organ_flags & ORGAN_FAILING))
		switch_mode_on()
	else
		switch_mode_off()
	SEND_SIGNAL(src, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, chemical_consuption)

/obj/item/organ/lungs/serpentid/on_life()
	. = ..()
	if(!owner)
		return

	if(!owner.loc)
		return

	var/datum/gas_mixture/environment = loc.return_air()
	var/danger_air = in_danger_zone(environment)

	if(last_danger_air_check)
		last_safe_zone_check = world.time

	last_danger_air_check = danger_air

	if(active_secretion)
		// Если Серпентид выделяет вещества и задыхается - подать сальбутамол
		if(owner.getOxyLoss())
			owner.reagents.add_reagent("salbutamol", salbutamol_production)

		// Если Серпентид выделяет вещества, но среда опасна и не активен "болон" - дышать через мешок
		if(danger_air && !owner.internal)
			owner.internal = serpentid_vault

		// Если Серпентид выделяет вещества, но среда не опасна и с момента последней проверки на безопасность дыхание прошло более 10 секунд - прекращение выделения
		var/safe_zone_timer = world.time - last_safe_zone_check
		if(safe_zone_timer > SERPENTID_LUNGS_SAFE_TIMER && !danger_air)
			switch_mode_off()

	// Если Серпентид не выделяет вещества, и среда опасна и он без сознания - начать выделять вещества
	if(danger_air && (owner.stat == UNCONSCIOUS) && !active_secretion)
		if(!owner.internal)
			switch_mode_on()

	// Если среда не опасна и Серпентид дышит через мешок - дышать нормально
	if(!danger_air && owner.internal == serpentid_vault)
		owner.internal = null

	var/pressure_value = serpentid_vault.air_contents.return_pressure()
	// Если давление в мешке ниже нормы (50 КПа)
	if(pressure_value < 50)
		var/replenish_value = 0
		// Если среда опасна, вырабатывать кислород химические, иначе наполнять его через среду
		if(danger_air)
			if(active_secretion)
				replenish_value = chemical_consuption * chem_to_oxy_mult
		else
			var/breath_moles = 0
			var/datum/gas_mixture/replenish_gas = environment.get_breath_partial_pressure(breath_moles)
			replenish_value = replenish_gas.gases[/datum/gas/oxygen][MOLES]
		var/oxygen_value = (0.5 * ONE_ATMOSPHERE) * serpentid_vault.volume  * replenish_value
		var/gas_mix_value = R_IDEAL_GAS_EQUATION * T20C
		var/value_to_replenish = ( oxygen_value / gas_mix_value )
		if(value_to_replenish > 0)
			serpentid_vault.air_contents.gases[/datum/gas/oxygen][MOLES] = serpentid_vault.air_contents.gases[/datum/gas/oxygen][MOLES] + value_to_replenish

/mob/living/carbon/human/proc/serpen_lungs(volume_needed)
	if(internal)
		return internal.remove_air_volume(volume_needed)
	return null

/obj/item/organ/lungs/serpentid/proc/in_danger_zone(datum/gas_mixture/breath)

	//Получение данных
	var/ox_pressure = (breath ? breath.get_breath_partial_pressure(breath[/datum/gas/oxygen]) : 0)
	var/n2_pressure = (breath ? breath.get_breath_partial_pressure(breath[/datum/gas/nitrogen]) : 0)
	var/tox_pressure = (breath ? breath.get_breath_partial_pressure(breath[/datum/gas/plasma]) : 0)
	var/co2_pressure = (breath ? breath.get_breath_partial_pressure(breath[/datum/gas/carbon_dioxide]) : 0)
	var/sa_pressure = (breath ? breath.get_breath_partial_pressure(breath[/datum/gas/nitrous_oxide]) : 0)
	var/bz_pressure = (breath ? breath.get_breath_partial_pressure(breath[/datum/gas/bz]) : 0)

	// Проверка кислорода
	var/O2_above_max = (safe_oxygen_max ? FALSE : ox_pressure > safe_oxygen_max)
	var/O2_below_min = (safe_oxygen_min ? FALSE : ox_pressure < safe_oxygen_min)
	var/O2_pp = O2_above_max || O2_below_min

	// Проверка токсинов
	var/Toxins_above_max = (safe_plasma_max ? FALSE : tox_pressure > safe_plasma_max)
	var/Toxins_below_min = (safe_plasma_min ? FALSE : tox_pressure < safe_plasma_min)
	var/Toxins_pp = Toxins_above_max || Toxins_below_min

	// Проверка азота
	var/N2_pp = (safe_nitro_min ? FALSE : n2_pressure < safe_nitro_min)

	// Проверка углекислого газа
	var/CO2_pp = (safe_co2_max ? FALSE : co2_pressure > safe_co2_max)

	// Проверка сонного газа
	var/SA_pp = (n2o_para_min ? FALSE : sa_pressure > n2o_para_min)

	var/BZ_pp = (BZ_trip_balls_min ? FALSE : bz_pressure > BZ_trip_balls_min)

	// Общая проверка зоны опасности
	var/danger_zone = O2_pp || N2_pp || Toxins_pp || CO2_pp || SA_pp || BZ_pp

	return danger_zone

#undef SERPENTID_LUNGS_SAFE_TIMER
#undef SERPENTID_COLD_THRESHOLD_LEVEL_BASE
#undef SERPENTID_COLD_THRESHOLD_LEVEL_DOWN
#undef SERPENTID_HEAT_THRESHOLD_LEVEL_BASE
#undef SERPENTID_HEAT_THRESHOLD_LEVEL_UP
