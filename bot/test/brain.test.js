// 🖤🩷 NZ:P bot brain tests — node:test, no deps
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseBotState, aimAngles, decide } from '../src/brain.js';

const LINE = 'BOTSTATE t=12.3 round=3 alive=4 hp=100 pts=1450 mag=24 reserve=96 weapon=thompson p=100,200,24 a=0,90 z=300,200,24,350,200;150,260,24,250,111';

test('S1: parses a well-formed BOTSTATE line', () => {
  const s = parseBotState(LINE);
  assert.equal(s.round, 3);
  assert.equal(s.hp, 100);
  assert.equal(s.pts, 1450);
  assert.equal(s.mag, 24);
  assert.equal(s.weapon, 'thompson');
  assert.deepEqual(s.player, { x: 100, y: 200, z: 24 });
  assert.equal(s.zombies.length, 2);
});

test('S1: returns null for other console lines', () => {
  assert.equal(parseBotState('some engine noise'), null);
  assert.equal(parseBotState(''), null);
  assert.equal(parseBotState(null), null);
});

test('S2: zombies sorted nearest-first by decide()', () => {
  const s = parseBotState(LINE);
  const d = decide(s);
  assert.equal(d.target.dist, 111);
});

test('S3: aimAngles points east target to yaw ~0, level pitch ~0', () => {
  const a = aimAngles({ x: 0, y: 0, z: 24 }, { x: 100, y: 0, z: 24 }, 0);
  assert.ok(Math.abs(a.yaw) < 0.01, `yaw=${a.yaw}`);
  assert.ok(Math.abs(a.pitch) < 0.01, `pitch=${a.pitch}`);
});

test('S3: aimAngles north target yaw ~90, head offset raises pitch', () => {
  const level = aimAngles({ x: 0, y: 0, z: 24 }, { x: 0, y: 100, z: 24 }, 0);
  assert.ok(Math.abs(level.yaw - 90) < 0.01, `yaw=${level.yaw}`);
  const head = aimAngles({ x: 0, y: 0, z: 24 }, { x: 0, y: 100, z: 24 }, 20);
  assert.ok(head.pitch < 0, 'Quake pitch is negative looking up'); // FTE/Quake: pitch down positive
});

test('S4: fires when target in range and mag > 0', () => {
  const s = parseBotState('BOTSTATE t=1 round=1 alive=1 hp=100 pts=500 mag=8 reserve=32 weapon=m1911 p=0,0,24 a=0,0 z=200,0,24,150,200');
  const d = decide(s);
  assert.equal(d.fire, true);
  assert.equal(d.reload, false);
});

test('S4: reloads on empty mag', () => {
  const s = parseBotState('BOTSTATE t=1 round=1 alive=1 hp=100 pts=500 mag=0 reserve=32 weapon=m1911 p=0,0,24 a=0,0 z=400,0,24,150,400');
  const d = decide(s);
  assert.equal(d.reload, true);
  assert.equal(d.fire, false);
});

test('S4/S5: zombie in danger range with rounds left -> retreat, no reload', () => {
  const s = parseBotState('BOTSTATE t=1 round=5 alive=3 hp=80 pts=900 mag=2 reserve=40 weapon=thompson p=0,0,24 a=0,0 z=40,0,24,550,40');
  const d = decide(s);
  assert.equal(d.reload, false);
  assert.equal(d.retreat, true);
});

test('S7: buy Thompson intent when rich, in help zone, unowned', () => {
  const s = parseBotState('BOTSTATE t=1 round=4 alive=0 hp=100 pts=1500 mag=30 reserve=90 weapon=m1a1 p=0,0,24 a=0,0');
  const d = decide(s, { zone: 'help', ownsThompson: false, helpDoorOpen: true });
  assert.equal(d.buy, 'thompson');
});

test('S7: open Help intent early when affordable and door closed', () => {
  const s = parseBotState('BOTSTATE t=1 round=2 alive=0 hp=100 pts=1100 mag=8 reserve=32 weapon=m1911 p=0,0,24 a=0,0');
  const d = decide(s, { zone: 'spawn', ownsThompson: false, helpDoorOpen: false });
  assert.equal(d.buy, 'open_help');
});

test('no zombies: no fire, no target, no retreat', () => {
  const s = parseBotState('BOTSTATE t=1 round=1 alive=0 hp=100 pts=500 mag=8 reserve=32 weapon=m1911 p=0,0,24 a=0,0');
  const d = decide(s);
  assert.equal(d.fire, false);
  assert.equal(d.target, null);
  assert.equal(d.retreat, false);
});
