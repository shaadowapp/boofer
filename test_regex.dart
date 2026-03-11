void main() {
  String prevLine = "1. test";
  final numberMatch = RegExp(r'^(\s*(\d+)([\.\)])\s+)(.*)$').firstMatch(prevLine);
  if (numberMatch != null) {
      String prefix = numberMatch.group(1)!;
      int num = int.parse(numberMatch.group(2)!);
      String sep = numberMatch.group(3)!;
      String prefixToAdd = prefix.replaceFirst('$num$sep', '${num + 1}$sep');
      print('Prefix added: "$prefixToAdd"');
  } else {
      print('No match');
  }

  // Roman list test
  String romanLine = "i. test";
  final romanMatch = RegExp(r'^(\s*([ivxlcdmIVXLCDM]+)([\.\)])\s+)(.*)$').firstMatch(romanLine);
  if (romanMatch != null) {
      print('Roman prefix: "${romanMatch.group(1)}"');
  } else {
      print('No roman match');
  }

  // Alpha list test
  String alphaLine = "a. test";
  final alphaMatch = RegExp(r'^(\s*([a-zA-Z])([\.\)])\s+)(.*)$').firstMatch(alphaLine);
  if (alphaMatch != null) {
      print('Alpha prefix: "${alphaMatch.group(1)}"');
  } else {
      print('No alpha match');
  }
}
