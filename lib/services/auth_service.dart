import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  // Simple login using email and password (for testing with database profiles)
  static Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Attempting login for: $email');
      
      // Query the profiles table directly for testing (bypass Supabase Auth)
      final response = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select()
          .eq('email', email)
          .eq('password', password) // Direct password comparison for testing
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid email or password');
      }

      print('✅ Login successful for: ${response['email']} (Role: ${response['role']})');
      
      // Store user session info (simple approach for testing)
      _currentUser = response;
      
      // For testing: Set a fake Supabase session to satisfy RLS
      await _setTestingSession(response);
      
      return response;
    } catch (e) {
      print('❌ Login failed: $e');
      throw Exception('Login failed: $e');
    }
  }

  // Set a testing session to satisfy RLS requirements
  static Future<void> _setTestingSession(Map<String, dynamic> user) async {
    try {
      // For testing purposes, we'll sign in anonymously to Supabase
      // This gives us an authenticated session that satisfies RLS
      final anonResponse = await _supabase.auth.signInAnonymously();
      
      if (anonResponse.user != null) {
        print('✅ Anonymous Supabase session created for RLS compliance');
      }
    } catch (e) {
      print('⚠️ Could not create anonymous session, but continuing: $e');
      // Continue without anonymous session - our RLS policies allow anon access
    }
  }

  // Simple signup (for testing)
  static Future<Map<String, dynamic>?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    try {
      print('📝 Creating account for: $email');
      
      // Extract company domain from email
      final companyDomain = email.split('@').last;
      
      // Insert new user into profiles table
      final userData = {
        'email': email,
        'password': password, // Plain text for testing
        'full_name': fullName,
        'role': role,
        'company_domain': companyDomain,
        'phone': phone,
        'is_active': true,
      };

      final response = await _supabase
          .from(SupabaseConfig.profilesTable)
          .insert(userData)
          .select()
          .single();

      print('✅ Account created successfully for: ${response['email']}');
      
      // Auto-login after signup
      _currentUser = response;
      await _setTestingSession(response);
      
      return response;
    } catch (e) {
      print('❌ Signup failed: $e');
      throw Exception('Failed to create account: $e');
    }
  }

  // Simple session management for testing
  static Map<String, dynamic>? _currentUser;

  static Future<Map<String, dynamic>?> getUserProfile() async {
    return _currentUser;
  }

  static Future<void> signOut() async {
    _currentUser = null;
    
    // Also sign out from Supabase auth if we have a session
    try {
      await _supabase.auth.signOut();
      print('👋 Supabase auth session ended');
    } catch (e) {
      print('⚠️ Error signing out from Supabase auth: $e');
    }
    
    print('👋 User signed out');
  }

  static bool get isLoggedIn => _currentUser != null;

  static String? get currentUserEmail => _currentUser?['email'];
  static String? get currentUserRole => _currentUser?['role'];
  static String? get currentUserCompany => _currentUser?['company_domain'];
}
