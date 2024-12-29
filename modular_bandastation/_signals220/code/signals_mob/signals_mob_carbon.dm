// Signals for /mob/living/carbon
// /datum/component/gadom_cargo/proc/try_load_cargo() : (/datum/component/gadom_living)
#define COMSIG_GADOM_LOAD "gadom_load"
// /datum/species/spec_attack_hand() /mob/living/carbon/human/MouseDrop_T() /mob/MouseDrop() : (/datum/component/gadom_cargo) (/datum/component/gadom_living)
#define COMSIG_GADOM_CAN_GRAB "gadom_can_grab"
	#define GADOM_CAN_GRAB (1 << 0)
// /datum/species/spec_attack_hand() : (/datum/component/gadom_cargo) (/datum/component/gadom_living)
#define COMSIG_GADOM_UNLOAD "gadom_unload"
// /datum/surgery_step/mend_carapace/success() : (/datum/component/carapace_shell)
#define COMSIG_SURGERY_REPAIR "surgery_repair"
// /datum/wound/carapace_damaged/apply_wound() : (/datum/component/carapace_shell)
#define COMSIG_HAVE_CARAPACE "have_carapace"
// /datum/component/carapace/proc/receive_damage() /datum/component/carapace/proc/heal_damage() : (/datum/component/carapace_shell)
#define COMSIG_CARAPACE_CHECK "carapace_check"

/mob/living/carbon/human/mouse_drop_receive(atom/movable/AM, mob/user)
	if(SEND_SIGNAL(usr, COMSIG_GADOM_CAN_GRAB) & GADOM_CAN_GRAB)
		SEND_SIGNAL(usr, COMSIG_GADOM_LOAD, user, AM)

/datum/species/spec_attack_hand(mob/living/carbon/human/M, mob/living/carbon/human/H, datum/martial_art/attacker_style)
	if(SEND_SIGNAL(H, COMSIG_GADOM_CAN_GRAB)  & GADOM_CAN_GRAB)
		SEND_SIGNAL(H, COMSIG_GADOM_UNLOAD)
	. = .. ()
