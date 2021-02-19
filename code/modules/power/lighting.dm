// The lighting system
//
// consists of light fixtures (/obj/machinery/light) and light tube/bulb items (/obj/item/light)

#define LIGHT_EMERGENCY_POWER_USE 0.2 //How much power emergency lights will consume per tick
// status values shared between lighting fixtures and items
#define LIGHT_OK 0
#define LIGHT_EMPTY 1
#define LIGHT_BROKEN 2
#define LIGHT_BURNED 3



/obj/item/wallframe/light_fixture
	name = "light fixture frame"
	desc = "Used for building lights."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "tube-construct-item"
	result_path = /obj/structure/light_construct
	inverse = TRUE

/obj/item/wallframe/light_fixture/small
	name = "small light fixture frame"
	icon_state = "bulb-construct-item"
	result_path = /obj/structure/light_construct/small
	materials = list(MAT_METAL=MINERAL_MATERIAL_AMOUNT)

/obj/item/wallframe/light_fixture/try_build(turf/on_wall, user)
	if(!..())
		return
	var/area/A = get_area(user)
	if(!IS_DYNAMIC_LIGHTING(A))
		to_chat(user, "<span class='warning'>You cannot place [src] in this area!</span>")
		return
	return TRUE


/obj/structure/light_construct
	name = "light fixture frame"
	desc = "A light fixture under construction."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "tube-construct-stage1"
	anchored = TRUE
	layer = WALL_OBJ_LAYER
	max_integrity = 200
	armor = list("melee" = 50, "bullet" = 10, "laser" = 10, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 80, "acid" = 50)

	var/stage = 1
	var/fixture_type = "tube"
	var/sheets_refunded = 2
	var/obj/machinery/light/newlight = null
	var/obj/item/stock_parts/cell/cell

	var/cell_connectors = FALSE

/obj/structure/light_construct/Initialize(mapload, ndir, building)
	. = ..()
	if(building)
		setDir(ndir)

/obj/structure/light_construct/Destroy()
	QDEL_NULL(cell)
	return ..()

/obj/structure/light_construct/get_cell()
	return cell

/obj/structure/light_construct/examine(mob/user)
	..()
	switch(src.stage)
		if(1)
			to_chat(user, "It's an empty frame.")
		if(2)
			to_chat(user, "It's wired.")
		if(3)
			to_chat(user, "The casing is closed.")
	if(cell_connectors)
		if(cell)
			to_chat(user, "You see [cell] inside the casing.")
		else
			to_chat(user, "The casing has no power cell for backup power.")
	else
		to_chat(user, "<span class='danger'>This casing doesn't support power cells for backup power.</span>")
		return

