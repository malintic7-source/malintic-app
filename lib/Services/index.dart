/// Service exports for Gestion Malintic
/// 
/// Centralized exports for all business logic services.
/// Import from this file instead of individual service files.
///
/// Usage:
/// ```dart
/// import 'package:gestion_formations/Services/index.dart';
///
/// final db = LocalDataService();
/// final auth = AuthProvider();
/// ```
library;

// Auth & Session
export 'auth_provider.dart';
export 'tab_session_lifecycle.dart';

// Data & Sync
export 'db_services.dart';
export 'polling_config.dart';
export 'supabase_config.dart';
export 'supabase_mapper.dart';

// Storage
export 'local_storage.dart';

// Media & Files
export 'imagekit_service.dart';
export 'pdf_service.dart';
export 'pdf_helper.dart';
export 'invoice_service.dart';

// Business Logic
export 'notifications_services.dart';
export 'payment_report_service.dart';
export 'poles_d_services.dart';
