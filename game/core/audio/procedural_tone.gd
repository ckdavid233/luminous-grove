class_name ProceduralTone
extends RefCounted

const MIX_RATE := 22050


static func create_chime(
	frequencies: PackedFloat32Array,
	duration: float,
	gain: float = 0.5,
	decay: float = 4.2,
) -> AudioStreamWAV:
	var frame_count := int(duration * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in frame_count:
		var time := float(frame) / MIX_RATE
		var attack := smoothstep(0.0, 0.012, time)
		var envelope := attack * exp(-decay * time / duration)
		var sample := 0.0
		for frequency in frequencies:
			sample += sin(TAU * frequency * time)
			sample += sin(TAU * frequency * 2.01 * time) * 0.22
			sample += sin(TAU * frequency * 3.98 * time) * 0.08
		sample /= maxf(float(frequencies.size()), 1.0)
		var pcm := int(clampf(sample * envelope * gain, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(frame * 2, pcm)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
