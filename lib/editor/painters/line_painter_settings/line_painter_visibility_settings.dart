final class LinePainterVisibilitySettings {
  final Map<LinePainterVisibility, bool> _visible;

  LinePainterVisibilitySettings.of(final Iterable<LinePainterVisibility> visible) : _visible = { for (final setting in visible) setting : true };
  LinePainterVisibilitySettings.fromMap(final Map<LinePainterVisibility, bool> visible) : _visible = Map.of(visible);

  void set(final LinePainterVisibility setting, final bool visible) => _visible[setting] = visible;

  bool isAvailable(final LinePainterVisibility setting) => availableSettings.contains(setting);
  bool isVisible(final LinePainterVisibility setting) => _visible[setting] == true;
  bool anyVisible() => _visible.values.any((final v) => v);

  static String nameOf(LinePainterVisibility setting) {
    String name = setting.name[0].toUpperCase();
    for (int i = 1; i < setting.name.length; i++) {
      if (setting.name[i] == setting.name[i].toUpperCase()) {
        name += " ";
      }
      name += setting.name[i];
    }
    return name;
  }

  late final availableSettings = Set.unmodifiable(_visible.keys.toSet());
  late final availableUniversalSettings = Set.unmodifiable(universalSettings.intersection(availableSettings));
  late final availableIrSettings = Set.unmodifiable(onlyIrSettings.intersection(availableSettings));
  late final availableSimulationSettings = Set.unmodifiable(onlySimulationSettings.intersection(availableSettings));
  late final availableNonUniversalSettings = Set.unmodifiable(availableSettings.difference(universalSettings));

  LinePainterVisibilitySettings copy() => LinePainterVisibilitySettings.fromMap(_visible);

  static final Set<LinePainterVisibility> allSettings = Set.unmodifiable(LinePainterVisibility.values);

  static const Set<LinePainterVisibility> onlyIrSettings = {
    LinePainterVisibility.irMeasurementInfo,
    LinePainterVisibility.irReadings,
    LinePainterVisibility.irPathApproximation,
    LinePainterVisibility.irTrackPath,
  };

  static const Set<LinePainterVisibility> onlySimulationSettings = {
    LinePainterVisibility.simulation,
  };

  static final Set<LinePainterVisibility> universalSettings = Set.unmodifiable(allSettings.difference(onlyIrSettings).difference(onlySimulationSettings));

  bool get showLengthScale => isVisible(LinePainterVisibility.lengthScale);

  bool get showVelocityScale => isVisible(LinePainterVisibility.velocityScale);

  bool get showRobiStateInfo => isVisible(LinePainterVisibility.robiStateInfo);

  bool get showIrMeasurementInfo => isVisible(LinePainterVisibility.irMeasurementInfo);

  bool get showGrid => isVisible(LinePainterVisibility.grid);

  bool get showRobi => isVisible(LinePainterVisibility.robi);

  bool get showObstacles => isVisible(LinePainterVisibility.obstacles);

  bool get showSimulation => isVisible(LinePainterVisibility.simulation);

  bool get showIrRead => isVisible(LinePainterVisibility.irReadings);

  bool get showIrPathApproximation => isVisible(LinePainterVisibility.irPathApproximation);

  bool get showIrTrackPath => isVisible(LinePainterVisibility.irTrackPath);
}

enum LinePainterVisibility {
  lengthScale,
  velocityScale,
  robiStateInfo,
  irMeasurementInfo,
  grid,
  robi,
  obstacles,
  simulation,
  irReadings,
  irPathApproximation,
  irTrackPath,
}