/obj/structure/light_construct/attackby(obj/item/W, mob/user, params)
	add_fingerprint(user)
	if(istype(W, /obj/item/stock_parts/cell))
		if(!cell_connectors)
			to_chat(user, "<span class='warning'>This [name] can't support a power cell!</span>")
			return
		if(W.item_flags & NODROP)
			to_chat(user, "<span class='warning'>[W] is stuck to your hand!</span>")
			return
		user.dropItemToGround(W)
		if(cell)
			user.visible_message("<span class='notice'>[user] swaps [W] out for [src]'s cell.</span>", \
			"<span class='notice'>You swap [src]'s power cells.</span>")
			cell.forceMove(drop_location())
			user.put_in_hands(cell)
		else
			user.visible_message("<span class='notice'>[user] hooks up [W] to [src].</span>", \
			"<span class='notice'>You add [W] to [src].</span>")
		playsound(src, 'sound/machines/click.ogg', 50, TRUE)
		W.forceMove(src)
		cell = W
		add_fingerprint(user)
		return
	switch(stage)
		if(1)
			if(istype(W, /obj/item/wrench))
				to_chat(usr, "<span class='notice'>You begin deconstructing [src]...</span>")
				if (W.use_tool(src, user, 30, volume=50))
					new /obj/item/stack/sheet/metal(drop_location(), sheets_refunded)
					user.visible_message("[user.name] deconstructs [src].", \
						"<span class='notice'>You deconstruct [src].</span>", "<span class='italics'>You hear a ratchet.</span>")
					playsound(src.loc, 'sound/items/deconstruct.ogg', 75, 1)
					qdel(src)
				return

			if(istype(W, /obj/item/stack/cable_coil))
				var/obj/item/stack/cable_coil/coil = W
				if(coil.use(1))
					icon_state = "[fixture_type]-construct-stage2"
					stage = 2
					user.visible_message("[user.name] adds wires to [src].", \
						"<span class='notice'>You add wires to [src].</span>")
				else
					to_chat(user, "<span class='warning'>You need one length of cable to wire [src]!</span>")
				return
		if(2)
			if(istype(W, /obj/item/wrench))
				to_chat(usr, "<span class='warning'>You have to remove the wires first!</span>")
				return

			if(istype(W, /obj/item/wirecutters))
				stage = 1
				icon_state = "[fixture_type]-construct-stage1"
				new /obj/item/stack/cable_coil(drop_location(), 1, "red")
				user.visible_message("[user.name] removes the wiring from [src].", \
					"<span class='notice'>You remove the wiring from [src].</span>", "<span class='italics'>You hear clicking.</span>")
				W.play_tool_sound(src, 100)
				return

			if(istype(W, /obj/item/screwdriver))
				user.visible_message("[user.name] closes [src]'s casing.", \
					"<span class='notice'>You close [src]'s casing.</span>", "<span class='italics'>You hear screwing.</span>")
				W.play_tool_sound(src, 75)
				switch(fixture_type)
					if("tube")
						newlight = new /obj/machinery/light/built(loc)
					if("bulb")
						newlight = new /obj/machinery/light/small/built(loc)
				if(newlight)
					newlight.setDir(dir)
					transfer_fingerprints_to(newlight)
					if(cell)
						newlight.cell = cell
						cell.forceMove(newlight)
						cell = null
					qdel(src)
				return
	return ..()

/obj/structure/light_construct/blob_act(obj/structure/blob/B)
	if(B && B.loc == loc)
		qdel(src)


/obj/structure/light_construct/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/metal(loc, sheets_refunded)
	qdel(src)

/obj/structure/light_construct/small
	name = "small light fixture frame"
	icon_state = "bulb-construct-stage1"
	fixture_type = "bulb"
	sheets_refunded = 1



// the standard tube light fixture
/obj/machinery/light
	name = "light fixture"
	icon = 'icons/obj/lighting.dmi'
	var/overlayicon = 'icons/obj/lighting_overlay.dmi'
	var/base_state = "tube"		// base description and icon_state
	icon_state = "tube"
	desc = "A lighting fixture."
	layer = WALL_OBJ_LAYER
	max_integrity = 100
	use_power = ACTIVE_POWER_USE
	idle_power_usage = 2
	active_power_usage = 20
	power_channel = LIGHT //Lights are calc'd via area so they dont need to be in the machine list
	var/on = FALSE					// 1 if on, 0 if off
	var/on_gs = FALSE
	var/static_power_used = 0
	var/brightness = 8			// luminosity when on, also used in power calculation
	var/bulb_power = 1			// basically the alpha of the emitted light source
	var/bulb_colour = "#FFFFFF"	// befault colour of the light.
	var/status = LIGHT_OK		// LIGHT_OK, _EMPTY, _BURNED or _BROKEN
	var/status_prev = LIGHT_OK

	var/flickering = FALSE
	var/light_type = /obj/item/light/tube		// the type of light item
	var/fitting = "tube"
	var/switchcount = 0			// count of number of times switched on/off
								// this is used to calc the probability the light burns out

	var/rigged = FALSE			// true if rigged to explode

	var/prob_starts_broken = 5
	var/prob_starts_empty = 1
	var/prob_starts_burned = 0

	var/obj/item/stock_parts/cell/cell
	var/start_with_cell = FALSE	// if true, this fixture generates a very weak cell at roundstart

	var/nightshift_enabled = FALSE	//Currently in night shift mode?
	var/nightshift_allowed = TRUE	//Set to FALSE to never let this light get switched to night mode.
	var/nightshift_brightness = 8
	var/nightshift_light_power = 0.45
	var/nightshift_light_color = "#FFDDCC"

	var/emergency_mode = FALSE	// if true, the light is in emergency mode
	var/no_emergency = FALSE	// if true, this light cannot ever have an emergency mode
	var/bulb_emergency_brightness_mul = 0.25	// multiplier for this light's base brightness in emergency power mode
	var/bulb_emergency_colour = "#FF3232"	// determines the colour of the light while it's in emergency mode
	var/bulb_emergency_pow_mul = 0.75	// the multiplier for determining the light's power in emergency mode
	var/bulb_emergency_pow_min = 0.5	// the minimum value for the light's power in emergency mode

	var/nightshift_active = FALSE	//CUSTOM NIGHTSHIFT
	var/nightshift_start_time = 702000		//7:30 PM, station time
	var/nightshift_end_time = 270000		//7:30 AM, station time

