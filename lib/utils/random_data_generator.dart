import 'dart:math';

class RandomDataGenerator {
  static final Random _random = Random();

  static final List<String> _adjectives = [
    'Neon',
    'Cyber',
    'Swift',
    'Solar',
    'Lunar',
    'Arctic',
    'Mystic',
    'Cosmic',
    'Pixel',
    'Binary',
    'Retro',
    'Quantum',
    'Ethereal',
    'Shadow',
    'Frost',
    'Voltaic',
    'Sonic',
    'Hyper',
    'Nova',
    'Zenith',
    'Azure',
    'Crimson',
    'Golden',
    'Silver',
    'Velvet',
    'Crystal',
    'Obsidian',
    'Emerald',
    'Spark',
    'Flash',
    'Storm',
    'Echo',
    'Pulse',
    'Vibe',
    'Drift',
  ];

  static final List<String> _nouns = [
    'Rider',
    'Wolf',
    'Eagle',
    'Phantom',
    'Runner',
    'Surfer',
    'Knight',
    'Ninja',
    'Samurai',
    'Pilot',
    'Nomad',
    'Voyager',
    'Falcon',
    'Hawk',
    'Tiger',
    'Lion',
    'Bear',
    'Fox',
    'Sprite',
    'Ghost',
    'Wraith',
    'Specter',
    'Phoenix',
    'Dragon',
    'Titan',
    'Giant',
    'Mage',
    'Wizard',
    'Alchemist',
    'Scribe',
    'Poet',
    'Artist',
    'Glitch',
    'Spark',
    'Shard',
  ];

  static final List<String> _bios = [
    'Exploring the digital frontier.',
    'Just another byte in the system.',
    'Chasing pixels and dreams.',
    'Coding my own path.',
    'Listening to the silent echoes.',
    'Quietly observing the chaos.',
    'Living in the moment.',
    'Here for a good time, not a long time.',
    'Ready for the next adventure.',
    'Digital nomad since always.',
    'Simplicity is the ultimate sophistication.',
    'Creating my own reality.',
    'Dreaming in code.',
    'Connecting the dots.',
    'Seeking the unknown.',
    'Lost in the matrix.',
    'Just here for the memes.',
    'Making every second count.',
    'Embracing the glitches.',
    'Offline is the new luxury.',
  ];

  static String generateFullName() {
    final adj = _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];
    return '$adj $noun';
  }

  static String generateHandle(String fullName) {
    // Convert to lowercase and remove spaces
    final base = fullName.toLowerCase().replaceAll(' ', '_');
    // Add random suffix
    final suffix = (1000 + _random.nextInt(9000)).toString();
    return '${base}_$suffix';
  }

  static String generateBio() {
    return _bios[_random.nextInt(_bios.length)];
  }

  /// Generates a random virtual number in the format '555-XXX-XXXX'
  /// This can be used as a fallback if the service fails or for demo data
  static String generateVirtualNumber() {
    final part1 = (100 + _random.nextInt(900)).toString();
    final part2 = (1000 + _random.nextInt(9000)).toString();
    return "555-$part1-$part2";
  }

  static final List<String> _avatars = [
    '🦊',
    '🐼',
    '🐨',
    '🦁',
    '🐯',
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🐻',
    '🐷',
    '🐮',
    '🐸',
    '🐵',
    '🦄',
    '🐝',
    '🐙',
    '🦋',
    '🐬',
    '🦕',
    '🦖',
    '🐉',
    '🐳',
    '🦈',
    '🦉',
    '🦅',
    '🦆',
    '🦜',
    '🦚',
    '🚀',
    '🛸',
    '🌍',
    '🔥',
    '⚡',
    '🌟',
    '🌈',
    '🎨',
    '🎮',
    '🎧',
    '🤖',
    '👾',
    '👻',
    '💀',
    '👽',
    '💩',
    '🤡',
    '👹',
    '👺',
    '🎃',
    '🎩',
    '👑',
    '💎',
    '🔮',
    '🧿',
    '🧩',
    '🎲',
    '🎯',
    '🎳',
    '🎹',
  ];

  static String generateAvatar() {
    return _avatars[_random.nextInt(_avatars.length)];
  }
}
