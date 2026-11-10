// Renders the shared sound effects and one region's ambience bed, offline.
//   sclang render_fx.scd sfx <outDir>                       click, wrong, ui, held, milestone, clear, out_of_gas
//   sclang render_fx.scd ambience <ambience.scd> <out.wav>  22 s raw bed; make_loop.py makes it loop
//
// A region's ambience.scd assigns one SynthDef named \ambience to ~ambience.
(
var mode = thisProcess.argv[0];
var options = ServerOptions.new.numOutputBusChannels_(2).numWireBufs_(512).memSize_(65536);
var head = { |t, def ... args| [t, [\s_new, def, -1, 0, 0] ++ args] };
var render = { |defs, events, dur, path, next|
	var list = defs.collect { |d| [0.0, [\d_recv, d.asBytes]] } ++ events ++ [[dur, [\c_set, 0, 0]]];
	Score(list.sort { |a, b| a[0] < b[0] }).recordNRT(path ++ ".osc", path, sampleRate: 44100, headerFormat: "WAV",
		sampleFormat: "int16", options: options, duration: dur,
		action: { File.delete(path ++ ".osc"); ("RENDERED " ++ path).postln; next.value });
};
var sfxDefs = [
	SynthDef(\click, { |freq=1400, amp=0.5|
		Out.ar(0, SinOsc.ar(freq) * EnvGen.ar(Env.perc(0.001, 0.03), doneAction: 2) * amp ! 2);
	}),
	SynthDef(\thunk, { |amp=0.4|
		var env = EnvGen.ar(Env.perc(0.002, 0.13), doneAction: 2);
		var sig = Pulse.ar(XLine.kr(190, 110, 0.12), 0.4) + Pulse.ar(XLine.kr(203, 104, 0.12), 0.3);
		Out.ar(0, LPF.ar(sig, 900) * env * amp * 0.5 ! 2);
	}),
	SynthDef(\chime, { |freq=880, amp=0.25|
		var env = EnvGen.ar(Env.perc(0.004, 0.42), doneAction: 2);
		Out.ar(0, (SinOsc.ar(freq) + (SinOsc.ar(freq * 3.01) * 0.2)) * env * amp ! 2);
	}),
	SynthDef(\cough, { |amp=0.6, len=0.18|
		var env = EnvGen.ar(Env.perc(0.01, len), doneAction: 2);
		Out.ar(0, LPF.ar(BrownNoise.ar + Saw.ar(38), 420) * env * amp ! 2);
	}),
];

if(mode == "sfx") {
	var dir = thisProcess.argv[1].withoutTrailingSlash ++ "/";
	var jobs = [
		["sfx_click", [head.(0.001, \click)], 0.1],
		["sfx_wrong", [head.(0.001, \thunk)], 0.25],
		["sfx_ui", [head.(0.001, \click, \freq, 760, \amp, 0.3)], 0.1],
		["sfx_held", [head.(0.001, \chime, \freq, 784), head.(0.075, \chime, \freq, 1175)], 0.7],
		// A combo milestone: two soft rising notes. A run that set a new best or opened a road: a short arpeggio.
		["sfx_milestone", [head.(0.001, \chime, \freq, 1047, \amp, 0.16), head.(0.07, \chime, \freq, 1568, \amp, 0.16)], 0.7],
		["sfx_clear", [523, 659, 784, 1047].collect { |f, i| head.(0.001 + (i * 0.11), \chime, \freq, f, \amp, 0.2) }, 1.1],
		["sfx_out_of_gas", [0.03, 0.34, 0.74, 1.3, 2.05].collect { |t, i| head.(t, \cough, \amp, 0.7 - (i * 0.1), \len, 0.16 + (i * 0.05)) }, 2.7],
	];
	var run = { |i| if(i >= jobs.size) { 0.exit } { render.(sfxDefs, jobs[i][1], jobs[i][2], dir ++ jobs[i][0] ++ ".wav", { run.(i + 1) }) } };
	run.(0);
} {
	thisProcess.argv[1].load;
	render.([~ambience], [head.(0.001, \ambience)], 22, thisProcess.argv[2], { 0.exit });
};
)
