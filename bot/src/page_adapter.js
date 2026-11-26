// 🖤🩷 page_adapter.js — glues the reflex brain into the NZ:P web page.
// Runs IN the page (our fork's index.html loads it before begin()).
// Perception: wraps Module.print (stock index.html routes engine print to
// console.log via Module.print) and feeds BOTSTATE lines to the brain.
// Action v1: synthetic key/mouse events. Known limits (from the live test):
// pointer lock may not engage for synthetic input and fire was unverified
// in the hosted-agent browser — this adapter is for a NORMAL browser tab
// (Vee's own browser), and the QC-input route in SPEC.md supersedes it.
import { parseBotState, decide } from './brain.js';

export function installBot({ canvas, doc = document, log = () => {} }) {
  let latest = null;
  let ctx = { zone: 'spawn', ownsThompson: false, helpDoorOpen: false };
  const held = new Set();

  const key = (code, down) => {
    const type = down ? 'keydown' : 'keyup';
    if (down) held.add(code); else held.delete(code);
    doc.dispatchEvent(new KeyboardEvent(type, { code, key: code.replace('Key', '').toLowerCase(), bubbles: true }));
  };
  const setKey = (code, want) => { if (held.has(code) !== want) key(code, want); };

  function onPrint(msg) {
    const s = parseBotState(String(msg));
    if (s) { latest = s; tick(); }
  }

  function tick() {
    if (!latest) return;
    const d = decide(latest, ctx);
    // Movement: retreat = back away; otherwise hold position (camp v1).
    setKey('KeyS', !!d.retreat);
    setKey('KeyW', false);
    // Fire: mouse down while brain says fire, else up. (v1: event only;
    // canvas mousedown listeners in FTE web read button state per frame.)
    if (d.fire && !installBot._firing) {
      installBot._firing = true;
      canvas.dispatchEvent(new MouseEvent('mousedown', { button: 0, bubbles: true }));
    } else if (!d.fire && installBot._firing) {
      installBot._firing = false;
      canvas.dispatchEvent(new MouseEvent('mouseup', { button: 0, bubbles: true }));
    }
    if (d.reload) { key('KeyR', true); setTimeout(() => key('KeyR', false), 60); }
    log({ state: latest, decision: d });
    return d;
  }

  return {
    onPrint,
    tick,
    setCtx: (c) => { ctx = { ...ctx, ...c }; },
    getState: () => latest,
    stop: () => { for (const c of [...held]) key(c, false); },
  };
}

// Fork index.html hook (illustrative — applied in the fork, not here):
//   const _print = Module.print;
//   const bot = installBot({ canvas: Module.canvas });
//   Module.print = (m) => { _print(m); bot.onPrint(m); };
