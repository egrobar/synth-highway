// Tidewater ambience (region id `coast`): slow heavy swells booming against the ice shelf on
// the sea side and gurgling back through it, a deep sea bed, ice creaking and twice cracking
// (a snap, a thud and the falling "zing" a crack makes running through sheet ice), a distant
// beacon horn out over the water, a cold wind with a thin whistle, and the hover car's low
// beating hum. render_fx.scd plays this for 22 s and make_loop.py crossfades the last 3 s
// over the first, so the one-off sounds (creaks, cracks, horn) sit between 5 s and 17 s,
// clear of the seam. The main swell's period matches SURF_PERIOD in coast.gd.
~ambience = SynthDef(\ambience, {
	// One swell: a deep rising rumble, a hollow boom as it meets the ice, then a gurgling wash back.
	var swell = { |period, phase, pan, level|
		var trig = Impulse.kr(period.reciprocal, phase);
		var rise = EnvGen.kr(Env([0, 1, 0.3, 0], [period * 0.38, period * 0.12, period * 0.5], [3, -2, -3]), trig);
		var hit = EnvGen.kr(Env([0, 0, 1, 0], [period * 0.38, 0.02, 1.6], [0, 2, -5]), trig);
		var wash = EnvGen.kr(Env([0, 0, 1, 0], [period * 0.42, period * 0.1, period * 0.45], [0, 1, -3]), trig);
		var body = LPF.ar(BrownNoise.ar, 90 + (rise * 260)) * rise * 0.7;
		var boomPitch = EnvGen.kr(Env([62, 62, 36], [period * 0.38, 0.9], [0, -4]), trig);
		var boom = ((SinOsc.ar(boomPitch) * 0.6) + (LPF.ar(PinkNoise.ar, 480) * 0.45)) * hit;
		var slosh = BPF.ar(BrownNoise.ar, LFNoise2.kr(3.2).range(260, 820), 0.35) * wash * LFNoise1.kr(7).range(0.3, 1.0) * 0.9;
		Pan2.ar((body + boom + slosh) * level, pan);
	};
	// Levels set by measurement: at 0.8 / 0.5 / 0.3 the booms peaked at 0.93 and the bed ran at
	// twice the other regions' loudness.
	var swells = swell.(9.0, 0.0, 0.5, 0.42) + swell.(13.0, 0.45, 0.25, 0.27) + swell.(7.3, 0.7, 0.85, 0.17);
	// The open sea far out never quite stops moving.
	var bed = LPF.ar(BrownNoise.ar(0.09), LFNoise2.kr(0.09).range(120, 260)) ! 2;

	// Ice creaking under the strain: a gliding train of clicks through a few resonances.
	var creak = { |at, len, f1, f2, rate0, rate1, amp, pan|
		var env = EnvGen.kr(Env([0, 0, 1, 1, 0], [at, len * 0.15, len * 0.6, len * 0.25], [0, 2, 0, -3]));
		var rate = EnvGen.kr(Env([rate0, rate0, rate1], [at, len], [0, 0])) * LFNoise1.kr(9).range(0.8, 1.25);
		var src = Impulse.ar(rate) + (Dust.ar(rate * 0.3) * 0.5);
		var tone = Mix(Ringz.ar(src, [f1, f2, f1 * 2.3], [0.03, 0.02, 0.012]));
		Pan2.ar(LPF.ar(tone, 3000) * env * amp, pan);
	};
	var creaks = creak.(5.6, 1.5, 410, 640, 22, 48, 0.035, -0.4) + creak.(10.4, 2.1, 300, 520, 30, 18, 0.03, 0.3)
		+ creak.(15.2, 1.2, 520, 860, 40, 70, 0.025, -0.15);

	// A crack: a snap, a crackle running away, a thud through the shelf and the falling zing.
	var crack = { |at, amp, pan, zing|
		var snap = HPF.ar(WhiteNoise.ar, 1800) * EnvGen.kr(Env([0, 0, 1, 0], [at, 0.001, 0.07], [0, 0, -6]));
		var crackle = HPF.ar(Dust2.ar(900), 2500) * EnvGen.kr(Env([0, 0, 1, 0], [at, 0.01, 0.35], [0, 0, -4]));
		var thud = SinOsc.ar(EnvGen.kr(Env([70, 70, 32], [at, 1.2], [0, -5])))
			* EnvGen.kr(Env([0, 0, 1, 0], [at, 0.005, 1.8], [0, 0, -5]));
		var chirp = SinOsc.ar(EnvGen.kr(Env([3200, 3200, 3200, 380], [at, 0.03, 0.55], [0, 0, -3])))
			* EnvGen.kr(Env([0, 0, 0, 1, 0], [at, 0.03, 0.01, 0.6], [0, 0, 0, -3])) * zing;
		Pan2.ar((snap * 0.5) + (crackle * 0.4) + (thud * 0.8) + (chirp * 0.25), pan) * amp;
	};
	var cracks = crack.(8.1, 0.16, -0.55, 1.0) + crack.(13.6, 0.09, 0.35, 0.7);
	var crackRoom = FreeVerb2.ar(cracks[0], cracks[1], 0.4, 0.85, 0.5);

	// The beacon horn far out over the water: a low two-voice blast, then a shorter one.
	var horn = { |at, len, amp|
		var env = EnvGen.kr(Env([0, 0, 1, 1, 0], [at, 0.35, len, 1.2], [0, 2, 0, -3]));
		var f = 92 * EnvGen.kr(Env([0.97, 0.97, 1.0], [at, 0.4], [0, 2]));
		LPF.ar(Mix([Saw.ar(f), Saw.ar(f * 1.5) * 0.6, Saw.ar(f * 1.006) * 0.8]), 520) * env * amp;
	};
	var horns = LPF.ar(horn.(8.9, 1.8, 1.0) + horn.(11.6, 1.0, 0.8), 700) * 0.04;
	var hornFar = Pan2.ar(FreeVerb.ar(horns, 0.55, 0.9, 0.6), 0.55);

	// Cold wind off the ice, wider than the swell, with a thin whistle drifting in and out.
	var wind = [BPF.ar(PinkNoise.ar, LFNoise2.kr(0.07).range(350, 900), 0.5),
		BPF.ar(PinkNoise.ar, LFNoise2.kr(0.08).range(330, 850), 0.5)] * LFNoise2.kr(0.11).range(0.025, 0.07);
	var whistle = [BPF.ar(WhiteNoise.ar, LFNoise2.kr(0.15).range(1500, 2300), 0.02),
		BPF.ar(WhiteNoise.ar, LFNoise2.kr(0.13).range(1450, 2200), 0.02)] * LFNoise2.kr(0.2).range(0.0, 0.18);

	// The hover car: two close low tones beating slowly, an octave above, a faint whine and fan air.
	var hum = (SinOsc.ar(55) * 0.5) + (SinOsc.ar(55.6) * 0.3) + (SinOsc.ar(110.4) * 0.22)
		+ (SinOsc.ar(331) * 0.04 * LFNoise2.kr(0.5).range(0.3, 1.0));
	var fans = LPF.ar(BrownNoise.ar, 240) * LFNoise2.kr(0.4).range(0.4, 0.7);
	var car = ((hum + fans) * 0.05) ! 2;
	Out.ar(0, swells + bed + creaks + crackRoom + hornFar + wind + whistle + car);
});
