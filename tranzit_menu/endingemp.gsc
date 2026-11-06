#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\utility_core\splits;
#include scripts\zm\utility_core\victis;
#include scripts\zm\tranzit_menu\tranzitutil;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              Ending EMP
##############################################################################*/
// The Richtofen ending on its own: power on, the jet gun tower step (A) and the
// tower kills (B) done, so only the lights step (C) is left. Vanilla
// richtofen_sidequest_c completes when four powered Denizen lights go out within
// 5 s of the first (EMP grenades). The player starts by the power station light
// on round 5 with the Ray Gun in hand, EMPs and every Denizen portal open (user,
// 2026-11-06) and the first kill drops the Max Ammo. Round 5 has begun by the
// release, and the run clock starts there at the Start Time setting (custom time
// only, 7:00 to 15:00). The one split, Lights, records the step's completion.
// Settings pick the next four teleports. No save slots.
//
// Setup runs frozen and invulnerable at timescale 10, with a deadline. The power
// switch is built and flipped as in a real game, so the power event runs in full
// and every light comes on (user, 2026-11-06), which the lights step needs. As
// vanilla, an EMP in the power room flips it off (zm_transit_emp_detonate).

#define ENDINGEMP_DEADLINE_MS  180000   // Setup deadline (game time).
#define ENDINGEMP_PORTAL_RANGE 96       // Start at least this far from the light: within 64 a portal takes the player.
#define ENDINGEMP_ROUND        5
#define ENDINGEMP_LIGHT        "powerstation"
#define ENDINGEMP_TELEPORTS    4
#define ENDINGEMP_ARRIVAL_MS   1500     // The fall from a light after a teleport ends within this.
#define ENDINGEMP_STEP_MS      5000     // Game time before a power step is forced.
#define ENDINGEMP_POWER_EVENT_MS 40000  // The power event takes 30 s of game time.
#define ENDINGEMP_TIME_FIRST   "7:00"   // Start Time limits (user, 2026-11-06).
#define ENDINGEMP_TIME_LAST    "15:00"
#define ENDINGEMP_TIME_DEFAULT "11:00"  // The middle, until the route's real time is known.

endingemp_initialize()
{
    flag_init("endingemp_ready");
    flag_init("endingemp_round_started");
    level.maxis_sq_intro_said = 1; // Skips sidequest_main's wait 2 and the Maxis line.
    replacefunc(maps\mp\zm_transit_sq::richtofen_sidequest, ::endingemp_richtofen_sidequest);
    replacefunc(maps\mp\zm_transit_ai_screecher::player_wait_land, ::endingemp_player_wait_land);
    tranzit_drops_install();
    tranzit_teleports_install(ENDINGEMP_TELEPORTS);
    practice_custom_time_setup(ENDINGEMP_TIME_FIRST, ENDINGEMP_TIME_LAST, ENDINGEMP_TIME_DEFAULT);
    level.mode.no_slots = true;
    mode_cfg_load("endingemp", endingemp_default_cfg());
}

endingemp_run()
{
    setdvar("timescale", SETUP_TIMESCALE); // The highest that works (user, 2026-11-06).
    level.zombie_round_start_delay = 0; // Vanilla round_start waits 2 s.
    level thread endingemp_round();
    level thread endingemp_lights_split();
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    get_players()[0] endingemp_setup();
}

endingemp_default_cfg()
{
    settings_ar = [];
    settings_ar = tranzit_drop_defaults(settings_ar);
    settings_ar = practice_custom_time_defaults(settings_ar);
    settings_ar["emp_second_gun"] = 0;  // 0 the starting pistol, 1 MP5.
    settings_ar["emp_bowie"] = 1;
    settings_ar = tranzit_teleport_defaults(settings_ar);
    return settings_ar;
}

endingemp_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        practice_custom_time_menu(settings);
        add_cfg_choice(settings, "Second Gun", "emp_second_gun", array("pistol", "MP5"));
        add_cfg_toggle(settings, "Bowie Knife", "emp_bowie");
        tranzit_drop_menu(settings);
        tranzit_teleport_menu(settings);
}

