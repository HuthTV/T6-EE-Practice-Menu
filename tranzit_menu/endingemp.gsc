#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\tranzit_menu\tranzitutil;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              Ending EMP
##############################################################################*/
// The Richtofen ending on its own: power on, the jet gun tower step (A) and the
// tower kills (B) done, so only the lights step (C) is left. Vanilla
// richtofen_sidequest_c completes when four powered Denizen lights go out within
// 5 s of the first (EMP grenades). The player starts by a light with EMPs, on
// the start round, and the clock starts at the release. "Lights" shows the time
// the step completes.
//
// Setup runs frozen and invulnerable at timescale 10, with a deadline. Power is
// turned on by its flag, as vanilla's Bus Depot mode does (the power switch stays
// unbuilt). Open: the route's real start spot and round (bus depot and 10 are
// guesses), the loadout beside the EMPs.

#define ENDINGEMP_DEADLINE_MS  180000   // Setup deadline (game time).

endingemp_initialize()
{
    flag_init("endingemp_ready");
    replacefunc(maps\mp\zm_transit_sq::richtofen_sidequest, ::endingemp_richtofen_sidequest);
    tranzit_drops_install();
    mode_cfg_load("endingemp", endingemp_default_cfg());
}

endingemp_run()
{
    setdvar("timescale", SETUP_TIMESCALE);
    level thread practice_set_round(get_cfg_int("start_round"));
    level thread endingemp_lights_split();
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    get_players()[0] endingemp_setup();
}

endingemp_default_cfg()
{
    settings_ar = [];
    settings_ar = tranzit_drop_defaults(settings_ar);
    settings_ar["start_light"] = 0;     // tranzit_light_names index: bus depot
    settings_ar["start_round"] = 10;
    return settings_ar;
}

endingemp_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Start light", "start_light", tranzit_light_labels());
        create_option(settings, "Start round: ^3" + get_cfg_int("start_round"), ::cfg_increment_int, "start_round", array(2, 30));
        tranzit_drop_menu(settings);
}

endingemp_setup()
{
    self endon("disconnect");
    deadline = gettime() + ENDINGEMP_DEADLINE_MS;
    self freezecontrols(1);
    was_demigod = is_true(self.demigod);
    if(!was_demigod) self toggle_demigod();

    // The loadout while the player still holds the starting pistol.
    self maps\mp\zombies\_zm_weapons::weapon_give("emp_grenade_zm", undefined, undefined, 0);
    self givemaxammo("emp_grenade_zm");

    iprintln("Ending setup: power");
    flag_set("power_on");
    while(!flag("endingemp_ready") && gettime() < deadline) wait 0.05;
    if(!flag("endingemp_ready")) iprintln("^1Ending setup: Richtofen steps not set (deadline)");

    iprintln("Ending setup: round");
    while(level.round_number < get_cfg_int("start_round") && gettime() < deadline)
        level waittill_notify_or_timeout("start_of_round", 1);
    self endingemp_place();

    setdvar("timescale", 1);
    wait 0.5; // Normal speed for 500 ms before the player can move.
    self freezecontrols(0);
    if(!was_demigod) self toggle_demigod();
    level.game_start_time = gettime();
    tranzit_arm_ending_max();
    iprintlnbold("^3Ending started");
}

// On the path node nearest the start light, facing it. The spot is printed so a
// good one can be hardcoded later.
endingemp_place()
{
    names = tranzit_light_names();
    light = tranzit_light(names[get_cfg_int("start_light")]);
    if(!isdefined(light)) return;

    ground = groundpos(light.origin);
    nodes = getnodesinradiussorted(ground, 256, 64, 128, "pathnodes");
    if(!nodes.size) nodes = getnodesinradiussorted(ground, 512, 64, 128, "pathnodes");
    spot = ground + (0, 0, 8);
    if(nodes.size) spot = nodes[0].origin;

    print("T-Prac: Ending EMP start at " + spot + " (light " + light.script_noteworthy + " at " + light.origin + ")");
    self setorigin(spot);
    facing = vectortoangles(ground - spot);
    self setplayerangles((0, facing[1], 0));
}

endingemp_lights_split()
{
    level endon("end_game");
    level waittill("richtofen_c_complete");
    iprintlnbold("^3Lights ^7" + game_time_string());
}

// OVERRIDE: maps\mp\zm_transit_sq::richtofen_sidequest
// Runs each time the power comes on (vanilla sidequest_main).
endingemp_richtofen_sidequest()
{
    level endon( "power_turned_off" );

    //MODIFIED: a Richtofen completion in the last game (player stat, read by
    // sidequest_main) does not block the practice.
    if ( !flag( "power_on" ) )
        return;

    level.richcompleted = 0;
    level.richtofen_sq_intro_said = 1;

    // Steps A and B done (no stats written), so only C runs.
    level.sq_progress["rich"]["A_jetgun_built"] = 1;
    level.sq_progress["rich"]["A_jetgun_tower"] = 1;
    level.sq_progress["rich"]["A_complete"] = 1;
    level.sq_progress["rich"]["B_zombies_tower"] = 0;
    level.sq_progress["rich"]["B_complete"] = 1;
    player = get_players();
    player[0] setclientfield( "screecher_sq_lights", 1 );
    level thread maps\mp\zm_transit_sq::richtofen_sidequest_c();
    flag_set( "endingemp_ready" );
    //MODIFIED END
}
