// Red Frontier: short sound effects for the world's answers to the player (2026-11-11), mixed under the
// music by ThemeWorld.event_sound(). Rendered offline, one WAV per job, into the region's audio folder:
//   sclang tools/themes/backroads/events.scd game/assets/themes/backroads/audio
// (through ~/Desktop/siege-pc/tools/heavy.sh, like every SuperCollider build).
(
var dir = thisProcess.argv[0].withoutTrailingSlash ++ "/";
var options = ServerOptions.new.numOutputBusChannels_(2).numWireBufs_(512).memSize_(65536);
var head = { |t, def ... args| [t, [\s_new, def, -1, 0, 0] ++ args] };
var render = { |defs, events, dur, path, next|
	var list = defs.collect { |d| [0.0, [\d_recv, d.asBytes]] } ++ events ++ [[dur, [\c_set, 0, 0]]];
	Score(list.sort { |a, b| a[0] < b[0] }).recordNRT(path ++ ".osc", path, sampleRate: 44100, headerFormat: "WAV",
		sampleFormat: "int16", options: options, duration: dur,
		action: { File.delete(path ++ ".osc"); ("RENDERED " ++ path).postln; next.value });
};
var defs = [
	// A shuttle lifting off, timed to backroads.gd's launch: the jets spool up (0-1.8 s) and lift it
	// clear (to 3.4 s), then the main engines' roar opens out, crackling, and fades as it climbs away.
	SynthDef(\launch, { |amp=0.5|
		var env = EnvGen.kr(Env.new([0, 0.3, 0.45, 1, 1, 0], [1.6, 1.8, 0.3, 2.0, 2.6], [2, 0, 3, 0, -3]), doneAction: 2);
		var roar = LPF.ar(PinkNoise.ar + (BrownNoise.ar * 0.7), XLine.kr(200, 2200, 4.2));
		var crackle = HPF.ar(Dust2.ar(220), 3000) * 0.18;
		var low = SinOsc.ar(36 + LFNoise1.kr(8, 4)) * 0.6;
		Out.ar(0, Pan2.ar((roar + crackle + low) * env * amp, 0.4));
	}),
	// A brown-out: a buzzing zap and the supply's hum sagging away.
	SynthDef(\brownout, { |amp=0.35|
		var zap = HPF.ar(WhiteNoise.ar, 2000) * EnvGen.ar(Env.perc(0.001, 0.25)) * LFPulse.ar(32);
		var hum = Saw.ar(XLine.kr(120, 38, 1.2)) * EnvGen.ar(Env.perc(0.01, 1.2)) * 0.4;
		var env = EnvGen.kr(Env.linen(0, 1.3, 0.05), doneAction: 2);
		Out.ar(0, Pan2.ar(LPF.ar(zap + hum, 3000) * env * amp, -0.35));
	}),
];
var jobs = [["event_launch", [head.(0.001, \launch)], 8.4], ["event_brownout", [head.(0.001, \brownout)], 1.5]];
var run = { |i| if(i >= jobs.size) { 0.exit } { render.(defs, jobs[i][1], jobs[i][2], dir ++ jobs[i][0] ++ ".wav", { run.(i + 1) }) } };
run.(0);
)
