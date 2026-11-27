import math
import struct
import wave
import os
import random

SAMPLE_RATE = 44100

def note_freq(note_number):
    # MIDI note to frequency (A4 = 69 = 440Hz)
    return 440.0 * (2.0 ** ((note_number - 69) / 12.0))

def clamp(v, min_v=-1.0, max_v=1.0):
    return max(min_v, min(max_v, v))

def create_groove_track(filename, duration=16.0):
    num_samples = int(duration * SAMPLE_RATE)
    bpm = 120.0
    beat_sec = 60.0 / bpm
    sixteenth_sec = beat_sec / 4.0
    
    # Bass progression (MIDI notes: C2=36, G1=31, A1=33, F1=29)
    bass_notes = [36, 36, 39, 41, 33, 33, 36, 38, 29, 29, 31, 33, 31, 31, 34, 36]
    
    # Mid chord notes (e.g. C minor / Eb / Ab / Bb)
    chords = [
        [60, 63, 67], # Cm
        [60, 63, 67],
        [56, 60, 63], # Ab
        [58, 62, 65], # Bb
    ]
    
    # Pre-generate noise for hi-hats
    noise_table = [random.uniform(-1.0, 1.0) for _ in range(SAMPLE_RATE)]
    
    left_samples = []
    right_samples = []
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        beat_pos = t / beat_sec
        bar_pos = beat_pos / 4.0
        
        # 1. LOW BAND (50Hz - 150Hz): Kick drum + Sub-bass
        # Kick on every beat (4-on-the-floor)
        t_in_beat = t % beat_sec
        kick_env = math.exp(-t_in_beat * 14.0)
        kick_pitch = 120.0 * math.exp(-t_in_beat * 30.0) + 50.0
        kick = math.sin(2.0 * math.pi * kick_pitch * t_in_beat) * kick_env * 0.9
        
        # Sub-bassline
        step16 = int(t / sixteenth_sec) % len(bass_notes)
        t_in_step = t % sixteenth_sec
        bass_note = bass_notes[step16]
        bass_freq = note_freq(bass_note)
        bass_env = math.exp(-t_in_step * 5.0)
        # Fundamental sine + second harmonic
        sub_bass = (math.sin(2.0 * math.pi * bass_freq * t) + 
                    0.3 * math.sin(2.0 * math.pi * bass_freq * 2.0 * t)) * bass_env * 0.6
        low_layer = kick + sub_bass
        
        # 2. MID BAND (400Hz - 2000Hz): Chords & Melody
        chord_idx = int(bar_pos) % len(chords)
        chord = chords[chord_idx]
        t_in_bar = t % (beat_sec * 4.0)
        # Stabs on off-beats
        chord_env = (math.sin(2.0 * math.pi * (t / beat_sec) * 2.0) ** 4) * 0.4
        chord_sound = 0.0
        for n in chord:
            f = note_freq(n)
            # Warm saw/triangle synth tone with odd harmonics
            chord_sound += (math.sin(2.0 * math.pi * f * t) + 
                            0.4 * math.sin(2.0 * math.pi * f * 2.0 * t) +
                            0.2 * math.sin(2.0 * math.pi * f * 3.0 * t)) / len(chord)
        mid_layer = chord_sound * chord_env * 0.7
        
        # 3. HIGH BAND (6000Hz - 16000Hz): Hi-Hats & Shakers & High Bells
        # 16th note closed hats + accented 8th open hat
        hat_env = math.exp(-(t % (beat_sec / 2.0)) * 35.0)
        noise_idx = (i * 7) % SAMPLE_RATE
        # High-pass filter simulated with derivative
        noise_diff = noise_table[noise_idx] - noise_table[(noise_idx - 1) % SAMPLE_RATE]
        hihat = noise_diff * hat_env * 0.5
        
        # High bell chime every 2 beats
        bell_t = t % (beat_sec * 2.0)
        bell_env = math.exp(-bell_t * 3.5)
        bell = (math.sin(2.0 * math.pi * 7500.0 * t) + 
                0.5 * math.sin(2.0 * math.pi * 10500.0 * t)) * bell_env * 0.25
        high_layer = hihat + bell
        
        # Master mix with slight stereo separation
        left = clamp(low_layer * 0.7 + mid_layer * 0.75 + high_layer * 0.8)
        right = clamp(low_layer * 0.7 + mid_layer * 0.65 + high_layer * 0.85)
        
        left_samples.append(int(left * 32767.0))
        right_samples.append(int(right * 32767.0))
        
    write_wav(filename, left_samples, right_samples)

