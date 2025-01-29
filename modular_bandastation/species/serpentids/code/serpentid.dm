/datum/species/serpentid
	name = "\improper Гигантский Бронированный Серпентид"
	plural_form = "Serpentids"
	id = SPECIES_SERPENTID

	inherent_biotypes = MOB_HUMANOID


	inherent_traits = list(
		TRAIT_MUTANT_COLORS, TRAIT_GLUTTON, TRAIT_ILLITERATE, TRAIT_PERFECT_ATTACKER
	)
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_MAGIC | MIRROR_PRIDE | RACE_SWAP

	species_language_holder = /datum/language_holder/serpentid

	mutantbrain = /obj/item/organ/brain/serpentid
	mutantheart = /obj/item/organ/heart/serpentid
	mutantlungs = /obj/item/organ/lungs/serpentid
	mutanteyes = /obj/item/organ/eyes/serpentid
	mutantears = /obj/item/organ/ears/serpentid
	mutanttongue = /obj/item/organ/tongue/serpentid
	mutantliver = /obj/item/organ/liver/serpentid
	mutantstomach = /obj/item/organ/stomach/serpentid
	mutant_organs = list(
		/obj/item/organ/tail/serpentid = "Default",
		/obj/item/organ/serpenblades = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/serpenblades/serpentid = "Default",
	)

	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/serpentid,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/serpentid,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/serpentid,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/serpentid,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/serpentid,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/serpentid,
	)

	payday_modifier = 0.8
	bodytemp_heat_damage_limit = BODYTEMP_HEAT_DAMAGE_LIMIT + 30
	bodytemp_cold_damage_limit = BODYTEMP_COLD_DAMAGE_LIMIT - 60

/*
/datum/species/serpentid/prepare_human_for_preview(mob/living/carbon/human/serpentid)
	serpentid.set_haircolor("#A26324", update = FALSE) // brown
	serpentid.set_hairstyle("Jagged", update = TRUE)
	serpentid.dna.features["mcolor"] = "#D69E67"
	serpentid.dna.features["serpentid_head_accessories"] = "serpentid Earfluff"
	serpentid.dna.features["furcolor_first"] = "#bd762f"
	serpentid.dna.features["furcolor_second"] = "#2b2015"
	serpentid.dna.features["furcolor_third"] = "#2b2015"
	serpentid.dna.features["furcolor_fourth"] = "#ffa2be"
	serpentid.dna.features["furcolor_fifth"] = "#bd762f"
	serpentid.update_body(is_creating = TRUE)

/datum/species/serpentid/randomize_features()
	var/list/features = ..()
	features["serpentid_body_markings"] = prob(50) ? pick(SSaccessories.serpentid_body_markings_list) : "None"
	features["tail_markings"] = prob(50) ? pick(SSaccessories.serpentid_tail_markings_list) : "None"
	features["serpentid_head_markings"] = prob(50) ? pick(SSaccessories.serpentid_head_markings_list) : "None"
	features["serpentid_head_accessories"] = prob(50) ? pick(SSaccessories.serpentid_head_accessories_list) : "None"
	features["serpentid_facial_hair"] = prob(50) ? pick(SSaccessories.serpentid_facial_hair_list) : "None"

	var/furcolor = "#[random_color()]"
	features["furcolor_first"] = furcolor
	features["furcolor_second"] = furcolor
	features["furcolor_third"] = furcolor
	features["furcolor_fourth"] = furcolor
	features["furcolor_fifth"] = furcolor
	return features
*/

/datum/species/serpentid/get_physical_attributes()
	return "Вульпканины - двуногие гуманоиды собакоподобные покрытые шерстью, ростом от 140 до 180 см и весом до 60 кг. \
	Их скелет легкий и прочный, а череп особенно прочно соединен с позвоночником. \
	У них глубоко расположенный речевой аппарат, длинный язык, паутинообразная грудная клетка, длинные пальцы с острыми \
	когтями, длинные задние конечности для ходьбы и бега, хвост для равновесия и невербального общения. \
	Их шерсть мягкая, хорошо сохраняет тепло, но уязвима к высоким температурам и химическим веществам."

/datum/species/serpentid/get_species_description()
	return "Вульпканины происходят с планеты Альтам, которая долгое время находится в стадии кровопролитной войны трёх доминирующих кланов, \
	которые пытаются установить на планете единый режим и привести расу вульпканинов к процветанию."

/datum/species/serpentid/get_species_lore()
	return list(
		"Альтам, родина вульпканинов, представляет собой мир, где горы, покрытые снегом, устремляются к небесам, а ниже расстилаются холодные пустыни. \
		Температура здесь редко поднимается выше одного градуса, создавая пейзаж вечного прохладного уединения. \
		В мире Альтама растения хитроумно сохраняют влагу под восковыми листьями, расцветая в короткую весну и оживляя холодные пустыни яркими красками. \
		Вульпканины гармонично вписываются в этот мир. Их мягкая шерсть и стальные мышцы помогают противостоять холоду.",

		"В силу того, что вульпкане окончательно не оформились в единственное государство, они представляют из себя децентрализованное скопление кланов, находящихся на своей родной планете Альтам. \
		Интересы расы во внешней политике не представляют из себя ничего. Вульпканины погружены в распри и кровопролитные войны на своей планете. \
		Сотни тысяч беженцев-вульпканинов заполонили всю галактику; те, кто хочет мира своей нации, бегут от войны, им чужды идеи их соплеменников, из-за чего оставшиеся на Альтаме вульпканины буквально ненавидят кочующих собратьев.",

		"Культура вульпканинов - это небогатое, но многообразное наследие, которое развивается в условиях войны и поиске единства на Альтаме. \
		На протяжении всей войны вульпканинская культура потеряла многие кланы, племена и народности. \
		Вульпканины продолжают бороться между собой за единство и мирную жизнь на планете Альтам, стремясь достичь процветания и равновесия для своей расы.",

		"Представители расы вульпканинов являются отличными разнорабочими, которые без особых проблем выполняют свои обязанности - от уборщика до наёмника. \
		В частности, представители кланов - это относительно дешёвая рабочая сила, неприхотливая в быту и пище, готовая работать за скромную плату. \
		Практически все члены кланов отправляют часть заработанных средств своему родному клану. \
		Что касается беженцев, то они не особо проявляют активность, например, на политическом поприще.",
	)

