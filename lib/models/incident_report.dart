import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum SeverityLevel {
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.medium:
        return 'Medium';
      case SeverityLevel.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case SeverityLevel.low:
        return AppColors.successGreen;
      case SeverityLevel.medium:
        return AppColors.warningOrange;
      case SeverityLevel.high:
        return AppColors.errorRed;
    }
  }

  // Enhanced color with better contrast
  Color get solidColor {
    switch (this) {
      case SeverityLevel.low:
        return const Color(0xFF16A34A); // Darker green
      case SeverityLevel.medium:
        return const Color(0xFFEA580C); // Darker orange
      case SeverityLevel.high:
        return const Color(0xFFDC2626); // Solid red
    }
  }

  String get name {
    switch (this) {
      case SeverityLevel.low:
        return 'low';
      case SeverityLevel.medium:
        return 'medium';
      case SeverityLevel.high:
        return 'high';
    }
  }
}

// Incident Report class for form data
class IncidentReport {
  final String? incidentType;
  final DateTime? incidentDate;
  final TimeOfDay? incidentTime;
  final SeverityLevel severityLevel;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final String detailedDescription;
  final String? regulationCategory;
  final String? accidentType;
  final String? causeOfDeath;
  final String? employeeName;
  final String? employerName;
  final bool submittedAnonymously;

  const IncidentReport({
    this.incidentType,
    this.incidentDate,
    this.incidentTime,
    this.severityLevel = SeverityLevel.medium,
    this.locationText,
    this.latitude,
    this.longitude,
    required this.detailedDescription,
    this.regulationCategory,
    this.accidentType,
    this.causeOfDeath,
    this.employeeName,
    this.employerName,
    this.submittedAnonymously = true,
  });
}