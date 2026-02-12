import 'dart:math';

class VirtualNumberService {
  static final VirtualNumberService _instance =
      VirtualNumberService._internal();
  factory VirtualNumberService() => _instance;
  VirtualNumberService._internal();

  /// Generates a random virtual number in the format '555-XXX-XXXX'
  Future<String?> generateAndAssignVirtualNumber(String userId) async {
    final Random random = Random();
    final String part1 = (100 + random.nextInt(900)).toString(); // 3 digits
    final String part2 = (1000 + random.nextInt(9000)).toString(); // 4 digits

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    return "555-$part1-$part2";
  }

  Future<Map<String, dynamic>> getVirtualNumberStats() async {
    return {'totalAssigned': 1, 'thisYearAssigned': 1};
  }
}