/obj/machinery/light/Move()
	if(status != LIGHT_BROKEN)
		break_light_tube(1)
	return ..()

// create a new lighting fixture
/obj/machinery/light/Initialize()
	. = ..()
	if(start_with_cell && !no_emergency)
		cell = new/obj/item/stock_parts/cell/emergency_light(src)

	if(prob(prob_starts_empty))
		status = LIGHT_EMPTY

	if(prob(prob_starts_broken))
		status = LIGHT_BROKEN

	if(prob(prob_starts_burned))
		status = LIGHT_BURNED

	update(0,TRUE)

/obj/machinery/light/Destroy()
	if(cell in src.contents)
		qdel(cell)
	set_light(0)
	return ..()

// the smaller bulb light fixture
/obj/machinery/light/small
	icon_state = "bulb"
	base_state = "bulb"
	fitting = "bulb"
	brightness = 4
	desc = "A small lighting fixture."
	light_type = /obj/item/light/bulb
	prob_starts_broken = 2
	prob_starts_empty = 2

/obj/machinery/light/broken
	icon_state = "tube-broken"
	prob_starts_broken = 100

/obj/machinery/light/small/broken
	icon_state = "bulb-broken"
	prob_starts_broken = 100

/obj/machinery/light/built
	icon_state = "tube-empty"
	prob_starts_broken = 0
	prob_starts_empty = 100

/obj/machinery/light/small/built
	icon_state = "bulb-empty"
	prob_starts_broken = 0
	prob_starts_empty = 100

//A mini kahuna
/obj/machinery/light/update_icon()
	cut_overlays()
	switch(status)		// set icon_states
		if(LIGHT_OK)
			icon_state = "[base_state]"
			if(on)
				var/mutable_appearance/glowybit = mutable_appearance(overlayicon, base_state, ABOVE_LIGHTING_LAYER, ABOVE_LIGHTING_PLANE)
				glowybit.alpha = CLAMP(light_power*250, 30, 200)
				add_overlay(glowybit)
		if(LIGHT_EMPTY)
			icon_state = "[base_state]-empty"
		if(LIGHT_BURNED)
			icon_state = "[base_state]-burned"
		if(LIGHT_BROKEN)
			icon_state = "[base_state]-broken"
	return

// update the icon_state and luminosity of the light depending on its state
//A big kahuna
/obj/machinery/light/proc/update(trigger = TRUE, forceme = FALSE)

	if(!forceme && status == status_prev) //Nothing has changed
		return

	status_prev = status
	if(status == LIGHT_BROKEN || status == LIGHT_BURNED || status == LIGHT_EMPTY)
		on = FALSE
		use_power = IDLE_POWER_USE //We're off
		set_light(0)
	else
		on = TRUE
		if(rigged && trigger && status == LIGHT_OK && !forceme)
			set_light(0)
			explode()
			return //Don't bother doing anything else

		var/BR = brightness
		var/PO = bulb_power
		var/CO = bulb_colour
		if (nightshift_enabled)
			BR = nightshift_brightness
			PO = nightshift_light_power
			CO = nightshift_light_color

		use_power = ACTIVE_POWER_USE

		if(emergency_mode && has_emergency_power(LIGHT_EMERGENCY_POWER_USE))
			use_power = IDLE_POWER_USE
			emergency_mode = TRUE
			START_PROCESSING(SSmachines, src) //ugh I hate this, is this emergency shit even used
		else
			emergency_mode = FALSE

		set_light(BR, PO, CO)

	update_icon()
	active_power_usage = (brightness * 10)
	if(on != on_gs)
		on_gs = on
		if(on)
			static_power_used = brightness * 20 //20W per unit luminosity
			addStaticPower(static_power_used, STATIC_LIGHT)
		else
			removeStaticPower(static_power_used, STATIC_LIGHT) //I hate these

