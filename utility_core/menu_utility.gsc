#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm_weapons;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;

getCFG( string )
{
    return level.mode_cfg[string];
}

setCFG( string, val, write)
{
    level.mode_cfg[string] = val;
    if(write || !isdefined(write))
    write_config();
}

read_config( file_name )
{
    cfg_settings = [];

    config_handle = fs_fopen(file_name, "read");
    settings = fs_read(config_handle);

    foreach(setting in strtok(settings, "\n"))
    {
        split = strtok(setting, "=");
        cfg_settings[split[0]] = split[1];
    }

    fs_fclose(config_handle);

    return cfg_settings;
}

write_config( cfg_array, file_name )
{
    data = "";

    if(isDefined(cfg_array))
    {
        foreach(setting in getarraykeys(cfg_array))
        {
            data += setting + "=" + cfg_array[setting] + "\n";
        }
    }

    fs_remove(file_name);

    config_handle = fs_fopen(file_name, "write");
    fs_write(config_handle, data);
    fs_fclose(config_handle);
}

// Returns defaults overlaid with the saved file and creates the file on first run.
cfg_load(file_name, defaults)
{
    if(!fs_testfile(file_name))
    {
        write_config(defaults, file_name);
        return defaults;
    }

    read_cfg = read_config(file_name);
    foreach(setting in getarraykeys(read_cfg))
        defaults[setting] = read_cfg[setting];
    return defaults;
}

mode_cfg_load(name, defaults)
{
    level.mode_cfg_str = level.practice_map.cfg_dir + name + ".cfg";
    if(isDefined(level.mode.timer))
    {
        defaults["timer_main"] = 1;
        if(level.mode.timer.segment) defaults["timer_segment"] = 1;
        // Every split defaults on unless the mode's defaults say otherwise.
        for(i = level.mode.timer.first_split; i < level.practice_map.split_names.size - 1; i++)
            if(!isDefined(defaults[split_setting(i)])) defaults[split_setting(i)] = 1;
    }
    // Kept for "Restore default settings" (GSC arrays are copied on assignment).
    level.mode_cfg_defaults = defaults;
    level.mode_cfg = cfg_load(level.mode_cfg_str, defaults);
    splits_snapshot();
}

// Omit initialize and run to register a placeholder mode. build_menu(root) adds
// the mode's own menus after Practice Modes. Returns the mode, so the caller can
// add data fields to it.
register_mode(name, label, initialize, run, build_menu)
{
    mode = spawnstruct();
    mode.name = name;
    mode.label = label;
    mode.initialize = initialize;
    mode.run = run;
    mode.build_menu = build_menu;
    level.modes[level.modes.size] = mode;
    return mode;
}

/*##############################################################################
                              Timer settings
##############################################################################*/
// A mode with a run timer declares it after register_mode, and gets a Timer menu
// (build_timer_menu): main timer on/off, segment timer on/off if it has one, and
// a toggle for each split from the mode's first split on, except the last, which
// always shows. Everything defaults on unless the mode's defaults say otherwise.
//
//     mode_timer(register_mode(...), true, SPLIT_ICE);
//
// The map names its splits in run order on its practice_map (split_names for the
// settings, split_labels for the menu). The map's timer code hands its HUDs to
// timer_main_hud (split rows and the live row) and timer_segment_hud (the top
// timer), so those toggles apply at once; split toggles apply on restart.
mode_timer(mode, has_segment_timer, first_split)
{
    mode.timer = spawnstruct();
    mode.timer.segment = has_segment_timer;
    mode.timer.first_split = first_split;
    return mode.timer;
}

split_setting(index)
{
    return "split_" + level.practice_map.split_names[index];
}

// Read once with the mode cfg, so a changed split shows from the next restart.
splits_snapshot()
{
    level.split_shown = [];
    if(!isDefined(level.mode.timer)) return;
    for(i = level.mode.timer.first_split; i < level.practice_map.split_names.size - 1; i++)
        level.split_shown[i] = get_cfg_int(split_setting(i));
}

