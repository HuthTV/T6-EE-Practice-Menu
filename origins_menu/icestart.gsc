#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Icestart
##############################################################################*/
// Round 10 with the Ice staff about to be crafted. The game runs from the black
// screen: the player can first view the Ice code (Peek Code), then is moved to
// the floor or mule start spot once the mound is open.

// Teleport spots (origin, view angles).
#define ICE_PEEK_CODE_ORIGIN  (11251, -7418.49, -403.875)
#define ICE_PEEK_CODE_ANGLES  (342.943, 53.5034, 0)
#define ICE_FLOOR_ORIGIN      (-46.571, 172.697, -751.875)
#define ICE_FLOOR_ANGLES      (11.6608, 99.3494, 0)
#define ICE_MULE_ORIGIN       (-74.8256, -400.802, -493.875)
#define ICE_MULE_ANGLES       (13.8415, 315.165, 0)

icestart_initialize()
{
    // Craft time presets: 12:30 to 14:30, every 5 seconds, 13:30 by default.
    // Custom Craft: 12 to 20 minutes.
    shared_craft_time_setup("12:30", "14:30", 5, "13:30", 12, 20);
    flag_init("icestart_setup_done");
    flag_clear("icestart_setup_done");
    flag_init("icestart_ready"); // Set when setup is done and the player is released.
    flag_clear("icestart_ready");
    puzzle_rng_install();
    mode_cfg_load("icestart", icestart_default_cfg());
    shared_segment_install(icestart_segment());
    shared_set_round(10, 1); // Install before native startup enters its callback.
}

icestart_run()
{
    level shared_run_segment(level.segment);
}

icestart_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_ICE;
    segment.gems = array(ICE);

    // Doors. R2L: the Gen 3 spawn door is open, the Gen 2 spawn door closed, and
    // Cycle 1 Foot (trench_path: 1 Gen 2, 2 Gen 3, 0 random) picks which second
    // door is open. Otherwise the doors are fixed: both Gen 3 doors closed.
    // The R2L route shows the AK chalk (unless the B23R rolls).
    if(get_cfg_int("r2l"))
    {
        trench_path = get_cfg_int("trench_path");
        if(trench_path == 0) trench_path = 1 + cointoss();
        segment.excluded_doors = array(SPAWN_GEN2);
        if(trench_path == 1) segment.excluded_doors[segment.excluded_doors.size] = GEN3;
        else                 segment.excluded_doors[segment.excluded_doors.size] = GEN2;
    }
    else
        segment.excluded_doors = array(GEN3, SPAWN_GEN3);
    segment.wallbuy_ak = get_cfg_int("r2l");
    segment.tank_trips = 2 - get_cfg_int("r2l");
    segment.leave_gramophone = !get_cfg_int("early_gram");

    segment.points_spent_claimed = false;
    segment.perks = array("specialty_longersprint");
    if(get_cfg_int("dt_start")) segment.perks[segment.perks.size] = "specialty_rof";
    segment.perks[segment.perks.size] = "specialty_armorvest";
    segment.kill_plane = get_cfg_int("kill_plane");
    segment.tablet = ::icestart_tablet;

    // Icestart's own start (Peek Code) instead of the held start. The player is
    // held from the spawn, before the black screen ends, until setup is done.
    segment.on_spawn = ::icestart_hold_controls;
    segment.start = ::icestart_start;
    segment.setup = ::icestart_setup;
    return segment;
}

icestart_setup()
{
    self shared_get_parts();
}

// on_spawn: freezes the player every frame (the vanilla intro fade unfreezes
// them) until the start spot is reached and setup is done. Not with Peek Code,
// which freezes only while the timescale is 10.
icestart_hold_controls()
{
    self endon("disconnect");
    if(get_cfg_int("peek_code")) return;

    while(self.sessionstate != "playing") wait 0.05;
    while(!flag("icestart_ready"))
    {
        self freezecontrols(1);
        wait 0.05;
    }
}

icestart_run_setup()
{
    self [[ level.segment.setup ]]();
    flag_set("icestart_setup_done");
}

