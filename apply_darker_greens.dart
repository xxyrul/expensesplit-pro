import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true);

  for (var entity in files) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      
      bool changed = false;
      
      // Teal 700 to Teal 800
      if (content.contains('0xFF0F766E')) {
        content = content.replaceAll('0xFF0F766E', '0xFF115E59');
        changed = true;
      }
      
      // Teal 500 to Teal 600
      if (content.contains('0xFF0EA5A0')) {
        content = content.replaceAll('0xFF0EA5A0', '0xFF0D9488');
        changed = true;
      }
      
      // Teal 900 to Teal 950
      if (content.contains('0xFF134E4A')) {
        content = content.replaceAll('0xFF134E4A', '0xFF042F2E');
        changed = true;
      }
      
      if (changed) {
        entity.writeAsStringSync(content);
        print('Updated: ${entity.path}');
      }
    }
  }
  print('Done applying darker premium greens!');
}
