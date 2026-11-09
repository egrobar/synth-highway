// Aurora Pass ambience: wind through the pines in slow gusts, a timber creak now and then, faint
// distant wind chimes (very sparse), and the snow 4x4's low diesel idle.
// render_fx.scd renders 22 s and make_loop.py crossfades the last 3 s over the start, so the rare
// sounds are timed (Impulse with a phase) to fall inside the 19 s loop: creaks at 4 s and 13.5 s,
// one breezy spell of chimes at 8 s.
~ambience = SynthDef(\ambience, {
	var gust = LFNoise2.kr(0.09).range(0.3, 1.0);
	var needles = HPF.ar(BPF.ar(PinkNoise.ar(1 ! 2), LFNoise2.kr([0.13, 0.11]).range(700, 2200), 0.8), 300) * 0.07 * gust;
	var body = LPF.ar(BrownNoise.ar(0.2 ! 2), LFNoise2.kr(0.07).range(160, 380)) * (0.45 + (gust * 0.55));
	var whistle = BPF.ar(WhiteNoise.ar(1 ! 2), LFNoise2.kr([0.05, 0.06]).range(620, 900), 0.02) * 0.05 * gust.squared;
	// A timber's stick-slip: a run of clicks through a wooden body.
	var creakEnv = EnvGen.kr(Env([0, 1, 0.6, 0], [0.35, 0.7, 0.45], \sin), Impulse.kr(1 / 9.5, 0.58));
	var clicks = Impulse.ar(LFNoise2.kr(5).range(14, 46)) * creakEnv;
	var creak = Mix(Ringz.ar(clicks, [310, 520, 870, 1340], [0.06, 0.04, 0.025, 0.015], [1, 0.6, 0.35, 0.2])) * 0.04;
	// Five chime tubes (G6 A6 C7 D7 E7), each struck at random during one short breezy spell, far off.
	var spell = EnvGen.kr(Env([0, 1, 1, 0], [0.6, 1.8, 0.8], \sin), Impulse.kr(1 / 19, 0.58));
	var chimes = Mix.fill(5, { |i|
		var freq = [1568, 1760, 2093, 2349, 2637][i];
		var hit = K2A.ar(CoinGate.kr(0.3, Impulse.kr(5.3 + (i * 0.9))) * (spell > 0.2));
		Pan2.ar(Ringz.ar(hit, freq, 2.4) + (Ringz.ar(hit, freq * 2.76, 0.7) * 0.3), (i - 2) * 0.25);
	});
	var distant = FreeVerb2.ar(chimes[0], chimes[1], 0.6, 0.92, 0.35) * 0.006;
	// The 4x4 idling: a low, lumpy diesel.
	var lump = 1 + LFNoise1.kr(7, 0.12);
	var engine = LPF.ar(Saw.ar(36 + LFNoise1.kr(1.7, 0.3)) + Pulse.ar(36.3, 0.32, 0.6), 130) * 0.05 * lump ! 2;
	Out.ar(0, needles + body + whistle + Pan2.ar(creak, -0.35) + LPF.ar(distant, 6500) + engine);
});
