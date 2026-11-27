.float bot_next_toggle;
.float bot_pulse;
.float bot_reload_next;
.float bot_mode;
.entity bot_win;
.float bot_win_next;
.vector bot_home;
.float bot_home_set;
.entity bot_tgt;
.float bot_shots;
.vector bot_lastpos;
.float bot_stuck_t;
.float bot_strafe_t;
.float bot_strafe_dir;
.float bot_tapped_dry;
.float bot_door_done;
.float bot_door_t;
// bot_export.qc -- NZ:P SSQC state export (read-only, no cheats)
// Writes nzp/data/botstate.log via FRIK_FILE. Every value goes out
// in its OWN fputs call: multi-ftos strcat collapses values on this
// VM, and bprint lines arrive shredded in the console.
float bot_export_next;
float bot_wd_deadline;
float bot_wd_last_rdly;
void(float side) W_Give_Ammo;
float(float wpn) getWeaponMag;
void() BotExport_Think =
{
	entity pl = find(world, classname, "player");
	if (!pl)
		return;
	// Reload watchdog (v12 patch for the Sep web snapshot): if a
	// reload started (reload_delay jumped into the future) but the
	// mag is still not full once reload_delay expires, the anim
	// chain dropped the grant -- deliver it with the game's own
	// W_Give_Ammo. No-op when the chain works (mag already full).
	if (pl.reload_delay > time && bot_wd_last_rdly <= time)
	{
		if (pl.weapons[0].weapon_magazine < getWeaponMag(pl.weapon) &&
		    pl.weapon != W_KAR_SCOPE && pl.weapon != W_HEADCRACKER &&
		    pl.weapon != W_TRENCH && pl.weapon != W_GUT)
			bot_wd_deadline = pl.reload_delay + 0.15;
	}
	bot_wd_last_rdly = pl.reload_delay;
	if (bot_wd_deadline && time >= bot_wd_deadline)
	{
		bot_wd_deadline = 0;
		if (pl.weapons[0].weapon_magazine < getWeaponMag(pl.weapon) &&
		    pl.weapons[0].weapon_reserve > 0)
		{
			entity keep = self;
			self = pl;
			W_Give_Ammo(S_RIGHT);
			self = keep;
		}
	}
	if (time < bot_export_next)
		return;
	bot_export_next = time + 0.25;
	// BOT DEBUG ASSIST (v14, temporary): flatten every lightstyle to
	// steady overbright so the map is easy to see while tuning.
	// Same bot_noassist gate as the FireTrace snap.
	if (cvar("bot_noassist") == 0 && time < 6)
	{
		float li = 0;
		while (li < 64)
		{
			lightstyle(li, "z");
			li = li + 1;
		}
	}
	float fh = fopen("botstate.log", FILE_APPEND);
	if (fh < 0)
		return;
	fputs(fh, "BOT t="); fputs(fh, ftos(time));
	fputs(fh, " r="); fputs(fh, ftos(rounds));
	fputs(fh, " al="); fputs(fh, ftos(Current_Zombies));
	fputs(fh, " hp="); fputs(fh, ftos(pl.health));
	fputs(fh, " pts="); fputs(fh, ftos(pl.score));
	fputs(fh, " mag="); fputs(fh, ftos(pl.weapons[0].weapon_magazine));
	fputs(fh, " res="); fputs(fh, ftos(pl.weapons[0].weapon_reserve));
	fputs(fh, " rdly="); fputs(fh, ftos(pl.reload_delay - time));
	fputs(fh, " wf="); fputs(fh, ftos(pl.weaponframe));
	fputs(fh, "/"); fputs(fh, ftos(pl.weaponframe_end));
	fputs(fh, " cfa="); fputs(fh, ftos(pl.callfuncat));
	fputs(fh, " p="); fputs(fh, ftos(pl.origin_x));
	fputs(fh, ","); fputs(fh, ftos(pl.origin_y));
	fputs(fh, ","); fputs(fh, ftos(pl.origin_z));
	fputs(fh, "\n");
	entity z = world;
	float n = 0;
	while ((z = find(z, classname, "ai_zombie")) && n < 6)
	{
		if (z.health > 0)
		{
			n = n + 1;
			vector d = pl.origin - z.origin;
			fputs(fh, "BOTZ ");
			fputs(fh, ftos(z.origin_x));
			fputs(fh, ","); fputs(fh, ftos(z.origin_y));
			fputs(fh, ","); fputs(fh, ftos(z.origin_z));
			fputs(fh, " hp="); fputs(fh, ftos(z.health));
			fputs(fh, " d="); fputs(fh, ftos(vlen(d)));
			fputs(fh, "\n");
		}
	}
	fclose(fh);
};
