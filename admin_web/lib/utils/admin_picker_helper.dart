import 'package:flutter/material.dart';

class AdminPickerHelper {
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

    return await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: defaultRange,
      currentDate: now,
      builder: (context, child) {
        final theme = Theme.of(context);
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 700;

        if (!isDesktop) {
          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.colorScheme.primary,
                onPrimary: theme.colorScheme.onPrimary,
                surface: theme.colorScheme.surfaceContainer,
                onSurface: theme.colorScheme.onSurface,
              ),
            ),
            child: child!,
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

    return await showDatePicker(
      context: context,
      initialDate: defaultDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: now,
      builder: (context, child) {
        final theme = Theme.of(context);
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 700;

        if (!isDesktop) {
          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.colorScheme.primary,
                onPrimary: theme.colorScheme.onPrimary,
                surface: theme.colorScheme.surfaceContainer,
                onSurface: theme.colorScheme.onSurface,
              ),
            ),
            child: child!,
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