//This is purely used for emergency mode. What a shit
/obj/machinery/light/process()
	if (!cell)
		return PROCESS_KILL
	if(has_power())
		if (cell.charge == cell.maxcharge)
			return PROCESS_KILL
		cell.charge = min(cell.maxcharge, cell.charge + LIGHT_EMERGENCY_POWER_USE) //Recharge emergency power automatically while not using it
	if(emergency_mode && !use_emergency_power(LIGHT_EMERGENCY_POWER_USE))
		update(FALSE) //Disables emergency mode and sets the color to normal

/obj/machinery/light/proc/burn_out()
	if(status == LIGHT_OK)
		status = LIGHT_BURNED
		update()

// attempt to set the light's on/off status
// will not switch on if broken/burned/empty
/obj/machinery/light/proc/seton(s)
	on = (s && status == LIGHT_OK)
	update()

/obj/machinery/light/get_cell()
	return cell

// examine verb
/obj/machinery/light/examine(mob/user)
	..()
	switch(status)
		if(LIGHT_OK)
			to_chat(user, "It is turned [on? "on" : "off"].")
		if(LIGHT_EMPTY)
			to_chat(user, "The [fitting] has been removed.")
		if(LIGHT_BURNED)
			to_chat(user, "The [fitting] is burnt out.")
		if(LIGHT_BROKEN)
			to_chat(user, "The [fitting] has been smashed.")
	if(cell)
		to_chat(user, "Its backup power charge meter reads [round((cell.charge / cell.maxcharge) * 100, 0.1)]%.")



// attack with item - insert light (if right type), otherwise try to break the light

/obj/machinery/light/attackby(obj/item/W, mob/living/user, params)

	//Light replacer code
	if(istype(W, /obj/item/lightreplacer))
		var/obj/item/lightreplacer/LR = W
		LR.ReplaceLight(src, user)

	// attempt to insert light
	else if(istype(W, /obj/item/light))
		if(status == LIGHT_OK)
			to_chat(user, "<span class='warning'>There is a [fitting] already inserted!</span>")
		else
			src.add_fingerprint(user)
			var/obj/item/light/L = W
			if(istype(L, light_type))
				if(!user.temporarilyRemoveItemFromInventory(L))
					return

				src.add_fingerprint(user)
				if(status != LIGHT_EMPTY)
					drop_light_tube(user)
					to_chat(user, "<span class='notice'>You replace [L].</span>")
				else
					to_chat(user, "<span class='notice'>You insert [L].</span>")
				status = L.status
				switchcount = L.switchcount
				rigged = L.rigged
				brightness = L.brightness
				on = has_power()
				update()

				qdel(L)

				if(on && rigged)
					explode()
				return 1
			else
				to_chat(user, "<span class='warning'>This type of light requires a [fitting]!</span>")

	// attempt to stick weapon into light socket
	else if(status == LIGHT_EMPTY)
		if(istype(W, /obj/item/screwdriver)) //If it's a screwdriver open it.
			W.play_tool_sound(src, 75)
			user.visible_message("[user.name] opens [src]'s casing.", \
				"<span class='notice'>You open [src]'s casing.</span>", "<span class='italics'>You hear a noise.</span>")
			deconstruct()
		else
			to_chat(user, "<span class='userdanger'>You stick \the [W] into the light socket!</span>")
			if(has_power() && (W.flags_1 & CONDUCT_1))
				do_sparks(3, TRUE, src)
				if (prob(75))
					electrocute_mob(user, get_area(src), src, rand(0.7,1.0), TRUE)
	else
		return ..()

