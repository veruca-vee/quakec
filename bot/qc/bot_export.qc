// bot_export.qc -- NZ:P SSQC state export (read-only, no cheats) -- vercel / HEXE bot v1
float bot_export_next;
void() BotBrain_Think;
void() BotExport_Think =
{
	if (time < bot_export_next)
		return;
	bot_export_next = time + 0.1;
	entity pl = find(world, classname, "player");
	if (!pl)
		return;
	string line;
	line = strcat("BOTSTATE t=", ftos(time));
	line = strcat(line, " round=");
	line = strcat(line, ftos(rounds));
	line = strcat(line, " alive=");
	line = strcat(line, ftos(Current_Zombies));
	line = strcat(line, " hp=");
	line = strcat(line, ftos(pl.health));
	line = strcat(line, " pts=");
	line = strcat(line, ftos(pl.score));
	line = strcat(line, " mag=");
	line = strcat(line, ftos(pl.weapons[0].weapon_magazine));
	line = strcat(line, " reserve=");
	line = strcat(line, ftos(pl.weapons[0].weapon_reserve));
	line = strcat(line, " weapon=");
	line = strcat(line, GetWeaponName(pl.weapon, 0));
	line = strcat(line, " p=");
	line = strcat(line, ftos(pl.origin_x));
	line = strcat(line, ",");
	line = strcat(line, ftos(pl.origin_y));
	line = strcat(line, ",");
	line = strcat(line, ftos(pl.origin_z));
	line = strcat(line, " a=");
	line = strcat(line, ftos(pl.v_angle_x));
	line = strcat(line, ",");
	line = strcat(line, ftos(pl.v_angle_y));
	entity z = world;
	string zs = "";
	float count = 0;
	while ((z = find(z, classname, "ai_zombie")) && count < 24)
	{
		if (z.health > 0)
		{
			count = count + 1;
			vector d = pl.origin - z.origin;
			if (zs != "")
				zs = strcat(zs, ";");
			zs = strcat(zs, ftos(z.origin_x));
			zs = strcat(zs, ",");
			zs = strcat(zs, ftos(z.origin_y));
			zs = strcat(zs, ",");
			zs = strcat(zs, ftos(z.origin_z));
			zs = strcat(zs, ",");
			zs = strcat(zs, ftos(z.health));
			zs = strcat(zs, ",");
			zs = strcat(zs, ftos(vlen(d)));
		}
	}
	if (zs != "")
	{
		line = strcat(line, " z=");
		line = strcat(line, zs);
	}
	bprint(PRINT_HIGH, line);
	bprint(PRINT_HIGH, "\n");
};
