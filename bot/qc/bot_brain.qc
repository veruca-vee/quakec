// bot_brain.qc -- NZ:P in-engine bot (HEXE bot v10 (native port of v8): verified aimbot)
// Runs inside PlayerPreThink: supplies the same inputs a human client
// would (angles, movement, buttons). No cheats: no health/point/damage
// edits. Off switch: console `set bot_off 1`.
//
// Why v8 exists (live evidence, v3-v7):
// - NZ:P zombies take damage through per-limb hitbox entities (head,
//   arms) parented to the zombie; the chest between them is hollow to
//   traces. Aiming at origin+26 threaded the gap: ~1 hit per magazine.
// - The head hitbox world position is origin + facing-rotated
//   head.view_ofs (see LinkZombiesHitbox in main.qc), +/-5 units.
// - A held reload button restarts W_Reload every tick and the mag
//   never fills; a human TAPS it. Fire/ADS inputs during a reload
//   cancel it (NZP dev comment in weapon_core.qc).
// So: compute the real head position, VERIFY the exact shot line with
// traceline (hit = target itself or one of its hitbox entities), fire
// only on a verified line, tap reload, and freeze all other inputs
// while a reload runs.
.float bot_next_toggle;
.float bot_pulse;
.float bot_reload_next;
void() BotBrain_Think =
{
	if (cvar("bot_off"))
		return;
	if (self.downed || self.is_spectator || self.health <= 0)
		return;

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
	self.button5 = 0;
	self.button8 = 0;

	float mag = self.weapons[0].weapon_magazine;
	float reserve = self.weapons[0].weapon_reserve;

	// Reload state machine: tap button5 once, then touch nothing
	// until the mag fills or the attempt times out.
	if (mag == 0 && reserve > 0)
	{
		self.movement = '0 0 0';
		if (time >= self.bot_reload_next)
		{
			self.button5 = 1;
			self.bot_reload_next = time + 2.5;
		}
		return;
	}
	if (self.reload_delay > time)
	{
		self.movement = '0 0 0';
		return;
	}


	if (nearest)
	{
		vector eye = self.origin + self.view_ofs;

		// Real head position: zombie origin + its facing-rotated
		// head hitbox offset (LinkZombiesHitbox math).
		makevectors(nearest.angles);
		vector hoff = (v_right * nearest.head.view_ofs_x)
		            + (v_forward * nearest.head.view_ofs_y)
		            + (v_up * nearest.head.view_ofs_z);
		vector headpos = nearest.origin + hoff;
		vector chestpos = nearest.origin + (v_forward * 8) + '0 0 4';

		// Verify candidate shot lines against the engine itself.
		vector tgt = chestpos;
		float clear = 0;
		traceline(eye, headpos, FALSE, self);
		if (trace_ent == nearest || trace_ent == nearest.head ||
		    (trace_ent && trace_ent.owner == nearest))
		{
			tgt = headpos;
			clear = 1;
		}
		else
		{
			traceline(eye, chestpos, FALSE, self);
			if (trace_ent == nearest ||
			    (trace_ent && trace_ent.owner == nearest))
				clear = 1;
		}
		if (best < 60)
			clear = 1;	// point blank: swing/shoot, don't freeze

		// Aim at the verified point (or best guess when blocked)
		self.v_angle = vectoangles(tgt - eye);
		self.fixangle = TRUE;

		// Movement in local frame
		makevectors(self.v_angle);
		vector away = normalize(self.origin - nearest.origin);
		float mf = away * v_forward;
		float mr = away * v_right;
		float retreat = 0;
		if (clear && best < 72)
			retreat = 1;
		if (!clear && best < 130)
			retreat = 1;
		if (mag == 0)
			retreat = 1;	// gun dry: kite, don't stand and get clawed
		if (retreat)
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

		// Knife range (Vee's rules: finish with the knife, save ammo;
		// also the only weapon left when the gun runs dry)
		if (best < 100)
		{
			self.button8 = 0;
			self.button0 = 0;
			if (time >= self.bot_next_toggle)
			{
				self.bot_pulse = !self.bot_pulse;
				self.bot_next_toggle = time + 0.25;
			}
			if (self.bot_pulse)
				self.button6 = 1;
			else
				self.button6 = 0;
			// back away between swings unless a zombie is at a
			// barricade (it cannot reach us; hold position)
			return;
		}
		self.button6 = 0;

		// Engage: ADS (spread -> 2%) + recoil-paced trigger pulses
		if (clear && best < 1200 && mag > 0)
		{
			self.button8 = 1;
			if (time >= self.recoil_delay)
			{
				if (time >= self.bot_next_toggle)
				{
					self.bot_pulse = !self.bot_pulse;
					self.bot_next_toggle = time + 0.06;
				}
				if (self.bot_pulse)
					self.button0 = 1;
			}
			else
			{
				self.bot_pulse = 0;
				self.button0 = 0;
			}
		}

		// Tactical reload: low mag, no verified shot right now
		if (reserve > 0 && mag <= 2 && !clear && time >= self.bot_reload_next)
		{
			self.button5 = 1;
			self.bot_reload_next = time + 2.5;
		}
	}
	else
	{
		self.movement = '0 0 0';
	}
};