/obj/machinery/light/deconstruct(disassembled = TRUE)
	if(flags_1 & NODECONSTRUCT_1)
		return //Big nope

	var/obj/structure/light_construct/newlight = null
	var/cur_stage = 2
	if(!disassembled)
		cur_stage = 1
	switch(fitting)
		if("tube")
			newlight = new /obj/structure/light_construct(src.loc)
			newlight.icon_state = "tube-construct-stage[cur_stage]"

		if("bulb")
			newlight = new /obj/structure/light_construct/small(src.loc)
			newlight.icon_state = "bulb-construct-stage[cur_stage]"
	if(newlight)
		newlight.setDir(src.dir)
		newlight.stage = cur_stage
		if(!disassembled)
			newlight.obj_integrity = newlight.max_integrity * 0.5
			if(status != LIGHT_BROKEN)
				break_light_tube()
			if(status != LIGHT_EMPTY)
				drop_light_tube()
			new /obj/item/stack/cable_coil(loc, 1, "red")
		transfer_fingerprints_to(newlight)
		if(cell)
			newlight.cell = cell
			cell.forceMove(newlight)
			cell = null
	qdel(src)

/obj/machinery/light/attacked_by(obj/item/I, mob/living/user)
	..()
	if(status == LIGHT_BROKEN || status == LIGHT_EMPTY)
		if(on && (I.flags_1 & CONDUCT_1))
			if(prob(12))
				electrocute_mob(user, get_area(src), src, 0.3, TRUE)

/obj/machinery/light/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1)
	. = ..()
	if(. && !QDELETED(src))
		if(prob(damage_amount * 5))
			break_light_tube()

/obj/machinery/light/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			switch(status)
				if(LIGHT_EMPTY)
					playsound(loc, 'sound/weapons/smash.ogg', 50, 1)
				if(LIGHT_BROKEN)
					playsound(loc, 'sound/effects/hit_on_shattered_glass.ogg', 90, 1)
				else
					playsound(loc, 'sound/effects/glasshit.ogg', 90, 1)
		if(BURN)
			playsound(src.loc, 'sound/items/welder.ogg', 100, 1)

// returns if the light has power /but/ is manually turned off
// if a light is turned off, it won't activate emergency power
/obj/machinery/light/proc/turned_off()
	var/area/A = get_area(src)
	return !A.lightswitch && A.power_light || flickering

// returns whether this light has power
// true if area has power and lightswitch is on
/obj/machinery/light/proc/has_power()
	var/area/A = get_area(src)
	return A.lightswitch && A.power_light

// returns whether this light has emergency power
// can also return if it has access to a certain amount of that power
/obj/machinery/light/proc/has_emergency_power(pwr)
	if(no_emergency || !cell)
		return FALSE
	if(pwr ? cell.charge >= pwr : cell.charge)
		return status == LIGHT_OK

// attempts to use power from the installed emergency cell, returns true if it does and false if it doesn't
/obj/machinery/light/proc/use_emergency_power(pwr = LIGHT_EMERGENCY_POWER_USE)
	if(!has_emergency_power(pwr))
		return FALSE
	if(cell.charge > 300) //it's meant to handle 120 W, ya doofus
		visible_message("<span class='warning'>[src] short-circuits from too powerful of a power cell!</span>")
		burn_out()
		return FALSE
	cell.use(pwr)
	return TRUE

/obj/machinery/light/proc/flicker(var/amount = rand(10, 20))
	set waitfor = 0
	if(flickering)
		return
	flickering = 1
	if(on && status == LIGHT_OK)
		for(var/i = 0; i < amount; i++)
			if(status != LIGHT_OK || QDELETED(src))
				break
			on = !on
			update(0)
			sleep(rand(5, 15))
		on = (status == LIGHT_OK)
		update(0)
	flickering = 0

// ai attack - make lights flicker, because why not

