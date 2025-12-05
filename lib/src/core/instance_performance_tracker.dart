import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_pod/pod.dart';

import '../annotations.dart';
import 'method_performance_tracker.dart';

/// Tracks the performance of JetLeaf pod instances during their lifecycle.
///
/// The [InstancePerformanceTracker] monitors the execution and lifecycle
/// of classes managed by a pod container, recording metrics such as:
/// - Instantiation duration
/// - Destruction duration
/// - Memory and error statistics (via underlying [MethodPerformanceTracker])
///
/// This class extends [MethodPerformanceTracker] to provide method-level
/// tracking and implements both [PodInstantiationProcessor] and
/// [PodDestructionProcessor] to hook into pod lifecycle events.
///
/// ## Lifecycle Integration
/// - **Before Instantiation:** Starts a performance timer and initializes a
///   [ConfigurablePerformance] record.
/// - **After Instantiation:** Can perform additional processing or validation.
/// - **Before Destruction:** Optional hook for pre-destruction logic.
/// - **After Destruction:** Stops the timer, records elapsed time, and
///   finalizes the [ConfigurablePerformance] record.
///
/// ## Usage
/// Implementations are expected to provide concrete storage and retrieval
/// mechanisms for performance data by overriding the abstract methods from
/// [MethodPerformanceTracker].
abstract class InstancePerformanceTracker extends MethodPerformanceTracker implements PodInstantiationProcessor, PodDestructionProcessor {
  /// Internal mapping of performance names to running stopwatches.
  ///
  /// Each pod instance being monitored has a corresponding stopwatch
  /// to measure instantiation and destruction durations.
  final Map<String, Stopwatch> _timers = HashMap();

  @override
  Future<Object?> processBeforeInstantiation(Class podClass, String name) async {
    final monitor = podClass.getDirectAnnotation<Monitor>();

    if (monitor != null) {
      final performance = create(monitor, podClass, name);

      final timer = Stopwatch();
      _timers[performance.getName()] = timer;
      timer.start();

      performance.setIsRunning(timer.isRunning);
      performance.setStartTime(DateTime.now());
      updatePerformance(performance);
    }

    return null;
  }
  
  @override
  Future<void> processAfterDestruction(Object pod, Class podClass, String name) async {
    final monitor = podClass.getDirectAnnotation<Monitor>();
    if (monitor != null) {
      final performance = getCreated(monitor, podClass, name);
      if (performance case final performed?) {
        final timer = _timers.remove(performed.getName());

        if (timer != null) {
          timer.stop();
      
          performed.setUptime(timer.elapsed);
          performed.setIsRunning(timer.isRunning);
        }

        performed.setEndTime(DateTime.now());
        updatePerformance(performed);
      }
    }
  }

  @override
  Future<bool> processAfterInstantiation(Object pod, Class podClass, String name) async => true;

  @override
  Future<void> processBeforeDestruction(Object pod, Class podClass, String name) async { }

  @override
  Future<PropertyValues?> processPropertyValues(PropertyValues pvs, Object pod, Class podClass, String name) async => pvs;

  @override
  Future<void> populateValues(Object pod, Class podClass, String name) async {}

  @override
  Future<bool> requiresDestruction(Object pod, Class podClass, String name) async => true;
}