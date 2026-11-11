// Io Burn ambience (region id `mesa`): the ground of a volcanic moon heard through the hull. A deep
// tidal rumble and sub drone, two hissing vents (one near on the left, one further off on the right),
// one eruption (a thud, a roar and falling debris), one rock crack with a short rumble after it, a
// vent surge, the cab's radiation counter crackling now and then (with one short flurry), and the
// armoured hauler's heavy six-cylinder engine with its turbo whine.
// render_fx.scd renders 22 s and make_loop.py crossfades the last 3 s over the first, so the loop
// is 19 s long. Every event is triggered between 3 s and 19 s (TDelay from the start), clear of the
// crossfade, so each plays once per loop at full strength. The steady tones complete whole cycles in
// 19 s (31 Hz and 31 + 1/19 for the beat, 62 Hz, the engine's 36 firings a second and its six-firing
// pattern), so the crossfade never cancels them. sclang has no operator precedence, hence the brackets.
~ambience = SynthDef(\ambience, {
	var at = { |time| TDelay.kr(Impulse.kr(0), time) };

	var swell = LFNoise2.kr([0.07, 0.09]).range(0.45, 1.0);
	var rumble = LPF.ar(BrownNoise.ar(1 ! 2), LFNoise2.kr([0.11, 0.13]).range(55, 95)) * swell * 0.32;
	var drone = (SinOsc.ar([31, 31 + (1 / 19)], 0, 0.05) + SinOsc.ar(62, 0, 0.012 ! 2)) * LFNoise2.kr(0.1).range(0.7, 1.0);

	var ventNear = HPF.ar(BPF.ar(WhiteNoise.ar(1), LFNoise2.kr(0.17).range(2600, 4200), 0.9), 900)
		* LFNoise2.kr(0.21).range(0.02, 0.085);
	var ventFar = BPF.ar(PinkNoise.ar(1), LFNoise2.kr(0.13).range(1500, 2600), 0.6) * LFNoise2.kr(0.16).range(0.015, 0.05);
	var sputter = LFNoise0.kr([13, 11]).range(0.7, 1.0);
	var surge = EnvGen.kr(Env([0, 1, 0.7, 0], [0.4, 0.9, 1.0], [2, 0, -3]), at.(15.5));
	var vents = ([ventNear + (ventFar * 0.3), (ventNear * 0.25) + ventFar] * sputter)
		+ (BPF.ar(WhiteNoise.ar(1 ! 2), [3400, 3000], 0.7) * (surge * 0.09));

	// The eruption, far off: a thud with a falling pitch, a roar that opens and closes, then debris.
	var eruptAt = at.(6.0);
	var thud = SinOsc.ar(EnvGen.kr(Env([72, 30], [1.2], -4), eruptAt)) * EnvGen.kr(Env([0, 1, 0], [0.02, 1.4], [4, -4]), eruptAt) * 0.4;
	var roarEnv = EnvGen.kr(Env([0, 1, 0.6, 0.25, 0], [0.06, 0.9, 1.6, 2.2], [4, -2, -2, -3]), eruptAt);
	var roar = LPF.ar(BrownNoise.ar(1 ! 2), EnvGen.kr(Env([500, 900, 160], [0.1, 3.5], [2, -3]), eruptAt)) * roarEnv * 0.65;
	var debrisRate = EnvGen.kr(Env([0, 30, 6, 0], [0.2, 1.5, 1.8], [2, -3, -2]), at.(6.4));
	var debris = BPF.ar(Decay2.ar(Dust.ar(debrisRate ! 2), 0.0005, 0.02) * PinkNoise.ar(1 ! 2), 1100, 1.4) * 0.45;
	var eruption = FreeVerb2.ar((roar[0] + debris[0]) + thud, (roar[1] + debris[1]) + thud, 0.35, 0.9, 0.5);

	// A rock crack close by on the right, and the short rumble it sets off.
	var crackAt = TDelay.ar(Impulse.ar(0), 12.8);
	var crackNoise = HPF.ar(WhiteNoise.ar(1), 1200) * EnvGen.kr(Env([0, 1, 0], [0.002, 0.12], [0, -6]), at.(12.8));
	var crackRing = Ringz.ar(crackAt, [820, 1340], 0.25) * 0.05;
	var crack = Pan2.ar(crackNoise * 0.22, 0.45) + crackRing;
	var aftershock = LPF.ar(BrownNoise.ar(1 ! 2), 120) * EnvGen.kr(Env([0, 1, 0], [0.3, 2.2], [2, -3]), at.(12.85)) * 0.5;

	// The radiation counter in the cab: sparse clicks that wander in rate, and one flurry at 9.6 s.
	var geigerRate = LFNoise1.kr(0.25).range(0.8, 4.5) + EnvGen.kr(Env([0, 22, 0], [0.05, 0.6], [0, -4]), at.(9.6));
	var tick = Dust.ar(geigerRate);
	var geiger = (HPF.ar(Decay2.ar(tick, 0.00008, 0.0009) * WhiteNoise.ar(1), 2500) + (Ringz.ar(tick, 3100, 0.004) * 0.3)) * 0.2;

	// The hauler: a heavy straight-six at a low idle (36 firings a second, each cylinder a little
	// different), the block's mechanical rumble, a turbo whine and a faint gear whine.
	var fire = Impulse.ar(36);
	var weight = Demand.ar(fire, 0, Dseq([1.0, 0.82, 0.93, 0.78, 0.97, 0.86], inf));
	var pulse = Decay2.ar(fire * weight, 0.002, 0.03);
	var exhaust = LPF.ar((pulse * 3).tanh, 210) + (RLPF.ar(pulse, 62, 0.35) * 0.6);
	var block = LPF.ar(BrownNoise.ar(1), 260) * 0.05;
	var whine = SinOsc.ar(2350 + LFNoise1.kr(0.4, 8), 0, 0.0035) + (BPF.ar(WhiteNoise.ar(1), 2350, 0.08) * 0.015)
		+ SinOsc.ar(410, 0, 0.0018);
	var engine = ([exhaust + block, DelayN.ar(exhaust + block, 0.01, 0.005)] * 0.16) + (whine ! 2);

	// Trimmed to sit at about the other regions' loudness (around -21 dBFS RMS); untrimmed it measured -13.7.
	Out.ar(0, (rumble + drone + vents + eruption + crack + aftershock + Pan2.ar(geiger, 0.3) + engine) * 0.55);
});