def create_synthwave_track(filename, duration=16.0):
    num_samples = int(duration * SAMPLE_RATE)
    bpm = 110.0
    beat_sec = 60.0 / bpm
    sixteenth_sec = beat_sec / 4.0
    
    # Synthwave progression: Dm (D2=38), F2=41, C2=36, G2=43
    root_notes = [38, 41, 36, 43]
    lead_arps = [
        [62, 65, 69, 74], # Dm
        [65, 69, 72, 77], # F
        [60, 64, 67, 72], # C
        [55, 59, 62, 67], # G
    ]
    
    noise_table = [random.uniform(-1.0, 1.0) for _ in range(SAMPLE_RATE)]
    
    left_samples = []
    right_samples = []
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        bar_idx = int(t / (beat_sec * 4.0)) % len(root_notes)
        root = root_notes[bar_idx]
        
        # 1. LOW: Driving 8th note rolling bassline
        t_in_eighth = t % (beat_sec / 2.0)
        bass_env = math.exp(-t_in_eighth * 8.0)
        bass_f = note_freq(root)
        bass = (math.sin(2.0 * math.pi * bass_f * t) + 
                0.5 * math.sin(2.0 * math.pi * bass_f * 2.0 * t)) * bass_env * 0.7
        # Snare punch low body
        t_in_24 = t % (beat_sec * 2.0)
        snare_body = math.sin(2.0 * math.pi * 180.0 * t_in_24) * math.exp(-t_in_24 * 25.0) * 0.4 if (int(t / beat_sec) % 2 == 1) else 0.0
        low_layer = bass + snare_body
        
        # 2. MID: 16th note synth arpeggios
        arp_idx = int(t / sixteenth_sec) % 4
        arp_note = lead_arps[bar_idx][arp_idx]
        arp_f = note_freq(arp_note)
        arp_env = math.exp(-(t % sixteenth_sec) * 12.0)
        # Synth pulse
        arp = (math.sin(2.0 * math.pi * arp_f * t) + 
               0.3 * math.sin(2.0 * math.pi * arp_f * 3.0 * t)) * arp_env * 0.6
        mid_layer = arp
        
        # 3. HIGH: Crisp noise snare snap + open hi-hat sizzle
        noise_idx = (i * 13) % SAMPLE_RATE
        noise_diff = noise_table[noise_idx] - noise_table[(noise_idx - 1) % SAMPLE_RATE]
        # Snare snap on beats 2 and 4
        is_snare_beat = (int(t / beat_sec) % 2 == 1)
        snare_snap = noise_diff * math.exp(-t_in_24 * 18.0) * 0.6 if is_snare_beat else 0.0
        # Continuous sizzling shaker
        shaker_env = (math.sin(2.0 * math.pi * (t / sixteenth_sec)) ** 2) * 0.2
        shaker = noise_diff * shaker_env
        high_layer = snare_snap + shaker
        
        left = clamp(low_layer * 0.65 + mid_layer * 0.7 + high_layer * 0.75)
        right = clamp(low_layer * 0.65 + mid_layer * 0.75 + high_layer * 0.7)
        
        left_samples.append(int(left * 32767.0))
        right_samples.append(int(right * 32767.0))
        
    write_wav(filename, left_samples, right_samples)

def create_acoustic_track(filename, duration=16.0):
    num_samples = int(duration * SAMPLE_RATE)
    bpm = 90.0
    beat_sec = 60.0 / bpm
    
    # Warm chords: G major, Em, C, D
    chords = [
        [43, 55, 59, 62, 67], # G
        [40, 52, 55, 59, 64], # Em
        [36, 48, 52, 55, 60], # C
        [38, 50, 54, 57, 62], # D
    ]
    
    left_samples = []
    right_samples = []
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        bar_idx = int(t / (beat_sec * 4.0)) % len(chords)
        chord = chords[bar_idx]
        
        # 1. LOW: Resonant acoustic bass note
        root_f = note_freq(chord[0])
        t_in_bar = t % (beat_sec * 4.0)
        bass_env = math.exp(-t_in_bar * 1.2)
        bass = (math.sin(2.0 * math.pi * root_f * t) + 
                0.3 * math.sin(2.0 * math.pi * root_f * 2.0 * t)) * bass_env * 0.75
        low_layer = bass
        
        # 2. MID: Fingerpicked guitar arpeggio
        t_in_pick = t % (beat_sec / 2.0)
        pick_idx = (int(t / (beat_sec / 2.0)) % (len(chord) - 1)) + 1
        pick_f = note_freq(chord[pick_idx])
        guitar_env = math.exp(-t_in_pick * 4.5)
        # Plucked string harmonic synthesis
        guitar = (math.sin(2.0 * math.pi * pick_f * t) + 
                  0.5 * math.sin(2.0 * math.pi * pick_f * 2.0 * t) + 
                  0.25 * math.sin(2.0 * math.pi * pick_f * 3.0 * t)) * guitar_env * 0.6
        mid_layer = guitar
        
        # 3. HIGH: Delicate sparkling harmonic overtone / chime
        chime_t = t % (beat_sec * 2.0)
        chime_env = math.exp(-chime_t * 2.0)
        chime_f = pick_f * 4.0
        chime = math.sin(2.0 * math.pi * chime_f * t) * chime_env * 0.2
        high_layer = chime
        
        left = clamp(low_layer * 0.7 + mid_layer * 0.7 + high_layer * 0.6)
        right = clamp(low_layer * 0.7 + mid_layer * 0.75 + high_layer * 0.65)
        
        left_samples.append(int(left * 32767.0))
        right_samples.append(int(right * 32767.0))
        
    write_wav(filename, left_samples, right_samples)

def write_wav(filename, left, right):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        raw_bytes = bytearray()
        for l, r in zip(left, right):
            raw_bytes.extend(struct.pack('<hh', l, r))
        wf.writeframes(raw_bytes)
    print(f"Generated {filename} ({len(left)} samples, {len(left)/SAMPLE_RATE:.1f}s)")

if __name__ == '__main__':
    out_dir = "assets/audio"
    create_groove_track(os.path.join(out_dir, "groove_beat.wav"), duration=16.0)
    create_synthwave_track(os.path.join(out_dir, "synth_wave.wav"), duration=16.0)
    create_acoustic_track(os.path.join(out_dir, "acoustic_chill.wav"), duration=16.0)