// Whether the timer draws split index. A hidden split is still waited for (the
// map's waits rely on their order) and still starts the run clock and restarts
// the segment timer; it just gets no row. The last split, and splits of modes
// that declared no timer, always show.
split_shown(index)
{
    if(!isDefined(level.split_shown) || !isDefined(level.split_shown[index])) return true;
    return level.split_shown[index];
}

// The first shown split from index on (the live row's label).
split_next_shown(index)
{
    while(index < level.practice_map.split_names.size - 1 && !split_shown(index)) index++;
    return index;
}

timer_main_hud(hud)
{
    if(!isDefined(level.timer_main_huds)) level.timer_main_huds = [];
    level.timer_main_huds[level.timer_main_huds.size] = hud;
    hud.alpha = timer_main_alpha();
}

// A timer drawn by a mode that declared none is always shown.
timer_main_alpha()
{
    if(!isDefined(level.mode.timer)) return 1;
    return get_cfg_int("timer_main");
}

timer_segment_hud(hud)
{
    level.timer_segment_hud = hud;
    timer_segment_refresh();
}

// level.timer_segment_paused: the map hides the top timer between segments.
timer_segment_refresh()
{
    if(!isDefined(level.timer_segment_hud)) return;
    if((!isDefined(level.mode.timer) || get_cfg_int("timer_segment")) && !is_true(level.timer_segment_paused))
        level.timer_segment_hud.alpha = 0.9;
    else
        level.timer_segment_hud.alpha = 0;
}

toggle_timer_main()
{
    self cfg_toggle_binary("timer_main");
    if(!isDefined(level.timer_main_huds)) return;
    foreach(hud in level.timer_main_huds)
        if(isDefined(hud)) hud.alpha = timer_main_alpha();
}

toggle_timer_segment()
{
    self cfg_toggle_binary("timer_segment");
    timer_segment_refresh();
}

mode_is_implemented(mode)
{
    return isDefined(mode.initialize) && isDefined(mode.run);
}

// Unknown names and placeholders fall back to the first registered mode.
get_mode(name)
{
    for(i = 0; i < level.modes.size; i++)
        if(level.modes[i].name == name && mode_is_implemented(level.modes[i]))
            return level.modes[i];
    return level.modes[0];
}

set_gamemode(mode)
{
    setDvar(level.practice_map.mode_dvar, mode);
    setDvar("timescale", 1);
    map_restart();
}

upgrade_weapon()
{
    baseweapon = get_base_name(self getcurrentweapon());
    weapon = get_upgrade(baseweapon);
    if(isDefined(weapon))
    {
        self takeweapon(baseweapon);
        self giveweapon(weapon, 0, self get_pack_a_punch_weapon_options(weapon));
        self switchtoweapon(weapon);
        self givemaxammo(weapon);
    }
}

get_upgrade(weapon)
{
    if(isDefined(level.zombie_weapons[weapon].upgrade_name) && isDefined(level.zombie_weapons[weapon]))
        return get_upgrade_weapon(weapon, 0 );
    else
        return get_upgrade_weapon(weapon, 1 );
}

play_sound()
{
	self playlocalSound("mus_lau_rank_up");
}

destroy_array(array)
{
	keys=getArrayKeys(array);
	for(a=0;a < keys.size;a++)
		if(isDefined(array[keys[ a ] ][0]))
			for(e=0;e < array[keys[ a ] ].size;e++)
				array[keys[ a ] ][e] destroy();
		else
			array[keys[ a ] ] destroy();
}

get_cfg_int(setting)
{
    // Check mode_cfg first (primary), then fallback to base_cfg
    if(isDefined(level.mode_cfg[setting]))
        return int(level.mode_cfg[setting]);
    else if(isDefined(level.base_cfg[setting]))
        return int(level.base_cfg[setting]);
    else
        return 0; // default fallback
}

get_cfg_float(setting)
{
    if(isDefined(level.mode_cfg[setting]))
        return float(level.mode_cfg[setting]);
    else if(isDefined(level.base_cfg[setting]))
        return float(level.base_cfg[setting]);
    else
        return 0;
}

cfgint_compare(setting, d_true, d_false)
{
    value = get_cfg_int(setting);

    if(isDefined(d_true))
    {
        if(value)   return d_true;
        else        return d_false;
    }
    else
    {
        if(value)   return "^2enabled";
        else        return "^1disabled";
    }
}

