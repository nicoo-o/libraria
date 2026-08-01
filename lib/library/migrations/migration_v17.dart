const String migrationV17 = '''
ALTER TABLE downloads ADD COLUMN was_network_failure INTEGER DEFAULT 0;
''';
