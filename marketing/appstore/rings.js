// Extends the app's thumb arcs out of the phone and across the panel.
// Geometry mirrors ArcLayout in iPhoneApp/ArcRemoteView.swift: the pivot sits
// just outside the bottom corner on the holding side, and the rows sit at
// 0.70 / 1.08 / 1.315 screen widths from it.
(function () {
  const NS = 'http://www.w3.org/2000/svg';
  const PHI = 1.618034;
  const INNER = 0.70, OUTER = 1.08;
  const TIMER = OUTER + (OUTER - INNER) / PHI;
  // Past the timer arc the gaps grow back out by φ
  const FAR = [TIMER + 0.38, TIMER + 0.38 + 0.615, TIMER + 0.38 + 0.615 + 0.995];

  const el = (name, attrs) => {
    const node = document.createElementNS(NS, name);
    for (const key in attrs) node.setAttribute(key, attrs[key]);
    return node;
  };

  // ?p=3 shows only panel 3, at exact size, for rendering
  const only = new URLSearchParams(location.search).get('p');
  const panels = [...document.querySelectorAll('.panel')];
  if (only) {
    document.body.classList.add('single');
    panels[only - 1].classList.add('on');
  }

  for (const panel of panels) {
    const target = document.getElementById(panel.dataset.rings);
    if (!target) continue;
    const w = target.offsetWidth, x = target.offsetLeft, y = target.offsetTop;
    const centered = 'ringCenter' in panel.dataset;
    const left = target.dataset.hand === 'left';

    // Pivot in panel pixels. In a 1320 px capture it is at (1386, 2766).
    const k = w / 1320;
    const px = centered ? x + w / 2 : left ? x - 66 * k : x + 1386 * k;
    const py = centered ? y + target.offsetHeight / 2 : y + 2766 * k;
    const unit = centered ? w * 0.8 : w;
    const at = (r, deg) => {
      const a = deg * Math.PI / 180;
      return [left ? px + r * Math.cos(a) : px - r * Math.cos(a), py - r * Math.sin(a)];
    };

    const svg = el('svg', { class: 'rings', viewBox: '0 0 1320 2868', width: 1320, height: 2868 });
    for (const r of [...FAR].reverse().concat([TIMER, OUTER, INNER])) {
      svg.append(el('circle', { cx: px, cy: py, r: r * unit, fill: 'var(--band)' }));
    }
    for (const r of [INNER, OUTER, TIMER]) {
      svg.append(el('circle', { cx: px, cy: py, r: r * unit, fill: 'none', stroke: 'var(--line)', 'stroke-width': 3 }));
    }

    // Minute ticks on the timer ring, continuing the 30 the app draws on screen
    if (!centered) {
      const start = 40.8, step = (85.4 - 40.8) / 30;
      let d = '';
      for (let i = -40; i <= 110; i++) {
        const deg = start + step * i;
        const len = (i % 5 === 0 ? 13.1 : 5) * 3 * k;
        const a = at(TIMER * unit + 18 * k, deg), b = at(TIMER * unit + 18 * k + len, deg);
        d += `M${a[0].toFixed(1)} ${a[1].toFixed(1)}L${b[0].toFixed(1)} ${b[1].toFixed(1)}`;
      }
      svg.append(el('path', { d, stroke: 'var(--line)', 'stroke-width': 4, 'stroke-linecap': 'round', fill: 'none' }));
    }
    panel.prepend(svg);

    // Optional: trace the two button rows on top of the screen
    if (panel.dataset.trace) {
      const top = el('svg', { class: 'trace', viewBox: '0 0 1320 2868', width: 1320, height: 2868 });
      // Visible on the screen only, and broken where a button sits
      const mask = el('mask', { id: 'screen-' + target.id, maskUnits: 'userSpaceOnUse', x: 0, y: 0, width: 1320, height: 2868 });
      mask.append(el('rect', { x, y, width: w, height: target.offsetHeight, rx: w * 0.141, fill: '#fff' }));
      const buttons = [[INNER, 23, 0.175], [INNER, 49, 0.235], [INNER, 75, 0.175], [OUTER, 39, 0.175], [OUTER, 58, 0.175], [OUTER, 77, 0.175]];
      for (const [r, deg, diameter] of buttons) {
        const c = at(r * unit, deg);
        mask.append(el('circle', { cx: c[0], cy: c[1], r: diameter * unit / 2 + 14, fill: '#000' }));
      }
      top.append(mask);
      for (const r of [INNER, OUTER]) {
        top.append(el('circle', {
          cx: px, cy: py, r: r * unit, fill: 'none', stroke: 'var(--field)', 'stroke-width': 6,
          'stroke-dasharray': '2 22', 'stroke-linecap': 'round', mask: `url(#screen-${target.id})`,
        }));
      }
      panel.append(top);
    }
  }
})();