endingemp_setup()
{
    self endon("disconnect");
    deadline = gettime() + ENDINGEMP_DEADLINE_MS;
    self freezecontrols(1);
    was_demigod = is_true(self.demigod);
    if(!was_demigod) self toggle_demigod();

    self endingemp_loadout();

    level thread endingemp_open_portals();
    iprintln("Ending setup: power");
    self endingemp_power(deadline);
    while(!flag("endingemp_ready") && gettime() < deadline) wait 0.05;
    if(!flag("endingemp_ready")) iprintln("^1Setup timed out: Richtofen steps not set");

    // Placed before the round, so the zones around the player spawn its zombies.
    self endingemp_place();

    iprintln("Ending setup: round");
    while(!flag("endingemp_round_started") && gettime() < deadline) wait 0.05;
    // Full speed until the first zombie is on the map (user, 2026-11-06).
    while(!get_current_zombie_count() && gettime() < deadline) wait 0.05;

    setdvar("timescale", 1);
    endingemp_refresh_lights();
    wait 0.5; // Normal speed for 500 ms before the player can move.
    self freezecontrols(0);
    if(!was_demigod) self toggle_demigod();
    practice_custom_time_start_clock();
    practice_splits_start(array("^3Lights ^7"), 0);
    victis_max_hold();
    tranzit_release_emps_max();
    // The Max is the next drop, and this lets the first kill drop it (vanilla sets
    // this when the score passes the next drop's mark). A kill outside the playable
    // area drops nothing and the next kill tries again.
    if(get_cfg_int("emps_max")) level.zombie_vars["zombie_drop_item"] = 1;
}

// The switch built and flipped, then waits for the power event (30 s of game time)
// and for every light. Vanilla's own electricswitch and powerevent do the rest.
// Each step has a forced fallback, so a stalled step cannot leave the lights off.
endingemp_power(deadline)
{
    self endingemp_build_switch();

    trig = getent("powerswitch_buildable_trigger_power", "targetname");
    flip_deadline = gettime() + ENDINGEMP_STEP_MS;
    while(!flag("switches_on") && gettime() < flip_deadline)
    {
        trig notify("trigger", self);
        wait 0.05;
    }

    event_deadline = gettime() + ENDINGEMP_POWER_EVENT_MS;
    while(!flag("power_on") && gettime() < event_deadline) wait 0.05;
    if(!flag("power_on"))
    {
        clientnotify("pwr");
        flag_set("power_on");
    }

    lights_deadline = gettime() + ENDINGEMP_STEP_MS;
    while(!endingemp_lights_on() && gettime() < lights_deadline) wait 0.05;
    endingemp_force_lights();
}

// A lamp's client thread only reacts to the power_on notify of its clientfield, and
// one sent while the setup runs fast can pass it by, which leaves a powered lamp
// dark. Off and on again at normal speed sends it once more.
endingemp_refresh_lights()
{
    foreach(light in level.safety_lights)
        level setclientfield(light.clientfieldname, 0);
    wait 0.2;
    foreach(light in level.safety_lights)
        if(is_true(light.power_on)) level setclientfield(light.clientfieldname, 1);
}

endingemp_lights_on()
{
    foreach(light in level.safety_lights)
        if(!is_true(light.power_on)) return false;
    return true;
}

// Any light the global power missed, as vanilla change_power turns one on.
endingemp_force_lights()
{
    foreach(powered in level.powered_items)
    {
        if(!isdefined(powered.target) || !isdefined(powered.target.clientfieldname)) continue;
        if(is_true(powered.target.power_on)) continue;
        powered.power = 1;
        powered [[ powered.power_on_func ]]();
    }
}

// What finishing the last piece at the table does, with the three pieces taken off
// the map and the switch's models shown (vanilla onuseplantobject_powerswitch).
endingemp_build_switch()
{
    switch_stub = undefined;
    foreach(stub in level.buildable_stubs)
        if(isdefined(stub.equipname) && stub.equipname == "powerswitch") switch_stub = stub;
    if(!isdefined(switch_stub)) return;

    zone = switch_stub.buildablezone;
    foreach(piece in zone.pieces)
    {
        piece.built = 1;
        piece maps\mp\zombies\_zm_buildables::piece_unspawn();
    }
    foreach(part in array("hand", "body", "lever"))
        getent("powerswitch_p6_zm_buildable_pswitch_" + part, "targetname") show();

    self maps\mp\zombies\_zm_buildables::player_finish_buildable(zone);
    switch_stub maps\mp\zombies\_zm_buildables::buildablestub_remove();
    level thread maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(switch_stub);
}

