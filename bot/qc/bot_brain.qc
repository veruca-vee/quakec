// bot_brain.qc -- NZ:P in-engine reflex bot (vercel / HEXE bot v1)
// Runs inside PlayerPreThink: overrides movement/buttons/angles for the
// local player using true engine state. No cheats: no health/point/damage
// edits -- it only supplies the same inputs a human client would.
// Disable any time from the console: set bot_off 1
void() BotBrain_Think =
{
	if (cvar("bot_off"))
		return;
	if (self.downed || self.is_spectator || self.health <= 0)
		return;

	// Nearest living zombie
	entity z = world;
	entity nearest = world;
	float best = 99999;
	while ((z = find(z, classname, "ai_zombie")))
	{
		if (z.health > 0)
		{
			float d = vlen(self.origin - z.origin);
			if (d < best) { best = d; nearest = z; }
		}
	}

	self.button0 = 0;
	if (nearest)
	{
		// Aim at upper chest/head from eye position
		vector eye = self.origin + self.view_ofs;
		vector tgt = nearest.origin + '0 0 26';
		self.v_angle = vectoangles(tgt - eye);
		self.fixangle = TRUE;

		// Movement in local frame (makevectors after setting angles)
		makevectors(self.v_angle);
		vector away = normalize(self.origin - nearest.origin);
		float mf = away * v_forward;
		float mr = away * v_right;
		if (best < 72)
		{
			self.movement_x = mf * 400;
			self.movement_y = mr * 400;
		}
		else
		{
			self.movement_x = 0;
			self.movement_y = 0;
		}
		self.movement_z = 0;

		// Fire: pulse the trigger (~7 Hz) so semi-autos re-trigger;
		// full-autos still burst. Game auto-reloads on empty mag.
		if (best < 1200 && self.weapons[0].weapon_magazine > 0)
		{
			if (floor(time * 7) - (floor(time * 7) / 2) * 2 == 0)
				self.button0 = 1;
		}
	}
	else
	{
		self.movement = '0 0 0';
	}
};