/datum/species/serpentid/create_pref_unique_perks()
	var/list/to_add = list()

	to_add += list(
		list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "wind",
			SPECIES_PERK_NAME = "Чувствительный нюх",
			SPECIES_PERK_DESC = "[plural_form] могут различать больше запахов и запоминать их.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
			SPECIES_PERK_ICON = "assistive-listening-systems",
			SPECIES_PERK_NAME = "Чувствительный слух",
			SPECIES_PERK_DESC = "[plural_form] лучше слышат, но более чувствительны к громким звукам, например, светошумовым гранатам.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "fire-alt",
			SPECIES_PERK_NAME = "Быстрый метаболизм",
			SPECIES_PERK_DESC = "[plural_form] быстрее тратят полезные вещества, потому чаще хотят есть.",
		),
	)

	return to_add

/datum/species/serpentid/create_pref_temperature_perks()
	return list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "temperature-low",
			SPECIES_PERK_NAME = "Термоустойчивость",
			SPECIES_PERK_DESC = "[plural_form] лучше переносят перепады температур.",))

/datum/species/serpentid/create_pref_liver_perks()
	return list(list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "wine-glass",
			SPECIES_PERK_NAME = "Чувствительность к алкоголю",
			SPECIES_PERK_DESC = "Вульпканская печень более восприимчива к алкоголю, чем печень человека, примерно на 150%."
		))

/datum/species/serpentid/create_pref_language_perk()
	return list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "comment",
			SPECIES_PERK_NAME = "Носитель языка",
			SPECIES_PERK_DESC = "[plural_form] получают возможность говорить на Канилунце.",
		))

/datum/species/serpentid/get_scream_sound(mob/living/carbon/human/human)
	if(human.physique == MALE)
		return pick(
			'sound/mobs/humanoids/human/scream/malescream_1.ogg',
			'sound/mobs/humanoids/human/scream/malescream_2.ogg',
			'sound/mobs/humanoids/human/scream/malescream_3.ogg',
			'sound/mobs/humanoids/human/scream/malescream_4.ogg',
			'sound/mobs/humanoids/human/scream/malescream_5.ogg',
			'sound/mobs/humanoids/human/scream/malescream_6.ogg',
		)

	return pick(
		'sound/mobs/humanoids/human/scream/femalescream_1.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_2.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_3.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_4.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_5.ogg',
	)

/datum/species/serpentid/get_cough_sound(mob/living/carbon/human/human)
	if(human.physique == FEMALE)
		return pick(
			'sound/mobs/humanoids/human/cough/female_cough1.ogg',
			'sound/mobs/humanoids/human/cough/female_cough2.ogg',
			'sound/mobs/humanoids/human/cough/female_cough3.ogg',
			'sound/mobs/humanoids/human/cough/female_cough4.ogg',
			'sound/mobs/humanoids/human/cough/female_cough5.ogg',
			'sound/mobs/humanoids/human/cough/female_cough6.ogg',
		)
	return pick(
		'sound/mobs/humanoids/human/cough/male_cough1.ogg',
		'sound/mobs/humanoids/human/cough/male_cough2.ogg',
		'sound/mobs/humanoids/human/cough/male_cough3.ogg',
		'sound/mobs/humanoids/human/cough/male_cough4.ogg',
		'sound/mobs/humanoids/human/cough/male_cough5.ogg',
		'sound/mobs/humanoids/human/cough/male_cough6.ogg',
	)

/datum/species/serpentid/get_cry_sound(mob/living/carbon/human/human)
	if(human.physique == FEMALE)
		return pick(
			'sound/mobs/humanoids/human/cry/female_cry1.ogg',
			'sound/mobs/humanoids/human/cry/female_cry2.ogg',
		)
	return pick(
		'sound/mobs/humanoids/human/cry/male_cry1.ogg',
		'sound/mobs/humanoids/human/cry/male_cry2.ogg',
		'sound/mobs/humanoids/human/cry/male_cry3.ogg',
	)


/datum/species/serpentid/get_sneeze_sound(mob/living/carbon/human/human)
	if(human.physique == FEMALE)
		return 'sound/mobs/humanoids/human/sneeze/female_sneeze1.ogg'
	return 'sound/mobs/humanoids/human/sneeze/male_sneeze1.ogg'

/datum/species/serpentid/get_laugh_sound(mob/living/carbon/human/human)
	if(!ishuman(human))
		return
	if(human.physique == FEMALE)
		return 'sound/mobs/humanoids/human/laugh/womanlaugh.ogg'
	return pick(
		'sound/mobs/humanoids/human/laugh/manlaugh1.ogg',
		'sound/mobs/humanoids/human/laugh/manlaugh2.ogg',
	)
