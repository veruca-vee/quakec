// bot_brain.qc -- NZ:P in-engine bot (HEXE bot v12: Vee's routine)
// Runs inside PlayerPreThink: supplies the same inputs a human client
// would (angles, movement, buttons). No cheats: no health/point/damage
// edits. Off switch: console `set bot_off 1`.
//
// Combat core (v8-v11, live-proven on the native rig): zombies take
// damage through per-limb hitbox entities; the head hitbox world pos
// is origin + facing-rotated head.view_ofs. Every shot line is
// VERIFIED with traceline before firing. Tap reload, freeze inputs
// while a reload runs, knife inside 100 units, kite when dry.
//
// Routine layer (v12, Vee's rules, STRATEGY.md):
// - Rounds 1-2: hold a window. Pick the window zombies are coming
//   to, stand inside it, farm: round 1 = 4 body shots then knife,
//   round 2 = 8 shots then knife. No retreating from a zombie that
//   is still at the barricade (it cannot reach us).
// - Between rounds (no zombies alive): repair the nearest damaged
//   window (walk up, hold use).
// - Round 3+: free roam (v11 behavior) -- door + wall rifle are the
//   next stage.
.float bot_mode;		// 0 roam, 1 navigate, 2 at-window, 3 repair

// Navigate toward a point. Returns 1 when within stopdist.
// Sets v_angle (yaw toward dest) + forward movement; simple
// stuck detection with a strafe wiggle.
float(vector dest, float stopdist) Bot_Navigate =
{
	vector d = dest - self.origin;
	d_z = 0;
	float dist = vlen(d);
	if (dist <= stopdist)
	{
		self.movement = '0 0 0';
		self.velocity_x = 0;
		self.velocity_y = 0;
		return 1;
	}
	vector want = self.v_angle;
	want_x = 0;
	want_y = vectoyaw(d);
	want_z = 0;
	self.v_angle = want;
	self.fixangle = TRUE;
	// NOTE: .movement set in PreThink is stomped by the local
	// client's real (empty) usercmd on this listen-server rig --
	// v11/v12 "movement" never moved the player. Drive velocity
	// directly instead (knockback proves the channel works).
	vector dir = normalize(d);
	self.velocity_x = dir_x * 190;
	self.velocity_y = dir_y * 190;
	self.movement = '0 0 0';
	// stuck? barely moved while trying to
	if (time >= self.bot_stuck_t)
	{
		if (vlen(self.origin - self.bot_lastpos) < 6 &&
		    self.bot_stuck_t > 0)
		{
			self.bot_strafe_t = time + 0.6;
			self.bot_strafe_dir = -self.bot_strafe_dir;
			if (!self.bot_strafe_dir)
				self.bot_strafe_dir = 1;
		}
		self.bot_lastpos = self.origin;
		self.bot_stuck_t = time + 1.2;
	}
	if (time < self.bot_strafe_t)
	{
		makevectors(self.v_angle);
		self.velocity_x = self.velocity_x + v_right_x * self.bot_strafe_dir * 190;
		self.velocity_y = self.velocity_y + v_right_y * self.bot_strafe_dir * 190;
		self.button2 = 1;	// hop the debris while stuck
	}
	else
		self.button2 = 0;
	return 0;
};

// Stand point inside the room for a window (toward home/spawn).
vector(entity w) Bot_WindowStand =
{
	vector d = self.bot_home - w.origin;
	d_z = 0;
	d = normalize(d);
	vector s = w.origin + d * 54;
	s_z = self.origin_z;
	return s;
};

