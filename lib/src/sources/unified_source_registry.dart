import 'unified_source_models.dart';

class UnifiedSourceRegistry {
  UnifiedSourceRegistry._();

  static final UnifiedSourceRegistry instance = UnifiedSourceRegistry._();

  final Map<int, UnifiedWorkBundle> _byWorkId = {};

  UnifiedWorkBundle? bundleFor(int workId) => _byWorkId[workId];

  bool contains(int workId) => _byWorkId.containsKey(workId);

  void register(UnifiedWorkBundle bundle) {
    _byWorkId[bundle.work.id] = bundle;
  }

  void registerAll(Iterable<UnifiedWorkBundle> bundles) {
    for (final bundle in bundles) {
      register(bundle);
    }
  }

  void clear() => _byWorkId.clear();
}
