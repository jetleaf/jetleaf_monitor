import 'dart:async';

import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:meta/meta.dart';

import '../annotations.dart';
import '../base/configurable_performance.dart';

/// Tracks the execution performance of methods annotated with [Monitor].
///
/// The [MethodPerformanceTracker] class is an abstract interceptor that monitors:
/// - Execution time (duration)
/// - Memory usage via associated [ConfigurablePerformance]
/// - Errors thrown during execution
///
/// It implements multiple interceptor interfaces:
/// - [MethodInterceptor]
/// - [MethodBeforeInterceptor]
/// - [AfterInvocationInterceptor]
/// - [AfterThrowingInterceptor]
///
/// ## Behavior
/// 1. Before a monitored method is invoked, a timer is started and a
///    [ConfigurablePerformance] instance is created or retrieved.
/// 2. After the method finishes, the timer stops, uptime is recorded, and
///    performance metrics are updated.
/// 3. If the method throws an exception, the error is recorded along with
///    its type.
///
/// Implementations must provide concrete storage or management of
/// [ConfigurablePerformance] via the `getOrCreate`, `getCreated`, and
/// `updatePerformance` methods.
abstract class MethodPerformanceTracker implements MethodInterceptor, MethodBeforeInterceptor, AfterInvocationInterceptor, AfterThrowingInterceptor {
  /// Internal mapping of performance names to running stopwatches.
  final Map<String, Stopwatch> _timers = HashMap();

  @override
  bool canIntercept(Method method) => method.hasDirectAnnotation<Monitor>() || method.getDeclaringClass().hasDirectAnnotation<Monitor>();

  @override
  FutureOr<void> beforeInvocation<T>(MethodInvocation<T> invocation) async {
    final method = invocation.getMethod();
    final monitor = method.getDirectAnnotation<Monitor>() ?? method.getDeclaringClass().getDirectAnnotation<Monitor>();

    if (monitor case final monitored?) {
      final performance = create(monitored, method);
      final timer = Stopwatch();
      _timers[performance.getName()] = timer;
      timer.start();

      performance.setIsRunning(timer.isRunning);
      performance.setStartTime(DateTime.now());
      updatePerformance(performance);
    }
  }

  @override
  FutureOr<void> afterInvocation<T>(MethodInvocation<T> invocation) async {
    final method = invocation.getMethod();
    final monitor = method.getDirectAnnotation<Monitor>() ?? method.getDeclaringClass().getDirectAnnotation<Monitor>();

    if (monitor case Monitor monitored) {
      final performance = getCreated(monitored, method);
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
  FutureOr<void> afterThrowing<T>(MethodInvocation<T> invocation, Object exception, Class exceptionClass, StackTrace stackTrace) async {
    final method = invocation.getMethod();
    final monitor = method.getDirectAnnotation<Monitor>() ?? method.getDeclaringClass().getDirectAnnotation<Monitor>();

    if (monitor case final monitored?) {
      final performance = getCreated(monitored, method);
      if (performance case final performed?) {
        performed.addErrorCount(exception is RuntimeException ? exception.getMessage() : exception.toString());
        performed.addErrorTypeCount(exception.runtimeType.toString());
        updatePerformance(performed);
      }
    }
  }

  /// Creates a [ConfigurablePerformance] for the given [monitor] annotation and [source].
  ///
  /// **Parameters:**
  /// - [monitor]: The [Monitor] annotation instance describing the target.
  /// - [source]: The source method or class being monitored.
  /// - [name]: The optional name to use for the [ConfigurablePerformance]
  ///
  /// **Returns:**
  /// - A [ConfigurablePerformance] instance representing the tracked performance.
  @protected
  ConfigurablePerformance create(Monitor monitor, Source source, [String? name]);

  /// Retrieves an existing [ConfigurablePerformance] for the given
  /// [monitor] annotation and [source].
  ///
  /// **Parameters:**
  /// - [monitor]: The [Monitor] annotation instance describing the target.
  /// - [source]: The source method or class being monitored.
  /// - [name]: The optional name to use for the [ConfigurablePerformance]
  ///
  /// **Returns:**
  /// - A [ConfigurablePerformance] instance if it exists, or `null` otherwise.
  @protected
  ConfigurablePerformance? getCreated(Monitor monitor, Source source, [String? name]);

  /// Updates or persists the given [performance] instance after it has been
  /// modified (e.g., after execution or error recording).
  ///
  /// **Parameters:**
  /// - [performance]: The [ConfigurablePerformance] instance to update.
  ///
  /// **Returns:**
  /// - A [FutureOr] indicating completion of the update operation.
  @protected
  void updatePerformance(ConfigurablePerformance performance);
}