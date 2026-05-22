import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true);
  int updatedFiles = 0;
  int replaceCount = 0;

  for (var entity in files) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      if (content.contains('.withOpacity(')) {
        final newContent = content.replaceAllMapped(RegExp(r'\.withOpacity\(([^)]+)\)'), (match) {
          replaceCount++;
          return '.withValues(alpha: ${match.group(1)})';
        });
        entity.writeAsStringSync(newContent);
        updatedFiles++;
      }
    }
  }
  print('Successfully updated $replaceCount instances of withOpacity across $updatedFiles files.');
}
