// Red Mesa ambience: gusting desert wind with a whistle in it, distant rolling thunder (one big roll
// and one faint one per loop), a lone cricket that only sometimes sings, and the muscle car's lumpy
// V8 idle. render_fx.scd renders 22 s; make_loop.py crossfades the last 3 s over the start, so the
// thunder sits between 3 s and 19 s where nothing is crossfaded away.
~ambience = SynthDef(\ambience, {
	// Wind: two independent noise beds under one slow gust envelope, plus a thin whistle on the peaks.
	var gust = LFNoise2.kr(0.13).range(0.2, 1.0).squared;
	var wind = (LPF.ar(BrownNoise.ar([0.24, 0.24]), LFNoise2.kr([0.21, 0.19]).range(240, 760))
		+ LPF.ar(PinkNoise.ar([0.06, 0.06]), 1800)) * gust;
	var whistle = BPF.ar(WhiteNoise.ar([1, 1]), LFNoise2.kr(0.23).range(620, 1150), 0.03) * gust.squared * 0.9;

	// Thunder: low rolling rumble, swelling and tumbling, far away.
	var roll = EnvGen.kr(Env([0, 0, 1, 0.5, 0.8, 0.35, 0.18, 0], [6.0, 0.35, 0.8, 0.5, 1.6, 2.0, 2.8], [0, 3, -2, 2, -2, -2, -3]));
	var faint = EnvGen.kr(Env([0, 0, 0.42, 0.2, 0], [14.2, 0.5, 1.2, 2.6], [0, 3, -2, -3]));
	var tumble = LFNoise1.kr([7, 6.3]).range(0.35, 1.0) * LFNoise2.kr(2.1).range(0.6, 1.0);
	var thunder = LPF.ar(BrownNoise.ar([1, 1]), 150) * tumble * (roll + faint) * 0.55;

	// One cricket, sparse: chirp groups that come and go on a slow cycle.
	var cricket = SinOsc.ar(4650) * Lag.kr(LFPulse.kr(31, 0, 0.45), 0.003)
		* Lag.kr(LFPulse.kr(1.15, 0, 0.17), 0.015) * Lag.kr(LFPulse.kr(0.085, 0.55, 0.3), 0.5) * 0.045;

	// V8 at a lumpy idle: four firings per crank turn, each with its own weight in an eight-beat
	// cycle (a long-duration cam), and a little rpm wander.
	var rpm = 690 * (1 + LFNoise1.kr(0.6, 0.018));
	var trig = Impulse.ar(rpm / 60 * 4);
	var weight = Demand.ar(trig, 0, Dseq([1.0, 0.58, 0.9, 0.42, 0.96, 0.66, 0.8, 0.3], inf));
	var pulse = Decay2.ar(trig * weight, 0.0015, 0.024);
	var exhaust = LPF.ar((pulse * 4).tanh, 230) + (RLPF.ar(pulse, 78, 0.3) * 0.5);
	var engine = [exhaust, DelayN.ar(exhaust, 0.01, 0.004)] * 0.1;

	Out.ar(0, wind + whistle + thunder + Pan2.ar(cricket, 0.55) + engine);
});