/obj/machinery/light/attack_ai(mob/user)
	no_emergency = !no_emergency
	to_chat(user, "<span class='notice'>Emergency lights for this fixture have been [no_emergency ? "disabled" : "enabled"].</span>")
	update(FALSE)
	return

// attack with hand - remove tube/bulb
// if hands aren't protected and the light is on, burn the player

/obj/machinery/light/attack_hand(mob/living/carbon/human/user)
	. = ..()
	if(.)
		return
	user.changeNext_move(CLICK_CD_MELEE)
	add_fingerprint(user)

	if(status == LIGHT_EMPTY)
		to_chat(user, "There is no [fitting] in this light.")
		return

	// make it burn hands if not wearing fire-insulated gloves
	if(on)
		var/prot = 0
		var/mob/living/carbon/human/H = user

		if(istype(H))

			if(H.gloves)
				var/obj/item/clothing/gloves/G = H.gloves
				if(G.max_heat_protection_temperature)
					prot = (G.max_heat_protection_temperature > 360)
		else
			prot = 1

		if(prot > 0)
			to_chat(user, "<span class='notice'>You remove the light [fitting].</span>")
		else if(istype(H) && H.dna.check_mutation(TK))
			to_chat(user, "<span class='notice'>You telekinetically remove the light [fitting].</span>")
		else
			to_chat(user, "<span class='warning'>You try to remove the light [fitting], but you burn your hand on it!</span>")

			var/obj/item/bodypart/affecting = H.get_bodypart("[(user.active_hand_index % 2 == 0) ? "r" : "l" ]_arm")
			if(affecting && affecting.receive_damage( 0, 5 ))		// 5 burn damage
				H.update_damage_overlays()
			return				// if burned, don't remove the light
	else
		to_chat(user, "<span class='notice'>You remove the light [fitting].</span>")
	// create a light tube/bulb item and put it in the user's hand
	drop_light_tube(user)

/obj/machinery/light/proc/drop_light_tube(mob/user)
	if(!ispath(light_type) || QDELETED(src))
		return

	if(status == LIGHT_EMPTY) //There's no tube/bulb in it already?
		return

	var/obj/item/light/L = new light_type(loc)
	if(!istype(L))
		qdel(L)
		return 0

	L.status = status
	L.rigged = rigged
	L.brightness = brightness

	// light item inherits the switchcount, then zero it
	L.switchcount = switchcount
	switchcount = 0

	L.update()
	if(user) //puts it in our active hand
		L.add_fingerprint(user)
		user.put_in_active_hand(L)
	status = LIGHT_EMPTY
	update()
	return L

/obj/machinery/light/attack_tk(mob/user)
	if(status == LIGHT_EMPTY)
		to_chat(user, "There is no [fitting] in this light.")
		return

	to_chat(user, "<span class='notice'>You telekinetically remove the light [fitting].</span>")
	// create a light tube/bulb item and put it in the user's hand
	var/obj/item/light/L = drop_light_tube()
	L.attack_tk(user)


// break the light and make sparks if was on

/obj/machinery/light/proc/break_light_tube(skip_sound_and_sparks = 0)
	if(QDELETED(src) || !isturf(src.loc)) //Make sure we haven't actually been eaten or are in a weird place
		return

	if(status == LIGHT_EMPTY || status == LIGHT_BROKEN) //Already broken idiot
		return

	if(!skip_sound_and_sparks)
		if(status == LIGHT_OK || status == LIGHT_BURNED)
			playsound(src.loc, 'sound/effects/glasshit.ogg', 75, 1)
		if(on)
			do_sparks(3, TRUE, src)
	status = LIGHT_BROKEN
	update()

/obj/machinery/light/proc/fix()
	if(status == LIGHT_OK)
		return
	status = LIGHT_OK
//	brightness = initial(brightness) //This is done in update
	on = TRUE
	update()

/obj/machinery/light/tesla_act(power, tesla_flags)
	if(tesla_flags & TESLA_MACHINE_EXPLOSIVE)
		explosion(src,0,0,0,flame_range = 5, adminlog = 0)
		qdel(src)
	else
		return ..()

