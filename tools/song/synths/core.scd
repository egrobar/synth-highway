// Core instrument library, shared by every song, every region and the MIDI importer.
// Loaded by render_score.scd, which first sets ~defs = [] and then loads every
// file in tools/song/synths/ in name order, so a region can add its own file.
//
// Contract: every instrument takes midi, sus (seconds), amp and pan, frees itself,
// and writes stereo to bus 0. Drums ignore midi and sus where they do not need them.
~defs = ~defs ++ [

	// ---------------------------------------------------------------- rhythm and harmony
	SynthDef(\pick, { |midi=60, sus=1.6, amp=0.2, pan=0|
		var freq = midi.midicps;
		var exc = PinkNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.012));
		var sig = Pluck.ar(exc, Impulse.ar(0), 0.05, freq.reciprocal, sus, 0.32);
		sig = HPF.ar(LPF.ar(sig, (freq * 7).clip(900, 7500)), 90) * amp * 3.2;
		Line.kr(1, 1, sus + 0.15, doneAction: 2);
		Out.ar(0, Pan2.ar(sig, pan));
	}),
	SynthDef(\bass, { |midi=36, sus=0.5, amp=0.5, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env([0, 1, 0.55, 0], [0.006, sus, 0.09], [\lin, -2, -3]), doneAction: 2);
		var sig = SinOsc.ar(freq) + (LFTri.ar(freq * 2) * 0.28) + (Pulse.ar(freq, 0.4) * 0.1);
		Out.ar(0, Pan2.ar(LPF.ar(sig, 900) * env * amp, pan));
	}),
	SynthDef(\synthbass, { |midi=36, sus=0.3, amp=0.4, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env([0, 1, 0.7, 0], [0.004, sus, 0.06], [\lin, -2, -4]), doneAction: 2);
		var cutoff = EnvGen.kr(Env([freq * 14, freq * 3], [0.18], -4)).clip(80, 9000);
		var sig = RLPF.ar(Saw.ar(freq) + Pulse.ar(freq * 0.5, 0.45, 0.6), cutoff, 0.35);
		Out.ar(0, Pan2.ar(sig.tanh * env * amp * 0.6, pan));
	}),
	SynthDef(\organ, { |midi=60, sus=2, amp=0.1, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env.linen(0.22, sus, 0.3), doneAction: 2);
		var trem = 1 + (SinOsc.kr(5.4) * 0.08);
		var sig = SinOsc.ar(freq) + (SinOsc.ar(freq * 2) * 0.45) + (SinOsc.ar(freq * 3) * 0.16);
		Out.ar(0, Pan2.ar(sig * env * trem * amp, pan));
	}),
	// Piano: inharmonic partials that each decay at their own rate, plus a felt thump.
	SynthDef(\piano, { |midi=60, sus=1, amp=0.3, pan=0|
		var freq = midi.midicps;
		var hold = EnvGen.ar(Env([1, 1, 0], [sus, 0.22], [0, -4]), doneAction: 2);
		var sig = Mix.fill(7, { |i|
			var n = i + 1;
			var partial = freq * n * (1 + (0.0004 * n * n)).sqrt;
			SinOsc.ar(partial, 0, 1 / (n ** 1.25)) * EnvGen.ar(Env.perc(0.002, (3.6 - (midi / 40)).max(0.6) / n.sqrt));
		});
		var thump = LPF.ar(WhiteNoise.ar, freq * 3) * EnvGen.ar(Env.perc(0.001, 0.02)) * 0.2;
		Out.ar(0, Pan2.ar((sig + thump) * hold * amp * 0.5, pan));
	}),
	SynthDef(\epiano, { |midi=60, sus=1, amp=0.25, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env([0, 1, 0.5, 0], [0.003, sus, 0.3], [\lin, -3, -4]), doneAction: 2);
		var index = EnvGen.kr(Env([2.4, 0.5], [0.6], -3));
		var mod = SinOsc.ar(freq, 0, freq * index);
		var tine = SinOsc.ar(freq * 14.2) * EnvGen.ar(Env.perc(0.001, 0.06)) * 0.12;
		var trem = 1 + (SinOsc.kr(4.6) * 0.12);
		Out.ar(0, Pan2.ar((SinOsc.ar(freq + mod) + tine) * env * trem * amp * 0.6, pan));
	}),
	SynthDef(\pad, { |midi=60, sus=2, amp=0.12, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env([0, 1, 1, 0], [0.45, sus, 0.9], [2, 0, -2]), doneAction: 2);
		var sig = Mix(Saw.ar(freq * [0.997, 1.0, 1.004])) / 3;
		sig = LPF.ar(sig, (freq * 4).clip(400, 2600));
		Out.ar(0, Pan2.ar(sig * env * amp, pan));
	}),
	SynthDef(\arp, { |midi=60, sus=0.15, amp=0.18, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env.perc(0.002, sus.max(0.08) + 0.12), doneAction: 2);
		var cutoff = EnvGen.kr(Env([freq * 16, freq * 2.5], [0.12], -4)).clip(200, 12000);
		Out.ar(0, Pan2.ar(RLPF.ar(Saw.ar(freq) + Pulse.ar(freq * 1.005, 0.3, 0.5), cutoff, 0.4) * env * amp * 0.5, pan));
	}),
	SynthDef(\power, { |midi=40, sus=0.4, amp=0.3, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.004, sus, 0.08], [\lin, -1, -4]), doneAction: 2);
		var sig = Mix([Saw.ar(freq), Saw.ar(freq * 1.4983), Saw.ar(freq * 2.003)]);
		sig = LPF.ar((sig * 6).tanh, 3200);
		sig = BPF.ar(sig, 1400, 1.4) + (LPF.ar(sig, 500) * 0.6);
		Out.ar(0, Pan2.ar(sig * env * amp * 0.5, pan));
	}),
	SynthDef(\bell, { |midi=72, sus=1.5, amp=0.15, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env.perc(0.002, sus.max(0.8)), doneAction: 2);
		var sig = SinOsc.ar(freq) + (SinOsc.ar(freq * 2.76) * 0.4) + (SinOsc.ar(freq * 5.4) * 0.15);
		Out.ar(0, Pan2.ar(sig * env * amp, pan));
	}),

	// ---------------------------------------------------------------- drums
	SynthDef(\kick, { |amp=0.5, pan=0|
		var pitchEnv = EnvGen.ar(Env([150, 58, 46], [0.03, 0.2], \exp));
		var env = EnvGen.ar(Env.perc(0.002, 0.26), doneAction: 2);
		Out.ar(0, Pan2.ar(SinOsc.ar(pitchEnv) * env * amp, pan));
	}),
	SynthDef(\snare, { |amp=0.4, pan=0|
		var env = EnvGen.ar(Env.perc(0.002, 0.18), doneAction: 2);
		var body = SinOsc.ar(EnvGen.ar(Env([240, 185], [0.04], \exp))) * EnvGen.ar(Env.perc(0.001, 0.07));
		var noise = BPF.ar(WhiteNoise.ar, 3200, 0.9) * env;
		Out.ar(0, Pan2.ar((body * 0.7 + noise) * amp, pan));
	}),
	SynthDef(\brush, { |amp=0.25, pan=0|
		var env = EnvGen.ar(Env.perc(0.006, 0.15), doneAction: 2);
		Out.ar(0, Pan2.ar(BPF.ar(WhiteNoise.ar, 2300, 1.7) * env * amp * 2, pan));
	}),
	SynthDef(\hat, { |sus=0.05, amp=0.15, pan=0|
		var env = EnvGen.ar(Env.perc(0.002, sus.clip(0.03, 0.6)), doneAction: 2);
		Out.ar(0, Pan2.ar(HPF.ar(WhiteNoise.ar, 8000) * env * amp, pan));
	}),
	SynthDef(\shaker, { |amp=0.1, pan=0|
		var env = EnvGen.ar(Env.perc(0.004, 0.05), doneAction: 2);
		Out.ar(0, Pan2.ar(HPF.ar(WhiteNoise.ar, 6500) * env * amp, pan));
	}),
	SynthDef(\crash, { |amp=0.2, pan=0|
		var env = EnvGen.ar(Env.perc(0.004, 1.8), doneAction: 2);
		var sig = HPF.ar(WhiteNoise.ar + (Pulse.ar([3150, 4370, 5310], 0.5).sum * 0.2), 4500);
		Out.ar(0, Pan2.ar(sig * env * amp, pan));
	}),
	SynthDef(\tom, { |midi=45, amp=0.4, pan=0|
		var freq = midi.midicps;
		var env = EnvGen.ar(Env.perc(0.002, 0.32), doneAction: 2);
		Out.ar(0, Pan2.ar(SinOsc.ar(EnvGen.ar(Env([freq * 1.6, freq], [0.06], \exp))) * env * amp, pan));
	}),

	// ---------------------------------------------------------------- leads (one per region)
	// Pedal steel (Backroads): slides up into each note; vibrato arrives late, so a held note blooms.
	SynthDef(\steel, { |midi=60, sus=1, amp=0.4, pan=0|
		var env = EnvGen.ar(Env([0, 1, 0.82, 0.7, 0], [0.014, 0.1, (sus - 0.1).max(0.02), 0.12], [\lin, \lin, -1, -3]), doneAction: 2);
		var glide = EnvGen.kr(Env([-0.7, 0], [0.075], \sin));
		var vibDepth = EnvGen.kr(Env([0, 0, 0.17], [0.34, 0.45]));
		var freq = (midi + glide + (SinOsc.kr(5.2) * vibDepth)).midicps;
		var src = VarSaw.ar(freq, 0, 0.35, 0.6) + SinOsc.ar(freq * 2, 0, 0.22) + LFTri.ar(freq * 0.5, 0, 0.1);
		var filt = RLPF.ar(src, EnvGen.kr(Env([freq * 8, freq * 3.5], [0.22], -3)).clip(200, 12000), 0.7);
		Out.ar(0, Pan2.ar(filt * env * amp, pan));
	}),
	// Saw lead (Neon Sprawl): bright, detuned, with a short glide.
	SynthDef(\sawlead, { |midi=72, sus=1, amp=0.35, pan=0|
		var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.008, (sus - 0.008).max(0.02), 0.14], [\lin, -1, -3]), doneAction: 2);
		var glide = EnvGen.kr(Env([-0.3, 0], [0.04]));
		var vib = SinOsc.kr(5.8) * EnvGen.kr(Env([0, 0, 0.12], [0.3, 0.4]));
		var freq = (midi + glide + vib).midicps;
		var sig = Mix(Saw.ar(freq * [0.996, 1.004])) * 0.5 + Pulse.ar(freq * 0.5, 0.5, 0.25);
		sig = RLPF.ar(sig, EnvGen.kr(Env([freq * 10, freq * 5], [0.25], -3)).clip(300, 14000), 0.5);
		Out.ar(0, Pan2.ar(sig * env * amp * 0.6, pan));
	}),
	// Overdriven guitar (Red Mesa).
	SynthDef(\drive, { |midi=64, sus=1, amp=0.35, pan=0|
		var env = EnvGen.ar(Env([0, 1, 0.75, 0], [0.005, (sus - 0.005).max(0.02), 0.1], [\lin, -1, -4]), doneAction: 2);
		var bend = EnvGen.kr(Env([-0.5, 0], [0.06]));
		var vib = SinOsc.kr(5.5) * EnvGen.kr(Env([0, 0, 0.25], [0.4, 0.4]));
		var freq = (midi + bend + vib).midicps;
		var sig = (Saw.ar(freq) + Pulse.ar(freq * 1.002, 0.3)) * 7;
		sig = LPF.ar(sig.tanh, 3800);
		sig = BPF.ar(sig, 1800, 1.2) + (LPF.ar(sig, 700) * 0.5);
		Out.ar(0, Pan2.ar(sig * env * amp * 0.5, pan));
	}),
	// A sung "ah": a buzzy source through vowel formants, with drift and late vibrato.
	// Used for choir-like leads and to test the importer, which looks for a human voice.
	SynthDef(\voice, { |midi=64, sus=1, amp=0.35, pan=0|
		var env = EnvGen.ar(Env([0, 1, 0.85, 0], [0.05, (sus - 0.05).max(0.02), 0.12], [\lin, -1, -3]), doneAction: 2);
		var vib = SinOsc.kr(5.3) * EnvGen.kr(Env([0, 0, 0.3], [0.25, 0.4]));
		var drift = LFNoise1.kr(3, 0.08);
		var freq = (midi + vib + drift).midicps;
		var source = Saw.ar(freq) * 0.6 + (PinkNoise.ar * 0.04);
		var sig = Mix([BPF.ar(source, 730, 0.12, 1.0), BPF.ar(source, 1090, 0.1, 0.5), BPF.ar(source, 2440, 0.08, 0.25)]);
		Out.ar(0, Pan2.ar(sig * env * amp * 4, pan));
	}),
	// Breathy flute (Coast Road).
	SynthDef(\flute, { |midi=72, sus=1, amp=0.35, pan=0|
		var env = EnvGen.ar(Env([0, 1, 0.85, 0], [0.04, (sus - 0.04).max(0.02), 0.12], [\lin, -1, -3]), doneAction: 2);
		var vib = SinOsc.kr(5.0) * EnvGen.kr(Env([0, 0, 0.14], [0.25, 0.4]));
		var freq = (midi + vib).midicps;
		var breath = BPF.ar(PinkNoise.ar, freq * 2, 0.3) * 0.25;
		var sig = SinOsc.ar(freq) + (LFTri.ar(freq * 2) * 0.12) + breath;
		Out.ar(0, Pan2.ar(sig * env * amp * 0.7, pan));
	}),
];