// start: the game runs from the black screen. Setup, the MP40 clue and the
// teleport (after Peek Code) happen while it does.
icestart_start()
{
    setDvar("timescale", 1);
    if(get_cfg_int("cycle_tracker")) level thread shared_cycle_tracker();
    level thread icestart_auto_round_end();
    level thread shared_segment_timer(level.segment.split, ::icestart_clock_start);
    self thread icestart_run_setup();
    self thread icestart_mp40_index();
    self thread icestart_start_teleport();
    flag_wait("start_robots");
}

// Ice craft starts the run clock at the selected craft time.
icestart_clock_start()
{
    // Standard trio timing. Ice has no Trio skip setting: every Ice craft time is
    // before the round 12 trio cycle, so both columns give the same schedule.
    shared_craft_time_start_clock();
}

icestart_start_teleport()
{

    // OOPA off during the intro; in memory only, the saved setting is untouched.
    oopa_status = get_cfg_int("oopa");
    level.base_cfg["oopa"] = 0;
	self.ignoreme = 1;

    // Peek Code: view the Ice code, then fast-forward past the
    // mound opening. Otherwise teleport as soon as the mound is open.
    if(get_cfg_int("peek_code"))
    {
        //chamber TP
        self setorigin(ICE_PEEK_CODE_ORIGIN);
        self setplayerangles(ICE_PEEK_CODE_ANGLES);

        wait 5;
        self freezecontrols( 1 );
        setDvar("timescale", 10);
    }

    flag_wait( "chamber_entrance_opened" );
    if(get_cfg_int("peek_code"))
    {
        wait 15;
        setDvar("timescale", 1);
    }
    level.base_cfg["oopa"] = oopa_status;

    // Held until the setup has finished too, and only then moved (Peek Code is
    // the one start with an earlier move, to the code). A failsafe keeps a stuck
    // setup from freezing the player for good.
    setup_wait_start = gettime();
    while(!flag("icestart_setup_done") && gettime() - setup_wait_start < 60000) wait 0.05;

    // Start Location: 1 floor, 2 mule, anything else picks one at random.
    location = get_cfg_int("start_loc");
    if(location != 1 && location != 2) location = 1 + cointoss();
    switch(location)
    {
        case 1:
            self.score = 6500;
            self maps\mp\zombies\_zm_perks::give_perk("specialty_additionalprimaryweapon");
            self setorigin(ICE_FLOOR_ORIGIN);
            self setplayerangles(ICE_FLOOR_ANGLES);
            break;
        case 2:
            self.score = 11500;
            self setorigin(ICE_MULE_ORIGIN);
            self setplayerangles(ICE_MULE_ANGLES);
            break;
    }

    // Normal speed for 500 ms before the player is released.
    setDvar("timescale", 1);
    wait 0.5;
    self.ignoreme = 0;
    flag_set("icestart_ready");
    self freezecontrols( 0 );
	self.kills = 205 + randomint( 26 );
    /*
    ice ori (11284.4, -7423.93, -403.875)
    ice ang (0, 76.8332, 0)

    mule ori (-121.526, -355.118, -493.875)
    mule ang (0, -40.507, 0)

    plint ori (-57.8077, 229.805, -751.875)
    plint ang (0, 99.0413, 0)
    */
}




icestart_tablet()
{
    self.sq_one_inch_punch_stage++;
    self.sq_one_inch_punch_tablet_num = level.n_tablets_remaining;
    self setclientfieldtoplayer( "player_tablet_state", 2 );
    //self playsound( "zmb_squest_oiptablet_pickup" );
    self thread maps\mp\zm_tomb_ee_side::sq_one_inch_punch_disconnect_watch();
    self thread maps\mp\zm_tomb_ee_side::sq_one_inch_punch_death_watch();
    m_tablet = getent( "tablet_bunker_" + level.n_tablets_remaining, "targetname" );
    m_tablet delete();
    level.n_tablets_remaining--;

    self setclientfieldtoplayer( "player_tablet_state", 1 );
    self.sq_one_inch_punch_stage = 4;
    self thread maps\mp\zm_tomb_ee_side::tablet_cleanliness_thread();
}
