// called when area power state changes
/obj/machinery/light/power_change()
	var/area/A = get_area(src)
	seton(A.lightswitch && A.power_light)

// called when on fire

/obj/machinery/light/temperature_expose(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	if(prob(max(0, exposed_temperature - 673)))   //0% at <400C, 100% at >500C
		break_light_tube()

// explode the light

/obj/machinery/light/proc/explode()
	set waitfor = 0
	var/turf/T = get_turf(src.loc)
	break_light_tube()	// break it first to give a warning
	sleep(2)
	explosion(T, 0, 0, 2, 2)
	if(!QDELETED(src))
		qdel(src) //Make sure we got deleted

// the light item
// can be tube or bulb subtypes
// will fit into empty /obj/machinery/light of the corresponding type

/obj/item/light
	icon = 'icons/obj/lighting.dmi'
	force = 2
	throwforce = 5
	w_class = WEIGHT_CLASS_TINY
	var/status = LIGHT_OK		// LIGHT_OK, LIGHT_BURNED or LIGHT_BROKEN
	var/base_state
	var/switchcount = 0	// number of times switched
	materials = list(MAT_GLASS=100)
	grind_results = list("silicon" = 5, "nitrogen" = 10) //Nitrogen is used as a cheaper alternative to argon in incandescent lighbulbs
	var/rigged = 0		// true if rigged to explode
	var/brightness = 2 //how much light it gives off

/obj/item/light/suicide_act(mob/living/carbon/user)
	if (status == LIGHT_BROKEN)
		user.visible_message("<span class='suicide'>[user] begins to stab [user.p_them()]self with \the [src]! It looks like [user.p_theyre()] trying to commit suicide!</span>")
		return BRUTELOSS
	else
		user.visible_message("<span class='suicide'>[user] begins to eat \the [src]! It looks like [user.p_theyre()] not very bright!</span>")
		shatter()
		return BRUTELOSS

/obj/item/light/tube
	name = "light tube"
	desc = "A replacement light tube."
	icon_state = "ltube"
	base_state = "ltube"
	item_state = "c_tube"
	brightness = 8

/obj/item/light/tube/broken
	status = LIGHT_BROKEN

/obj/item/light/bulb
	name = "light bulb"
	desc = "A replacement light bulb."
	icon_state = "lbulb"
	base_state = "lbulb"
	item_state = "contvapour"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	brightness = 4

/obj/item/light/bulb/broken
	status = LIGHT_BROKEN

/obj/item/light/throw_impact(atom/hit_atom)
	if(!..()) //not caught by a mob
		shatter()

// update the icon state and description of the light

/obj/item/light/proc/update()
	switch(status)
		if(LIGHT_OK)
			icon_state = base_state
			desc = "A replacement [name]."
		if(LIGHT_BURNED)
			icon_state = "[base_state]-burned"
			desc = "A burnt-out [name]."
		if(LIGHT_BROKEN)
			icon_state = "[base_state]-broken"
			desc = "A broken [name]."


/obj/item/light/Initialize()
	. = ..()
	update()


// attack bulb/tube with object
// if a syringe, can inject plasma to make it explode
/obj/item/light/attackby(obj/item/I, mob/user, params)
	..()
	if(istype(I, /obj/item/reagent_containers/syringe))
		var/obj/item/reagent_containers/syringe/S = I

		to_chat(user, "<span class='notice'>You inject the solution into \the [src].</span>")

		if(S.reagents.has_reagent("plasma", 5))

			rigged = 1

		S.reagents.clear_reagents()
	else
		..()
	return

/obj/item/light/attack(mob/living/M, mob/living/user, def_zone)
	..()
	shatter()

/obj/item/light/attack_obj(obj/O, mob/living/user)
	..()
	shatter()

/obj/item/light/proc/shatter()
	if(status == LIGHT_OK || status == LIGHT_BURNED)
		visible_message("<span class='danger'>[src] shatters.</span>","<span class='italics'>You hear a small glass object shatter.</span>")
		status = LIGHT_BROKEN
		force = 5
		playsound(src.loc, 'sound/effects/glasshit.ogg', 75, 1)
		update()


/obj/machinery/light/floor
	name = "floor light"
	icon = 'icons/obj/lighting.dmi'
	base_state = "floor"		// base description and icon_state
	icon_state = "floor"
	brightness = 4
	layer = 2.5
	light_type = /obj/item/light/bulb
	fitting = "bulb"

//F13 EDIT
/obj/machinery/light/lampost
	name = "light post"
	icon = 'icons/obj/f13lamppost.dmi'
	icon_state = "lamppost0"
	base_state = "lamppost1"
	desc = "a post supporting a usually outdoor lamp or lantern."
	brightness = 8
	active_power_usage = 5
	density = 0
	layer = WALL_OBJ_LAYER
	nightshift_allowed = FALSE
	start_with_cell = TRUE
	no_emergency = TRUE

/obj/machinery/light/proc/night_update() //gah, cant have procs with same name from parent
	var/time = station_time()
	var/night_time = (time < nightshift_end_time) || (time > nightshift_start_time)
	if(night_time)	//night
		nightshift_active = TRUE
		on = TRUE
		update(FALSE)

	if(nightshift_active != night_time) //d a y
		nightshift_active = FALSE
		on = FALSE
		update(FALSE)

/obj/machinery/light/lampost/process()
	. = ..()
	night_update()

//F13 COLORED LIGHTS
/obj/machinery/light/fo13colored/Pink
	name = "Arcade Light"
	icon = 'icons/obj/lighting.dmi'
	icon_state = "tube"
	desc = "A lighting fixture with pink lighting."
	nightshift_allowed = FALSE
	no_emergency = TRUE
	brightness = 5
	density = 0
	layer = WALL_OBJ_LAYER
	bulb_colour = "#FF5ABF"
	light_color = "#FF00FF"

/obj/machinery/light/fo13colored/Aqua
	name = "Novelty Store Light"
	icon = 'icons/obj/lighting.dmi'
	icon_state = "tube"
	desc = "A lighting fixture with green lighting."
	nightshift_allowed = FALSE
	no_emergency = TRUE
	brightness = 5
	density = 0
	layer = WALL_OBJ_LAYER
	bulb_colour = "#00FFFF"
	light_color = "#00FFFF"

/obj/machinery/light/fo13colored/Red
	name = "Red Light"
	icon = 'icons/obj/lighting.dmi'
	icon_state = "tube"
	desc = "A lighting fixture with red lighting."
	nightshift_allowed = FALSE
	no_emergency = TRUE
	brightness = 4
	density = 0
	layer = WALL_OBJ_LAYER
	bulb_colour = "#8B0000"
	light_color = "#FF0000"

//Flickering Ported From Hippiestation. credits to yoyobatty
/obj/machinery/light/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1)
	. = ..()
	if(. && !QDELETED(src))
		if(prob(damage_amount * 10))
			flicker(damage_amount*rand(1,3))

/obj/machinery/light/flicker(var/amount = rand(10, 20))
	set waitfor = 0
	if(flickering)
		return
	flickering = TRUE
	if(on && status == LIGHT_OK)
		visible_message("<span class='warning'>[src] begins flickering!</span>","<span class='italics'>You hear an electrical sparking.</span>")
		for(var/i = 0; i < amount; i++)
			if(status != LIGHT_OK)
				break
			on = !on
			if(prob(18) && !on)//only spark when off so it doesn't occur too much
				do_sparks(1, FALSE, src)
			else if(prob(40))
				bulb_colour = LIGHT_COLOR_BROWN
				playsound(src, pick('sound/effects/sparks1.ogg', 'sound/effects/sparks2.ogg', 'sound/effects/sparks3.ogg', 'sound/effects/sparks4.ogg', 'sound/effects/light_flicker.ogg'), 100, 1)
			update(FALSE)
			sleep(rand(1, 5))
		on = (status == LIGHT_OK)
		bulb_colour = initial(bulb_colour)
		update(FALSE)
	flickering = FALSE
