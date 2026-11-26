// 🖤🩷 bot_export.qc — NZ:P SSQC state export (OUR addition, read-only)
// Merge: add to progs/ssqc.src includelist AFTER ai/zombie_core.qc,
// and call BotExport_Think() from the server per-frame path in main.qc
// (StartFrame sequence) — it self-throttles to 0.1s.
//
// Output (one line, engine console -> Module.print -> page JS):
// BOTSTATE t=.. round=.. alive=.. hp=.. pts=.. mag=.. reserve=..
//          weapon=.. p=x,y,z a=pitch,yaw z=x,y,z,hp,dist;...
//
// NO game state is written here. No cheats. Export only.
//
// Fields verified from NZ:P source (2026-11-26, plain read):
//   globals: rounds, Current_Zombies          (rounds.qc)
//   zombie classname: "ai_zombie"             (zombie_core.qc)
//   player field: .score (points)             (defs/custom.qc)
// VERIFY AT MERGE TIME (names differ across NZ:P versions):
//   player current-weapon mag/reserve accessors (weapon_core.qc /
//   weapon_stats.qc), player entity lookup (local_client / player_count
//   globals exist in defs/custom.qc), zombie .health field name.

float bot_export_next;

void() BotExport_Think =
{
	if (time < bot_export_next)
		return;
	bot_export_next = time + 0.1;

	// First player (solo v1). Co-op: loop all players, prefix p1=, p2=...
	entity pl = local_client; // VERIFY: or find(world, classname, "player")
	if (!pl)
		return;

	string line;
	line = "BOTSTATE t=";
	line = strcat(line, ftos(time));
	line = strcat(line, " round=");
	line = strcat(line, ftos(rounds));
	line = strcat(line, " alive=");
	line = strcat(line, ftos(Current_Zombies));
	line = strcat(line, " hp=");
	line = strcat(line, ftos(pl.health));
	line = strcat(line, " pts=");
	line = strcat(line, ftos(pl.score));
	// mag=/reserve=/weapon= : fill from current weapon accessors at merge.
	line = strcat(line, " p=");
	line = strcat(line, vtos(pl.origin));
	line = strcat(line, " a=");
	line = strcat(line, ftos(pl.v_angle_x));
	line = strcat(line, ",");
	line = strcat(line, ftos(pl.v_angle_y));

	entity z = world;
	string zs = "";
	float count = 0;
	while ((z = find(z, classname, "ai_zombie")) && count < 24)
	{
		if (z.health <= 0)
			continue;
		count = count + 1;
		vector d = pl.origin - z.origin;
		if (zs != "")
			zs = strcat(zs, ";");
		zs = strcat(zs, vtos(z.origin));
		zs = strcat(zs, ",");
		zs = strcat(zs, ftos(z.health));
		zs = strcat(zs, ",");
		zs = strcat(zs, ftos(vlen(d)));
	}
	if (zs != "")
	{
		line = strcat(line, " z=");
		line = strcat(line, zs);
	}
	bprint(line);
	bprint("\n");
};