icestart_default_cfg()
{
	settings_ar = [];

	// Convert all set_dvar_if_unset calls to cfg defaults
	settings_ar["peek_code"] = 0; // 1: view the Ice code before the mound opens. Off by default (user, 2026-10-25).
	settings_ar["dt_start"] = 0;
	settings_ar["start_loc"] = 1; //0 random 1 floor 2 mule
	settings_ar["trench_path"] = 0; //0 random, 1 gen2, 2 gen3
	settings_ar["kill_plane"] = 1;
	settings_ar["plane_part"] = 1;
    settings_ar["r2l"] = 1;
    settings_ar["mp40_tile_clue"] = 1; // On by default (user, 2026-10-20).
    settings_ar = shared_craft_time_defaults(settings_ar);
	settings_ar["last_disc"] = 0;
	settings_ar = shared_part_defaults(settings_ar);
	settings_ar = shared_segment_item_defaults(settings_ar);
	settings_ar["headshot_reward"] = 0;
	settings_ar["early_gram"] = 1;
	settings_ar["auto_round_end"] = 1; // On by default (user, 2026-10-25).
	settings_ar["auto_round_end_delay"] = 5;

	settings_ar["panzer_2"] = 0;
	settings_ar["panzer_3"] = 0;

	settings_ar["relay_start"] = 1;
	settings_ar["relay_tank"] = 0;
	settings_ar["relay_air"] = 0;
	settings_ar["relay_elec"] = 1;
	settings_ar["relay_ruins"] = 1;
	settings_ar["relay_ice"] = 0;
	settings_ar["relay_village"] = 1;

	settings_ar = shared_templar_defaults(settings_ar);

	// Defaults use constants and do not depend on runtime label tables.
	// Preset has 17 cycles.
	for(cycle = 1; cycle <= 17; cycle++)
	{
		settings_ar["cycle_" + cycle] = ROBOT_RANDOM;
		settings_ar["foot_" + cycle] = FOOT_RANDOM;
	}


    for(scramble = 1; scramble <= 4; scramble++)
        settings_ar["disc_" + scramble] = 0;

    settings_ar["rain_foot"] = FOOT_LEFT;
    settings_ar["rain_robot"] = ROBOT_ODIN; // Rain Fire hatch robot (segment default).
    settings_ar["cycle_tracker_ms"] = 0;
    settings_ar["cycle_tracker"] = 1;

    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}

icestart_auto_round_end()
{
    while(level.n_staffs_crafted < 1) wait 0.05;
	wait get_cfg_int("auto_round_end_delay");

	if(get_cfg_int("auto_round_end") && level.round_number == 10)
	{
		zombies = getaiarray("axis");
		if(isDefined(zombies))
		{
			for(i = 0; i < zombies.size; i++)
			{
				if(isDefined(zombies[i]))
					zombies[i] dodamage(zombies[i].health + 666, zombies[i].origin);
			}
		}
	}
}

icestart_mp40_index()
{
    self endon("disconnect");
    self endon("death");
    level endon("ice_puzzle_1_complete");

    flag_wait("initial_blackscreen_passed");
    if(!get_cfg_int("mp40_tile_clue")) return;

    // The gem starts at -1; wait for the quest to select a tile.
    answer = undefined;
    while(!isdefined(answer) || !self hasweapon("mp40_zm"))
    {
        tiles = getentarray("ice_ceiling_tile", "script_noteworthy");
        gem = getent("ice_chamber_gem", "targetname");
        answer = undefined;
        if(isdefined(gem) && isdefined(gem.value) && gem.value >= 0)
        {
            foreach(tile in tiles)
                if(isdefined(tile.value) && tile.value == gem.value) answer = tile;
        }
        if(!isdefined(answer) || !self hasweapon("mp40_zm")) wait 0.05;
    }

    index = 1;
    foreach(tile in tiles) if(tile.origin[0] < answer.origin[0]) index++;

    ammo = self getweaponammoclip("mp40_zm");
    ammo = ammo - ammo % 10 + index;
    if(ammo > weaponclipsize("mp40_zm")) ammo -= 10;
    self setweaponammoclip("mp40_zm", ammo);
}