// The flag goes up when the round has begun: level.round_number changes seconds
// before that, in the break before the round.
endingemp_round()
{
    practice_set_round(ENDINGEMP_ROUND);
    flag_set("endingemp_round_started");
}

// EMPs first, while the player still holds the starting pistol. The Ray Gun last, so
// it ends up in hand.
endingemp_loadout()
{
    self maps\mp\zombies\_zm_weapons::weapon_give("emp_grenade_zm", undefined, undefined, 0);
    self givemaxammo("emp_grenade_zm");
    if(get_cfg_int("emp_bowie")) self endingemp_give_bowie();
    if(get_cfg_int("emp_second_gun"))
    {
        self takeweapon(level.start_weapon);
        self maps\mp\zombies\_zm_weapons::weapon_give("mp5k_zm", undefined, undefined, 0);
    }
    self maps\mp\zombies\_zm_weapons::weapon_give("ray_gun_zm", undefined, undefined, 0);
    wait 0.05;
    self switchtoweapon("ray_gun_zm");
}

// Vanilla do_melee_weapon_flourish_end without the flourish: it waits on a weapon
// change the frozen setup should not depend on.
endingemp_give_bowie()
{
    self giveweapon("bowie_knife_zm");
    self maps\mp\zombies\_zm_melee_weapon::change_melee_weapon("bowie_knife_zm", self getcurrentweapon());
    if(self hasweapon("knife_zm")) self takeweapon("knife_zm");
    self maps\mp\zombies\_zm_melee_weapon::trigger_hide_all();
}

// Every light gets the portal a Denizen digs under it. create_portal waits for the
// dig to end (burrow_done), so that is sent once each has started. Each portal
// closes when used, as vanilla's do.
endingemp_open_portals()
{
    lights = getstructarray("screecher_escape", "targetname");
    foreach(light in lights)
        if(!is_true(light.burrow_active)) light thread maps\mp\zm_transit_ai_screecher::create_portal();
    wait 0.2;
    foreach(light in lights)
        light notify("burrow_done");
    wait 1; // The hole rises out of the ground for 1 s.
}

// On the path node nearest the start light, facing it. The spot is printed so a
// good one can be hardcoded later.
endingemp_place()
{
    light = tranzit_light(ENDINGEMP_LIGHT);
    if(!isdefined(light)) return;

    ground = groundpos(light.origin);
    nodes = getnodesinradiussorted(ground, 256, ENDINGEMP_PORTAL_RANGE, 128, "pathnodes");
    if(!nodes.size) nodes = getnodesinradiussorted(ground, 512, ENDINGEMP_PORTAL_RANGE, 128, "pathnodes");
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
    practice_split(0);
}

// OVERRIDE: maps\mp\zm_transit_ai_screecher::player_wait_land
endingemp_player_wait_land()
{
    self endon( "disconnect" );

    while ( !self isonground() )
        wait 0.1;

    if ( level.portals.size > 0 )
    {
        remove_portal = undefined;

        foreach ( portal in level.portals )
        {
            dist_sq = distance2dsquared( self.origin, portal.origin );

            if ( dist_sq < 4096 )
            {
                //MODIFIED: every light has a portal here, so the landing after a
                // teleport does not take the one at the arrival light. In vanilla
                // that would chain through all of them.
                if ( isdefined( self.tranzit_arrival_light ) && portal == self.tranzit_arrival_light && gettime() < self.tranzit_arrival_time + ENDINGEMP_ARRIVAL_MS )
                    continue;
                //MODIFIED END
                remove_portal = portal;
                break;
            }
        }

        if ( isdefined( remove_portal ) )
        {
            arrayremovevalue( level.portals, remove_portal );
            remove_portal maps\mp\zm_transit_ai_screecher::portal_use( self );
            wait 0.5;
        }
    }
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
