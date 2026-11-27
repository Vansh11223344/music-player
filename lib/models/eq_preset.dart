class EqPreset {
  final String name;
  final double lowGain;  // 0.0 to 4.0 (1.0 = flat 0dB)
  final double midGain;  // 0.0 to 4.0 (1.0 = flat 0dB)
  final double highGain; // 0.0 to 4.0 (1.0 = flat 0dB)
  final String description;

  const EqPreset({
    required this.name,
    required this.lowGain,
    required this.midGain,
    required this.highGain,
    required this.description,
  });

  static const EqPreset flat = EqPreset(
    name: 'Flat',
    lowGain: 1.0,
    midGain: 1.0,
    highGain: 1.0,
    description: 'Natural sound without coloration (0 dB)',
  );

  static const EqPreset bassBoost = EqPreset(
    name: 'Bass Boost',
    lowGain: 2.6,
    midGain: 1.0,
    highGain: 0.9,
    description: 'Deep, thumping low-end kick and bassline',
  );

  static const EqPreset vocalBoost = EqPreset(
    name: 'Vocal / Mid',
    lowGain: 0.8,
    midGain: 2.3,
    highGain: 1.1,
    description: 'Emphasizes lead vocals, speech, and instruments',
  );

  static const EqPreset trebleBoost = EqPreset(
    name: 'Treble Sparkle',
    lowGain: 0.85,
    midGain: 1.0,
    highGain: 2.6,
    description: 'Crisp highs, sizzling cymbals, and airy details',
  );

  static const EqPreset rock = EqPreset(
    name: 'Rock / V-Curve',
    lowGain: 2.1,
    midGain: 0.7,
    highGain: 2.2,
    description: 'Punchy low bass and bright highs with recessed mids',
  );

  static const List<EqPreset> presets = [
    flat,
    bassBoost,
    vocalBoost,
    trebleBoost,
    rock,
  ];
}
