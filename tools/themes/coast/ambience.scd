// Coast Road ambience: surf breaking and washing back in slow sets (two shorelines,
// left and right, out of step), a light sea breeze, one distant gull and one far buoy
// bell, and the convertible's soft burble. render_fx.scd plays this for 22 s and
// make_loop.py crossfades the last 3 s over the first, so the one-off sounds (gull,
// bell) sit between 5 s and 17 s, clear of the seam.
~ambience = SynthDef(\ambience, {
	// One wave: a swelling rumble, the break, then a long fizzing wash as it runs back.
	var wave = { |period, phase, pan, level|
		var trig = Impulse.kr(period.reciprocal, phase);
		var swell = EnvGen.kr(Env([0, 1, 0.25, 0], [period * 0.32, period * 0.18, period * 0.5], [3, -2, -3]), trig);
		var crash = EnvGen.kr(Env([0, 0, 1, 0.45, 0], [period * 0.3, 0.12, period * 0.12, period * 0.5], [0, 2, -3, -4]), trig);
		var body = LPF.ar(BrownNoise.ar, 180 + (swell * 420)) * swell * 0.55;
		var hiss = BPF.ar(PinkNoise.ar, 900 + (crash * 2600), 1.4) * crash * 0.5;
		var fizz = HPF.ar(WhiteNoise.ar, 3500) * Lag.kr(crash, 0.6) * LFNoise1.kr(18).range(0.2, 1.0) * 0.07;
		Pan2.ar((body + hiss + fizz) * level, pan);
	};
	var surf = wave.(6.6, 0.0, 0.45, 0.78) + wave.(8.3, 0.55, -0.35, 0.5) + wave.(11.0, 0.3, 0.75, 0.3);
	// Far surf all along the coast never quite stops.
	var bed = LPF.ar(BrownNoise.ar(0.085), LFNoise2.kr(0.11).range(220, 420)) ! 2;
	// Breeze: airy band-passed noise drifting in level and pitch, slightly wider than the surf.
	var breeze = [BPF.ar(PinkNoise.ar, LFNoise2.kr(0.09).range(500, 1100), 0.6),
		BPF.ar(PinkNoise.ar, LFNoise2.kr(0.1).range(480, 1000), 0.6)] * LFNoise2.kr(0.13).range(0.012, 0.045);
	// One gull, far off to the sea side: two falling cries, a third shorter.
	var gullEnv = { |at, len| EnvGen.kr(Env([0, 0, 1, 0.8, 0], [at, 0.04, len * 0.6, len * 0.4], [0, 2, -1, -4])) };
	var gullPitch = { |at, len, hi, lo| EnvGen.kr(Env([hi, hi, hi * 1.06, lo], [at, 0.05, len], [0, 1, -2])) };
	var cry = { |at, len, hi, lo|
		var f = gullPitch.(at, len, hi, lo);
		var src = SinOsc.ar(f) + (SinOsc.ar(f * 2) * 0.35) + (LFTri.ar(f * 3) * 0.12);
		BPF.ar(src, f * 1.5, 1.2) * gullEnv.(at, len);
	};
	var gull = Pan2.ar(LPF.ar(cry.(7.4, 0.42, 2350, 1480) + cry.(7.95, 0.38, 2300, 1420)
		+ (cry.(8.55, 0.22, 2200, 1600) * 0.7), 3800) * 0.022, 0.6);
	// A bell buoy far out, rung once by the swell, with a softer second knock.
	var bellHit = { |at, amp| EnvGen.kr(Env([0, 0, amp, 0], [at, 0.003, 4.5], [0, 0, -5])) };
	var bellTone = { |env| Mix([SinOsc.ar(392, 0, 1), SinOsc.ar(392 * 2.76, 0, 0.35), SinOsc.ar(392 * 5.4, 0, 0.12)]) * env };
	var bell = Pan2.ar(LPF.ar(bellTone.(bellHit.(12.2, 1.0)) + bellTone.(bellHit.(13.7, 0.5)), 2400) * 0.012, 0.75);
	// The convertible: a low, even burble with the firing pulse just audible.
	var fire = LFPulse.kr(39, 0, 0.35).lag(0.01);
	var engine = LPF.ar(Saw.ar(39 + LFNoise1.kr(1.7, 0.3)) + Saw.ar(39.5), 150) * (0.75 + (fire * 0.25)) * 0.045 ! 2;
	Out.ar(0, surf + bed + breeze + gull + bell + engine);
});
