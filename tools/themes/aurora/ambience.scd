// Ring Road ambience (region id `aurora`): inside a glass skyway on an orbital ring. The station's
// calm hum, soft air handling breathing through the vents, one slow choral pad swell a loop (an open
// D chord sung on "aah", far off in a big reverb), two sparse phrases of distant chimes, and the
// transit pod's quiet maglev glide (a soft high tone and a hush of air under it).
// render_fx.scd renders 22 s and make_loop.py crossfades the last 3 s over the first, so the loop
// is 19 s long. The steady tones complete whole cycles in 19 s (hum 57 Hz and 57 + 1/19 for its slow
// beat, 114, 171; the glide 380, 760, 1140; the air's breathing 2/19 Hz and the glide's sway 3/19 Hz),
// so the crossfade never cancels them. Every event is triggered between 3 s and 16 s (TDelay from the
// start) and has died away by 19 s: the pad swells from 4 s to 16 s, the chimes fall at 5.5 s and
// 12.6 s. sclang has no operator precedence, hence the brackets around every product.
~ambience = SynthDef(\ambience, {
	var at = { |time| TDelay.kr(Impulse.kr(0), time) };

	var humLevel = LFNoise2.kr(0.08).range(0.85, 1.0);
	var hum = (SinOsc.ar([57, 57 + (1 / 19)], 0, 0.016) + SinOsc.ar(114, 0, 0.006 ! 2)
		+ SinOsc.ar(171, 0, 0.0022 ! 2)) * humLevel;
	var humAir = LPF.ar(BrownNoise.ar(0.2 ! 2), 120) * 0.12;

	var breath = SinOsc.kr(2 / 19, 0).range(0.65, 1.0);
	var air = LPF.ar(HPF.ar(PinkNoise.ar(1 ! 2), 180), LFNoise2.kr([0.09, 0.11]).range(900, 1500)) * (0.05 * breath);
	var vent = BPF.ar(WhiteNoise.ar(1 ! 2), 2400, 0.4) * (0.006 * breath);

	var swell = EnvGen.kr(Env([0, 0, 1, 1, 0], [4.0, 4.5, 2.5, 5.0], [0, 2, 0, -2]));
	var notes = [50, 57, 62, 66, 69].midicps;
	var voices = Mix.fill(5, { |i|
		var f = notes[i] * (1 + SinOsc.kr(4.7 + (i * 0.37), i, 0.0035));
		Saw.ar(f * [1, 1.004, 0.996]).sum * 0.3
	});
	var choir = Mix(BPF.ar(LPF.ar(voices, 3200), [700, 1220, 2600], [0.12, 0.1, 0.08], [1, 0.5, 0.22])) * (swell * 0.22);
	var choirWide = FreeVerb2.ar(choir, DelayN.ar(choir, 0.03, 0.017), 0.75, 0.96, 0.45);

	var chimeTimes = [5.5, 6.15, 6.9, 12.6, 13.35];
	var chimeFreqs = [1318.51, 1760.0, 1975.53, 1567.98, 2093.0];
	var chimePans = [-0.5, 0.3, -0.2, 0.5, -0.35];
	var chimes = Mix.fill(5, { |i|
		var hit = K2A.ar(at.(chimeTimes[i]));
		var tone = Ringz.ar(hit, chimeFreqs[i], 2.6) + (Ringz.ar(hit, chimeFreqs[i] * 2.76, 0.7) * 0.25);
		Pan2.ar(tone, chimePans[i])
	});
	var distant = FreeVerb2.ar(LPF.ar(chimes[0], 5500), LPF.ar(chimes[1], 5500), 0.65, 0.93, 0.4) * 0.04;

	var sway = SinOsc.kr(3 / 19, 0).range(0.8, 1.0);
	var glide = ((SinOsc.ar(380, 0, 0.004) + SinOsc.ar(760, 0, 0.0016) + SinOsc.ar(1140, 0, 0.0007)) * sway) ! 2;
	var hush = LPF.ar(BrownNoise.ar(1 ! 2), 280) * 0.05;

	// Scaled to sit near the other regions' loudness (about -22 dBFS RMS); the pad and chimes stay soft events.
	Out.ar(0, (hum + humAir + air + vent + choirWide + distant + glide + hush) * 2.2);
});