void() BotBrain_Think =
{
	if (cvar("bot_off"))
		return;
	if (self.downed || self.is_spectator || self.health <= 0)
		return;

	if (!self.bot_home_set)
	{
		self.bot_home = self.origin;
		self.bot_home_set = 1;
		self.bot_strafe_dir = 1;
	}

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
	self.button6 = 0;
	self.button7 = 0;
	self.button8 = 0;

	float mag = self.weapons[0].weapon_magazine;
	float reserve = self.weapons[0].weapon_reserve;

	// Reload state machine: tap button5 once, then touch nothing
	// until the mag fills or the attempt times out.
	if (mag == 0 && reserve > 0)
	{
		self.movement = '0 0 0';
		if (!self.bot_tapped_dry || time >= self.bot_reload_next)
		{
			self.button5 = 1;
			self.bot_tapped_dry = 1;
			self.bot_reload_next = time + 2.5;
		}
		// do not freeze to be clawed: back away from the
		// nearest zombie while the reload runs
		if (nearest && best < 200)
		{
			makevectors(self.v_angle);
			vector away2 = normalize(self.origin - nearest.origin);
			self.velocity_x = (away2 * v_forward) * 190;
			self.velocity_y = (away2 * v_right) * 190;
		}
		else
		{
			self.velocity_x = 0;
			self.velocity_y = 0;
		}
		return;
	}
	if (mag > 0)
		self.bot_tapped_dry = 0;
	if (self.reload_delay > time)
	{
		self.movement = '0 0 0';
		return;
	}

	// ============ Routine layer (Vee's rules) ============
	self.bot_mode = 0;
	float hold_position = 0;	// zombie at barricade: do not retreat
	float fire_allowed = 1;

	// Between rounds: repair the nearest damaged window.
	if (Current_Zombies == 0)
	{
		entity w = world;
		entity hurt_win = world;
		float wbest = 99999;
		while ((w = find(w, classname, "window")))
		{
			if (w.health >= 0 && w.health < 6 &&
			    vlen(w.origin - self.bot_home) < 1000)
			{
				float d = vlen(self.origin - w.origin);
				if (d < wbest) { wbest = d; hurt_win = w; }
			}
		}
		if (hurt_win)
		{
			self.bot_mode = 3;
			vector stand = hurt_win.origin +
				normalize(self.bot_home - hurt_win.origin) * 30;
			stand_z = self.origin_z;
			if (Bot_Navigate(stand, 18))
			{
				// face the window and hold use to rebuild boards
				vector fw = hurt_win.origin - self.origin;
				self.v_angle = vectoangles(fw);
				self.fixangle = TRUE;
				self.button7 = 1;
			}
			return;
		}
	}

	// Gun dry with money: go buy a wall weapon (Vee: buy a rifle).
	// The buyable entity is the buy_weapon TRIGGER (brush, linked
	// to the chalk); it needs touch + looking + use held.
	if (reserve == 0 && mag <= 3 && self.score >= 200)
	{
		entity w = world;
		entity wall = world;
		float wbest = 99999;
		while ((w = find(w, classname, "buy_weapon")))
		{
			if (w.weapon == W_KAR)
			{
				float d = vlen(self.origin - w.origin);
				if (d < wbest) { wbest = d; wall = w; }
			}
		}
		if (wall)
		{
			self.bot_mode = 4;
			// the trigger's buy box sits on its chalk (enemy)
			vector wpos = wall.origin;
			if (wall.enemy)
				wpos = wall.enemy.origin;
			vector stand = wpos +
				normalize(self.bot_home - wpos) * 18;
			stand_z = self.origin_z;
			if (Bot_Navigate(stand, 10))
			{
				vector fw = wpos - self.origin;
				self.v_angle = vectoangles(fw);
				self.fixangle = TRUE;
				self.button7 = 1;
			}
			if (!(nearest && best < 150))
				return;
		}
	}

	// Round 3+: open a door (Vee: stop holding every window,
	// let them leak through). Doors open on touch when paid.
	if (rounds >= 3 && !self.bot_door_done && self.score >= 1500)
	{
		entity dr = world;
		entity door = world;
		float dbest = 99999;
		while ((dr = find(dr, classname, "door_nzp_cost")))
		{
			vector dc = (dr.absmin + dr.absmax) * 0.5;
			float dd = vlen(dc - self.bot_home);
			if (dd < dbest) { dbest = dd; door = dr; }
		}
		if (door && dbest < 1200)
		{
			self.bot_mode = 5;
			vector dc = (door.absmin + door.absmax) * 0.5;
			vector stand = dc +
				normalize(self.bot_home - dc) * 36;
			stand_z = self.origin_z;
			if (Bot_Navigate(stand, 20))
			{
				// walk into it + hold use: both open paths
				vector fw = dc - self.origin;
				self.v_angle = vectoangles(fw);
				self.fixangle = TRUE;
				self.button7 = 1;
				makevectors(self.v_angle);
				self.velocity_x = v_forward_x * 190;
				self.velocity_y = v_forward_y * 190;
				if (!self.bot_door_t)
					self.bot_door_t = time + 4;
			}
			if (self.bot_door_t && time > self.bot_door_t)
				self.bot_door_done = 1;
			if (!(nearest && best < 150))
				return;
		}
		else
			self.bot_door_done = 1;
	}

	// Rounds 1-2: window duty.
	if (rounds <= 2 && rounds >= 1)
	{
		// (Re)pick the window zombies are heading to.
		if (!self.bot_win || time >= self.bot_win_next)
		{
			entity w = world;
			entity pick = world;
			float pickscore = 99999;
			while ((w = find(w, classname, "window")))
			{
				if (vlen(w.origin - self.bot_home) > 1000)
					continue;
				// nearest zombie to this window
				entity zz = world;
				float zd = 99999;
				while ((zz = find(zz, classname, "ai_zombie")))
				{
					if (zz.health > 0)
					{
						float d2 = vlen(zz.origin - w.origin);
						if (d2 < zd) zd = d2;
					}
				}
				float score = zd;
				// unreachable in a straight line = bad pick:
				// the Nacht debris pile eats the south windows
				vector st = w.origin +
					normalize(self.bot_home - w.origin) * 54;
				vector from = self.bot_home;
				from_z = st_z + 8;
				st_z = st_z + 8;
				traceline(from, st, TRUE, self);
				if (trace_fraction < 0.95)
					score = score + 5000;
				if (score < pickscore)
				{ pickscore = score; pick = w; }
			}
			if (pick && pick != self.bot_win)
			{
				// score of current window for comparison
				float curscore = 99999;
				if (self.bot_win)
				{
					entity zz2 = world;
					while ((zz2 = find(zz2, classname, "ai_zombie")))
					{
						if (zz2.health > 0)
						{
							float d3 = vlen(zz2.origin - self.bot_win.origin);
							if (d3 < curscore) curscore = d3;
						}
					}
				}
				if (pickscore < curscore - 150 || curscore > 900)
					self.bot_win = pick;
			}
			if (!self.bot_win && pick)
				self.bot_win = pick;
			self.bot_win_next = time + 1.0;
		}
		if (self.bot_win && self.bot_win.health == 0)
			self.bot_win = world;	// breached: fall back & kite
		if (self.bot_win)
		{
			vector stand = Bot_WindowStand(self.bot_win);
			float dstand = vlen(self.origin - stand);
			if (dstand > 26)
			{
				self.bot_mode = 1;
				Bot_Navigate(stand, 26);
				// fight back if something is already on us
				if (!(nearest && best < 150))
					return;
			}
			self.bot_mode = 2;
			self.movement = '0 0 0';
			self.velocity_x = 0;
			self.velocity_y = 0;
			// Is the nearest zombie still at the barricade?
			vector wout = nearest.origin - self.bot_win.origin;
			vector win_in = self.bot_home - self.bot_win.origin;
			if (nearest &&
			    vlen(nearest.origin - self.bot_win.origin) <= 64 &&
			    (wout * win_in) < 0)
			{
				hold_position = 1;
				// Recipe: N shots, then knife only.
				float allowed = 4;
				if (rounds == 2)
					allowed = 8;
				if (nearest != self.bot_tgt)
				{
					self.bot_tgt = nearest;
					self.bot_shots = 0;
				}
				if (self.bot_shots >= allowed)
					fire_allowed = 0;
			}
		}
	}

	// ============ Combat core (v11) ============
	if (nearest)
	{
		vector eye = self.origin + self.view_ofs;

		makevectors(nearest.angles);
		vector hoff = (v_right * nearest.head.view_ofs_x)
		            + (v_forward * nearest.head.view_ofs_y)
		            + (v_up * nearest.head.view_ofs_z);
		vector headpos = nearest.origin + hoff;
		vector chestpos = nearest.origin + (v_forward * 8) + '0 0 4';

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
			clear = 1;

		self.v_angle = vectoangles(tgt - eye);
		self.fixangle = TRUE;

		makevectors(self.v_angle);
		vector away = normalize(self.origin - nearest.origin);
		float mf = away * v_forward;
		float mr = away * v_right;
		float retreat = 0;
		if (!hold_position)
		{
			if (clear && best < 72)
				retreat = 1;
			if (!clear && best < 130)
				retreat = 1;
			if (mag == 0)
				retreat = 1;
		}
		if (self.bot_mode != 2)
		{
			self.movement = '0 0 0';
			if (retreat)
			{
				makevectors(self.v_angle);
				vector rv = v_forward * mf + v_right * mr;
				self.velocity_x = rv_x * 190;
				self.velocity_y = rv_y * 190;
			}
			else
			{
				self.velocity_x = 0;
				self.velocity_y = 0;
			}
		}

		// Knife range
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
			return;
		}
		self.button6 = 0;

		// Engage: ADS + recoil-paced trigger pulses
		if (clear && best < 1200 && mag > 0 && fire_allowed)
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
				{
					self.button0 = 1;
					if (self.bot_mode == 2 &&
					    nearest == self.bot_tgt)
						self.bot_shots = self.bot_shots + 1;
				}
			}
			else
			{
				self.bot_pulse = 0;
				self.button0 = 0;
			}
		}

		// Tactical reload
		if (reserve > 0 && mag <= 2 && !clear &&
		    time >= self.bot_reload_next)
		{
			self.button5 = 1;
			self.bot_reload_next = time + 2.5;
		}
	}
	else if (self.bot_mode == 0)
	{
		self.movement = '0 0 0';
	}
};
