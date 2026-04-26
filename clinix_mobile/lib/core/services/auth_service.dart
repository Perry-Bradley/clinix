import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/api_constants.dart';

class AuthService {
  static const _baseUrl = ApiConstants.accounts;
  static const _storage = FlutterSecureStorage();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConstants.baseUrl}${ApiConstants.accounts}',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  // ─── Register (Basic) ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post('register/', data: {
      'full_name': fullName,
      'identifier': identifier,
      'password': password,
    });
    return response.data;
  }

  // ─── Role Selection ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> selectRole({required String userType}) async {
    final accessToken = await getAccessToken();
    final response = await _dio.post(
      'role-selection/',
      data: {'user_type': userType},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    
    // Update stored user type
    await _storage.write(key: 'user_type', value: userType);
    return response.data;
  }

  // ─── Login ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post('login/', data: {
      'identifier': identifier,
      'password': password,
    });
    
    await saveTokens(
      access: response.data['access']?.toString() ?? '',
      refresh: response.data['refresh']?.toString() ?? '',
      userType: response.data['user_type'] ?? 'unassigned',
      fullName: response.data['full_name'],
    );
    return response.data;
  }

  // ─── Google OAuth ─────────────────────────────────────────────────────────
  
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static Future<Map<String, dynamic>?> signInWithGoogle({String? userType}) async {
    try {
      print("AuthService: Starting Google Sign-In...");
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        print("AuthService: Google Sign-In was cancelled by the user.");
        return null; 
      }

      print("AuthService: Google Sign-In successful. Authenticating with Firebase...");
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credentials
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final String? firebaseIdToken = await userCredential.user?.getIdToken(true); // Force refresh to be sure

      if (firebaseIdToken == null) {
        print("AuthService Error: Received null Firebase ID Token.");
        throw Exception("Could not retrieve Firebase ID Token. Ensure Firebase is correctly configured.");
      }

      print("AuthService: Firebase ID Token obtained. Sending to backend (userType: $userType)...");
      return await googleLogin(idToken: firebaseIdToken, userType: userType);
    } on FirebaseAuthException catch (e) {
      print("========== FIREBASE AUTH ERROR ==========");
      print("Code: ${e.code}");
      print("Message: ${e.message}");
      print("=========================================");
      rethrow;
    } on PlatformException catch (e) {
      print("========== GOOGLE SIGN-IN DEBUG INFO ==========");
      print("Error Code: ${e.code}");
      print("Error Message: ${e.message}");
      print("Details: ${e.details}");
      if (e.code == '10' || e.code == 'DEVELOPER_ERROR') {
        print("TIP: This usually means your SHA-1 fingerprint is NOT registered in Firebase Console.");
        print("TIP: Or your google-services.json is outdated/missing the Web Client ID.");
      }
      print("===============================================");
      rethrow;
    } catch (e) {
      print("AuthService: Unexpected error during Google Sign-In: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    String? userType,
  }) async {
    const path = 'google-auth/';
    final response = await _dio.post(path, data: {
      'id_token': idToken,
      'user_type': userType,
    });
    
    await saveTokens(
      access: response.data['access'],
      refresh: response.data['refresh'],
      userType: response.data['user_type'] ?? userType,
      fullName: response.data['full_name'],
    );
    return response.data;
  }

  // ─── Token Management ─────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String access,
    required String refresh,
    required String userType,
    String? fullName,
  }) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    await _storage.write(key: 'user_type', value: userType);
    if (fullName != null) await _storage.write(key: 'full_name', value: fullName);
  }

  static Future<String?> getUserType() async {
    return await _storage.read(key: 'user_type');
  }

  static Future<String?> getUserName() async {
    return await _storage.read(key: 'full_name');
  }

  /// Returns the user's preferred language ('en' or 'fr'), or null if unset.
  /// Reads the value the backend embedded in the login response when we
  /// stored it locally, falling back to the device locale.
  static Future<String?> getLanguagePref() async {
    final stored = await _storage.read(key: 'language_pref');
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  /// Decode the JWT access token and return the current user's UUID.
  static Future<String?> getCurrentUserId() async {
    final token = await getAccessToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // JWT payload is base64url-encoded (no padding).
      var payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decodedBytes = base64Url.decode(payload);
      final map = jsonDecode(utf8.decode(decodedBytes)) as Map<String, dynamic>;
      return map['user_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Refresh the access token using the stored refresh token.
  /// Returns the new access token, or null if refresh failed.
  static Future<String?> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await _dio.post('token/refresh/', data: {
        'refresh': refreshToken,
      });
      final newAccess = response.data['access']?.toString();
      if (newAccess != null && newAccess.isNotEmpty) {
        await _storage.write(key: 'access_token', value: newAccess);
        // If backend rotates refresh tokens, save the new one too
        final newRefresh = response.data['refresh']?.toString();
        if (newRefresh != null && newRefresh.isNotEmpty) {
          await _storage.write(key: 'refresh_token', value: newRefresh);
        }
        return newAccess;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _storage.deleteAll();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Email OTP Sending ──────────────────────────────────────────────────
 
  static Future<void> sendEmailOtp({required String email}) async {
    await _dio.post('otp/email/send/', data: {'email': email});
  }

  static Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _dio.post('otp/email/verify/', data: {
      'email': email,
      'otp': otp,
    });
    return response.data;
  }
 
  // ─── FCM Token ───────────────────────────────────────────────────────────

  static Future<void> saveFcmToken(String fcmToken) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return;
    try {
      await _dio.post(
        'fcm-token/',
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (e) {
      print('FCM token upload failed: $e');
    }
  }
}
