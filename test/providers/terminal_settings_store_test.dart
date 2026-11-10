import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late TerminalSettingsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
    store = TerminalSettingsStore(storageService: storageService);
  });

  test(
      'custom key preferences persist and can be reordered, removed, and reset',
      () async {
    await store.load();
    expect(store.hapticFeedbackEnabled, isTrue);
    expect(store.accessoryKeys.first.label, 'Esc');

    // Toggle haptic feedback
    await store.setHapticFeedbackEnabled(false);
    expect(store.hapticFeedbackEnabled, isFalse);

    // Toggle key visibility
    final initialCount = store.accessoryKeys.length;
    await store.toggleAccessoryKeyVisibility(0); // disables 'Tab'
    expect(store.accessoryKeys.length, initialCount - 1);
    expect(store.accessoryKeys.first.label, 'Tab');

    // Add custom key
    await store.addCustomAccessoryKey(
      label: 'sudo',
      sequence: r'sudo \n',
      description: 'Run as superuser',
    );
    expect(store.configuredAccessoryKeys.last.label, 'sudo');
    expect(store.configuredAccessoryKeys.last.sequence, 'sudo \n');
    expect(store.configuredAccessoryKeys.last.isCustom, isTrue);

    final reloaded = TerminalSettingsStore(storageService: storageService);
    await reloaded.load();
    expect(reloaded.configuredAccessoryKeys.last.label, 'sudo');
    expect(reloaded.hapticFeedbackEnabled, isFalse);

    // Reorder key
    final lastIdx = store.configuredAccessoryKeys.length - 1;
    await store.reorderAccessoryKeys(lastIdx, 0);
    expect(store.configuredAccessoryKeys.first.label, 'sudo');

    // Remove key
    await store.removeAccessoryKey(0);
    expect(store.configuredAccessoryKeys.first.label, 'Esc');

    // Reset to defaults
    await store.resetAccessoryKeysToDefault();
    expect(store.configuredAccessoryKeys.length, 6);
    expect(store.accessoryKeys.first.label, 'Esc');
  });
}
