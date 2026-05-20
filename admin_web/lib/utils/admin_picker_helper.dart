import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

class AdminPickerHelper {
  static const double _mobileBreakpoint = 768;

  /// Opens a responsive Date Range Picker.
  /// - Desktop: Compact centered card layout (480x600) with dark glassmorphism styling
  /// - Mobile: Standard mobile-friendly full-screen layout
  /// - Automatically defaults to the last 30 days if [initialRange] is null
  static Future<DateTimeRange?> pickDateRange({
    required BuildContext context,
    DateTimeRange? initialRange,
  }) async {
    final now = DateTime.now();
    // Default to last 30 days if no range is selected yet
    final defaultRange = initialRange ?? DateTimeRange(
      start: DateUtils.dateOnly(now.subtract(const Duration(days: 30))),
      end: DateUtils.dateOnly(now),
    );

    // On small web viewports, use native HTML date inputs (mobile-friendly)
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _mobileBreakpoint;

    if (!isDesktop) {
      // Use two native date inputs sequentially for start and end
      Future<DateTime?> _pickNativeDate({DateTime? initial}) async {
        final completer = Completer<DateTime?>();
        final input = html.InputElement();
        input.type = 'date';
        if (initial != null) {
          // format as yyyy-MM-dd
          input.value = '${initial.year.toString().padLeft(4, '0')}-'
              '${initial.month.toString().padLeft(2, '0')}-'
              '${initial.day.toString().padLeft(2, '0')}';
        }
        // keep it off-screen but clickable
        input.style.position = 'absolute';
        input.style.left = '-9999px';
        html.document.body!.append(input);

        late StreamSubscription sub; sub = input.onChange.listen((_) {
          final val = input.value;
          input.remove();
          sub.cancel();
          if (val == null || val.isEmpty) {
            completer.complete(null);
            return;
          }
          try {
            completer.complete(DateTime.parse(val));
          } catch (_) {
            completer.complete(null);
          }
        });

        input.click();
        return completer.future;
      }

      // pick start
      final start = await _pickNativeDate(initial: defaultRange.start);
      if (start == null) return null;
      // pick end
      final end = await _pickNativeDate(initial: defaultRange.end);
      if (end == null) return null;

      return DateTimeRange(start: DateUtils.dateOnly(start), end: DateUtils.dateOnly(end));
    }

    return await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: defaultRange,
      currentDate: now,
      builder: (context, child) {
        final theme = Theme.of(context);
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isDesktop = screenWidth >= _mobileBreakpoint;

        if (!isDesktop) {
          final constrainedSize = Size(
            screenWidth * 0.94,
            screenHeight * 0.9,
          );

          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.colorScheme.primary,
                onPrimary: theme.colorScheme.onPrimary,
                surface: theme.colorScheme.surfaceContainer,
                onSurface: theme.colorScheme.onSurface,
              ),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: constrainedSize),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constrainedSize.width,
                    maxHeight: constrainedSize.height,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
        }

        return Theme(
          data: theme.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            canvasColor: Colors.transparent,
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surfaceContainer,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: 480,
              height: 600,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
  }

  /// Opens a responsive Single Date Picker.
  /// - Desktop: Compact centered card layout (400x520) with dark theme styling
  /// - Mobile: Standard adaptive dialog layout
  /// - Automatically defaults to today's date if [initialDate] is null
  static Future<DateTime?> pickDate({
    required BuildContext context,
    DateTime? initialDate,
  }) async {
    final now = DateTime.now();
    final defaultDate = initialDate ?? now;

    // For single-date picker: swap to native HTML input on small web viewports
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _mobileBreakpoint;

    if (!isDesktop) {
      final completer = Completer<DateTime?>();
      final input = html.InputElement();
      input.type = 'date';
      final d = defaultDate;
      input.value = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      input.style.position = 'absolute';
      input.style.left = '-9999px';
      html.document.body!.append(input);

      late StreamSubscription sub; sub = input.onChange.listen((_) {
        final val = input.value;
        input.remove();
        sub.cancel();
        if (val == null || val.isEmpty) {
          completer.complete(null);
          return;
        }
        try {
          completer.complete(DateTime.parse(val));
        } catch (_) {
          completer.complete(null);
        }
      });

      input.click();
      return completer.future;
    }

    return await showDatePicker(
      context: context,
      initialDate: defaultDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: now,
      builder: (context, child) {
        final theme = Theme.of(context);
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isDesktop = screenWidth >= _mobileBreakpoint;

        if (!isDesktop) {
          final constrainedSize = Size(
            screenWidth * 0.94,
            screenHeight * 0.9,
          );

          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.colorScheme.primary,
                onPrimary: theme.colorScheme.onPrimary,
                surface: theme.colorScheme.surfaceContainer,
                onSurface: theme.colorScheme.onSurface,
              ),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: constrainedSize),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constrainedSize.width,
                    maxHeight: constrainedSize.height,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
        }

        return Theme(
          data: theme.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            canvasColor: Colors.transparent,
            dialogBackgroundColor: Colors.transparent,
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surfaceContainer,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: 400,
              height: 520,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}
