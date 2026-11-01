#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;

/*##############################################################################
                              Split timer
##############################################################################*/
// O-Prac's segment timer for any map (origins_menu\segmentutil.gsc still has its
// own copy, shared_segment_timer). The map waits for each split and calls
// practice_split; this file only draws:
//   - one row per split reached, with the run time (game_time_string) it was
//     reached at;
//   - a live row below it for the next split;
//   - optionally a segment timer at the top, shown from the first split that
//     starts a segment and restarted by each one (a map that never passes
//     starts_segment, like Mob, has none).
// With clock_start, the run clock starts at the first split: clock_start sets
// level.game_start_time (a practice start time), then the live row appears.
// Without it, the run clock is already running and the live row starts at once.
practice_splits_start(labels, first, clock_start)
{
    level.split_labels = labels;
    level.split_next = first;
    level.split_row = 0;
    level.split_clock_start = clock_start;
    level thread practice_splits_end();

    if(!isdefined(clock_start)) level thread practice_splits_running();
}

// Records split index (into labels) at the current run time.
practice_split(index, starts_segment)
{
    first = !isdefined(level.split_running);
    if(first && isdefined(level.split_clock_start)) [[ level.split_clock_start ]]();

    // A hidden split (Timer menu) gets no row; see split_shown.
    if(split_shown(index))
    {
        hud = createServerFontString("default", 1.4);
        hud.sort = 2000;
        hud.hidewheninmenu = 0;
        hud setpoint("TOPLEFT", "TOPLEFT", -63, 75 + level.split_row * 16);
        hud setTextUnlimited(level.split_labels[index] + game_time_string());
        timer_main_hud(hud);
        level.split_row++;
    }
    level.split_next = index + 1;

    if(is_true(starts_segment))
    {
        if(!isdefined(level.split_segment_hud))
        {
            level.split_segment_hud = createServerFontString("default", 1.3);
            level.split_segment_hud setpoint("CENTER", "TOP", 0, 0);
            level.split_segment_hud.sort = 2000;
            timer_segment_hud(level.split_segment_hud);
        }
        level.split_segment_start = gettime();
        level.split_segment_hud settimerup(0);
    }
    if(first) level thread practice_splits_running();
}

// Live time for the next split, one row below the last recorded split. Gone
// after the last split.
practice_splits_running()
{
    level endon("end_game");
    level.split_running = createServerFontString("default", 1.4);
    level.split_running.sort = 2000;
    level.split_running.hidewheninmenu = 0;
    timer_main_hud(level.split_running);
    while(level.split_next < level.split_labels.size)
    {
        level.split_running setpoint("TOPLEFT", "TOPLEFT", -63, 75 + level.split_row * 16);
        level.split_running setTextUnlimited(level.split_labels[split_next_shown(level.split_next)] + game_time_string());
        wait 0.05;
    }
    level.split_running destroy();
}

// Freezes the timers at game end.
practice_splits_end()
{
    level waittill("end_game");
    if(isdefined(level.split_running)) level.split_running destroy();
    if(!isdefined(level.split_segment_start)) return;
    level.split_segment_hud setTextUnlimited(game_time_string(1, gettime() - level.split_segment_start));
}

/*##############################################################################
                              Start time setting
##############################################################################*/
// The run time a segment start begins at (O-Prac's "Craft Time", which still
// has its own copy as shared_craft_time_*): presets every few seconds, or a
// custom minutes:seconds time. A mode describes its presets once, in its
// initialize function, BEFORE its cfg is loaded:
//
//     practice_start_time_setup("Plane Time", "6:00", "12:00", 5, "8:00");
//
// Read it as: "presets from 6:00 to 12:00, every 5 seconds, 8:00 by default".
// The saved "start_time" setting is a preset number, not a time.

practice_start_time_setup(label, first_time, last_time, step_seconds, default_time)
{
    first_seconds = practice_time_text_to_seconds(first_time);
    last_seconds = practice_time_text_to_seconds(last_time);

    level.start_time = spawnstruct();
    level.start_time.label = label;
    level.start_time.first_seconds = first_seconds;
    level.start_time.step_seconds = step_seconds;
    level.start_time.preset_count = int((last_seconds - first_seconds) / step_seconds) + 1;
    level.start_time.default_seconds = practice_time_text_to_seconds(default_time);
}

// Adds the start time settings to a mode's default cfg.
practice_start_time_defaults(settings_ar)
{
    default_seconds = level.start_time.default_seconds;
    settings_ar["start_time"] = int((default_seconds - level.start_time.first_seconds) / level.start_time.step_seconds);
    settings_ar["custom_start"] = 0;
    settings_ar["custom_start_minutes"] = int(default_seconds / 60);
    settings_ar["custom_start_seconds"] = default_seconds % 60;
    return settings_ar;
}

// The start time the player picked, in seconds.
practice_start_time_seconds()
{
    default_seconds = level.start_time.default_seconds;

    if(get_cfg_int("custom_start"))
    {
        minutes = get_cfg_int("custom_start_minutes");
        seconds = get_cfg_int("custom_start_seconds");
        if(minutes < 0 || minutes > 59) minutes = int(default_seconds / 60);
        if(seconds < 0 || seconds > 59) seconds = default_seconds % 60;
        return minutes * 60 + seconds;
    }

    preset = get_cfg_int("start_time");
    if(preset < 0 || preset >= level.start_time.preset_count) return default_seconds; // Hand-edited cfg.
    return level.start_time.first_seconds + preset * level.start_time.step_seconds;
}

// Adds "<label>" and its Custom submenu to a mode's settings menu.
practice_start_time_menu(menu)
{
    create_option(menu, level.start_time.label + ": ^3" + practice_seconds_to_time_text(practice_start_time_seconds()), ::practice_start_time_next_preset);

    custom = add_submenu(menu, "custom_start", "Custom " + level.start_time.label);
        add_cfg_toggle(custom, "Enabled", "custom_start");
        create_option(custom, "Minutes: ^3" + get_cfg_int("custom_start_minutes"), ::cfg_increment_int, "custom_start_minutes", array(0, 59));
        create_option(custom, "Seconds: ^3" + get_cfg_int("custom_start_seconds"), ::cfg_increment_int, "custom_start_seconds", array(0, 59));
}

// Menu action: turns the custom time off and moves to the next preset, back to
// the first after the last.
practice_start_time_next_preset()
{
    level.mode_cfg["custom_start"] = 0;
    self cfg_increment_int("start_time", array(0, level.start_time.preset_count - 1));
}

// Starts the run clock at the picked start time.
practice_start_time_start_clock()
{
    level.game_start_time = getTime() - practice_start_time_seconds() * 1000;
    // Phased checks (practice_check_phasing) move onto the real run's timing.
    if(isdefined(level.practice_phasing)) flag_set(level.practice_phasing.clock);
}

// "13:20" -> 800
practice_time_text_to_seconds(time_text)
{
    parts = strtok(time_text, ":");
    return int(parts[0]) * 60 + int(parts[1]);
}

// 800 -> "13:20"; 785 -> "13:05".
practice_seconds_to_time_text(total_seconds)
{
    minutes = int(total_seconds / 60);
    seconds = total_seconds % 60;
    if(seconds < 10) return minutes + ":0" + seconds;
    return minutes + ":" + seconds;
}