int_compare(value, d_true, d_false)
{
    if(isDefined(d_true))
    {
        if(value)   return d_true;
        else        return d_false;
    }
    else
    {
        if(value)   return "^2enabled";
        else        return "^1disabled";
    }
}

// The host's setting is the cfg's hud_speed; other players keep theirs in a dvar.
// Starts or stops the HUD at once.
cfg_toggle_speedometer()
{
    if(self isHost())
    {
        self cfg_toggle_binary("hud_speed");
        speed_on = get_cfg_int("hud_speed");
    }
    else
    {
        speed_dvar = self.name + "_speedometer";
        speed_on = 1 - int(getdvar(speed_dvar));
        setdvar(speed_dvar, speed_on);
    }

    if(speed_on)
    {
        if(!isDefined(self.speedometer))
            self thread basegame_speedometer();
    }
    else if(isDefined(self.speedometer))
    {
        self notify("kill_speedometer");
        self.speedometer destroy();
        self.speedometer = undefined;
    }
    self refresh_menu();
}

// Cheat: opens every door. A map whose doors need more than triggers sets
// level.practice_map.open_doors to replace this, or open_doors_extra to add steps.
open_all_doors()
{
    if(isDefined(level.practice_map.open_doors))
    {
        self [[ level.practice_map.open_doors ]]();
        return;
    }

    setdvar( "zombie_unlock_all", 1 );
    flag_set( "power_on" );
    players = get_players();
    zombie_doors = getentarray( "zombie_door", "targetname" );

    for ( i = 0; i < zombie_doors.size; i++ )
    {
        zombie_doors[i] notify( "trigger", players[0] );

        if ( is_true( zombie_doors[i].power_door_ignore_flag_wait ) )
            zombie_doors[i] notify( "power_on" );

        wait 0.05;
    }

    zombie_airlock_doors = getentarray( "zombie_airlock_buy", "targetname" );

    for ( i = 0; i < zombie_airlock_doors.size; i++ )
    {
        zombie_airlock_doors[i] notify( "trigger", players[0] );
        wait 0.05;
    }

    zombie_debris = getentarray( "zombie_debris", "targetname" );

    for ( i = 0; i < zombie_debris.size; i++ )
    {
        zombie_debris[i] notify( "trigger", players[0] );
        wait 0.05;
    }

    if ( isdefined( level.practice_map.open_doors_extra ) )
        players[0] [[ level.practice_map.open_doors_extra ]]();

    level notify( "open_sesame" );
    wait 1;
    setdvar( "zombie_unlock_all", 0 );
}


game_time_string(ms = 1, custom_duration)
{
    duration = 0;
    if(isDefined(custom_duration))
    {
        duration = custom_duration;
    }
    else if(isDefined(level.game_start_time))
    {
        duration = getTime() - level.game_start_time;
    }
    else
    {
        return "00:00.00";
    }

    total_sec = int(duration / 1000);
    mn = int(total_sec / 60);           //minutes
    se = total_sec % 60;                //seconds
    ce = ( int(duration) % 1000) / 10;  //centiseconds
    time_string = "";

    //minutes
    if(mn == 0)     { time_string = time_string + "00:"; }
    else if(mn > 9) { time_string = time_string + mn + ":"; }
	else            { time_string = time_string + "0" + mn + ":"; }

    //seconds
	if(se > 9)      { time_string = time_string + se; }
	else            { time_string = time_string + "0" + se; }

    if(ms)
    {
        //centiseconds
        if(ce < 10) { time_string = time_string + ".0" + ce; }
        else        { time_string = time_string + "." + ce; }
    }

	return time_string;
}

set_points( amount )
{
    self.score = amount;
}

demi_god()
{
    self endon( "disable_godmode" );

    while ( true )
    {
        if ( self.health < 999999 )
        {
            self.maxhealth = 999999;
            self.health = self.maxhealth;
        }

        wait 0.05;
    }
}

bool_compare_string(bol, a, b)
{
    if(bol) return a;
    else    return b;
}

int_in_range( val, min, max )
{
    return min <= val && max >= val;
}
