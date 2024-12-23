// Язык вульпкан

/datum/language/nabberian
	name = "Наберийский"
	desc = "Основной разговорный язык серпентидов."
	key = "8"
	flags = TONGUELESS_SPEECH | LANGUAGE_HIDE_ICON_IF_NOT_UNDERSTOOD
	space_chance = 60
	syllables = list("клик","клак","клинг","кланг","кланд","клог","клац","клуц","клиц","клоц","звинг","звяньк","бзвум")
	icon = 'modular_bandastation/species/serpentids/icon/serpentid_face.dmi'
	icon_state = "serpentid_eyes"
	default_priority = 90

/datum/language/nabberian/get_random_name(
	gender = NEUTER,
	name_count = default_name_count,
	syllable_min = default_name_syllable_min,
	syllable_max = default_name_syllable_max,
	force_use_syllables = FALSE,
)
	if(force_use_syllables)
		return ..()
	if(gender != MALE)
		gender = pick(MALE, FEMALE)

	if(gender == MALE)
		return "[pick(GLOB.first_names_male)]"
	return "[pick(GLOB.first_names_female)]"

/datum/language_holder/serpentid
	understood_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/nabberian = list(LANGUAGE_ATOM),
	)
	spoken_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/nabberian = list(LANGUAGE_ATOM),
	)
