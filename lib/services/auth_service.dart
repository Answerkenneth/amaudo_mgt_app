import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/patient_record_model.dart';
import '../utils/validators.dart';
import 'auth_exception.dart';
import 'role_slot_service.dart';
import 'session_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
export 'auth_exception.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const String _webGoogleClientId =
      '412038702642-2g715k4tkeuelif6972gldop99jdvc2v.apps.googleusercontent.com';

  bool _googleSignInInitialized = false;

  static const String _usersCollection = 'users';
  static const String _phoneIndexCollection = 'phoneIndex';
  static const String _emailIndexCollection = 'emailIndex';
  static const String _syntheticEmailDomain = 'phoneauth.amaudo.app';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  // ---------------------------------------------------------------------
  // REGISTRATION
  // ---------------------------------------------------------------------

  Future<UserModel> registerWithPhoneAndPassword({
    required String fullName,
    required String phone,
    required String password,
    String? email,
    Gender? gender,
    int? age,
    required UserRole role,
    String? chpClinicalRole,
    String? customRole,
    String? country,
    String? state,
    String? localGovernmentArea,
    String? address,
    String? workplace,
    String? workLocation,
    String? hearAboutAmaudo,
    String? hearAboutAmaudoOther,
  }) async {
    final normalizedPhone = Validators.normalizePhone(phone);
    final normalizedEmail =
        (email != null && email.trim().isNotEmpty)
            ? Validators.normalizeEmail(email)
            : null;

    if (await _phoneIndexExists(normalizedPhone)) {
      throw const AuthException(
        'An account already exists with this phone number.',
      );
    }
    if (normalizedEmail != null && await _emailIndexExists(normalizedEmail)) {
      throw const AuthException(
        'An account already exists with this email.',
      );
    }

    final authEmail = normalizedEmail ?? _generateSyntheticEmail();

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }

    final uid = credential.user?.uid;
    if (uid == null) {
      throw const AuthException(
        'Registration could not be completed. Please try again.',
      );
    }

    try {
      await credential.user!.getIdToken(true);
    } catch (_) {}

    String? cleanValue(String? v) =>
        (v != null && v.trim().isNotEmpty) ? v.trim() : null;

        final model = UserModel(
      uid: uid,
      fullName: fullName,
      phone: normalizedPhone,
      email: normalizedEmail,
      gender: gender,
      age: age,
      role: role,
      customRole: customRole,
      authProvider: 'password',
      country: cleanValue(country),
      state: cleanValue(state),
      localGovernmentArea: cleanValue(localGovernmentArea),
      address: cleanValue(address),
      workplace: cleanValue(workplace),
      workLocation: cleanValue(workLocation),
      chpClinicalRole: role == UserRole.chp ? chpClinicalRole : null,
      hearAboutAmaudo:
          role == UserRole.patient ? cleanValue(hearAboutAmaudo) : null,
      hearAboutAmaudoOther:
          role == UserRole.patient ? cleanValue(hearAboutAmaudoOther) : null,
    );

    try {
      await _firestore.runTransaction((transaction) async {
        final phoneRef =
            _firestore.collection(_phoneIndexCollection).doc(normalizedPhone);
        final phoneSnap = await transaction.get(phoneRef);
        if (phoneSnap.exists) {
          throw const AuthException(
            'An account already exists with this phone number.',
          );
        }

        DocumentReference<Map<String, dynamic>>? emailRef;
        if (normalizedEmail != null) {
          emailRef = _firestore
              .collection(_emailIndexCollection)
              .doc(normalizedEmail);
          final emailSnap = await transaction.get(emailRef);
          if (emailSnap.exists) {
            throw const AuthException(
              'An account already exists with this email.',
            );
          }
        }

        if (RoleSlotService.isPrivileged(role)) {
          await RoleSlotService.instance.claimWithinTransaction(
            transaction: transaction,
            firestore: _firestore,
            role: role,
            uid: uid,
          );
        }

               // ignore: avoid_print
        print('registerWithPhoneAndPassword: gender param = $gender, '
            'toCreateMap()["gender"] = ${model.toCreateMap()["gender"]}');
        transaction.set(
          _firestore.collection(_usersCollection).doc(uid),
          model.toCreateMap(),
        );
        transaction.set(phoneRef, {
          'uid': uid,
          'authEmail': authEmail,
          'provider': 'password',
        });
        if (emailRef != null) {
          transaction.set(emailRef, {
            'uid': uid,
            'authEmail': authEmail,
            'provider': 'password',
          });
        }

        if (role == UserRole.patient) {
          final patientRef = _firestore.collection('patients').doc(uid);
          final phc = (workplace != null && workplace.trim().isNotEmpty)
              ? workplace.trim()
              : null;
          transaction.set(
            patientRef,
            PatientRecordModel(
              patientUid: uid,
              primaryHealthcareCenter: phc,
              createdBy: uid,
            ).toCreateMap(createdByUid: uid),
          );
        }
      });
       } on AuthException {
      await credential.user?.delete().catchError((_) {});
      rethrow;
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print(
        'registerWithPhoneAndPassword FirebaseException: '
        'code=${e.code} message=${e.message}',
      );
      await credential.user?.delete().catchError((_) {});
      throw AuthException(_mapFirestoreError(e));
    }
    try {
      await credential.user?.updateDisplayName(fullName.trim());
    } catch (_) {}

    return model;
  }

  Future<bool> isPrivilegedRoleTaken(UserRole role) {
    return RoleSlotService.instance.isRoleTaken(
      firestore: _firestore,
      role: role,
    );
  }

  // ---------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------

  Future<void> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final isEmail = trimmed.contains('@');

    final normalizedId = isEmail
        ? Validators.normalizeEmail(trimmed)
        : Validators.normalizePhone(trimmed);
    final collection = isEmail ? _emailIndexCollection : _phoneIndexCollection;

    DocumentSnapshot<Map<String, dynamic>> indexDoc;
    try {
      indexDoc =
          await _firestore.collection(collection).doc(normalizedId).get();
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }

    if (!indexDoc.exists) {
      throw const AuthException('Incorrect phone/email or password.');
    }

    final data = indexDoc.data();
    final authEmail = data?['authEmail'] as String?;
    final provider = data?['provider'] as String?;

    if (authEmail == null || provider == 'google') {
      throw const AuthException(
        'This account uses Google Sign-In. Please continue with Google.',
      );
    }

    UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapIdentifierAuthError(e));
    }

    try {
      await credential.user?.getIdToken(true);
    } catch (_) {}
  }

  String _generateSyntheticEmail() {
    final random = Random.secure();
    final bytes = List<int>.generate(20, (_) => random.nextInt(256));
    final token =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$token@$_syntheticEmailDomain';
  }

  Future<bool> _phoneIndexExists(String normalizedPhone) async {
    try {
      final doc = await _firestore
          .collection(_phoneIndexCollection)
          .doc(normalizedPhone)
          .get();
      return doc.exists;
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }
  }

  Future<bool> _emailIndexExists(String normalizedEmail) async {
    try {
      final doc = await _firestore
          .collection(_emailIndexCollection)
          .doc(normalizedEmail)
          .get();
      return doc.exists;
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }
  }

  // ---------------------------------------------------------------------
  // PASSWORD RECOVERY — self-service, free tier only.
  // ---------------------------------------------------------------------

  /// (Chunk 4B regression fix) Resolves the given phone-or-email
  /// identifier and, where possible, sends a genuine Firebase
  /// password-reset email — using ONLY the phoneIndex/emailIndex
  /// `authEmail` field, which is deliberately public/pre-auth
  /// readable by design.
  ///
  /// A previous version of this method also read `users/{uid}.email`
  /// as a fallback "authoritative" source. That read requires
  /// `request.auth != null` under the Firestore rules, but this
  /// method is called from the Forgot Password screen BEFORE the
  /// user is signed in — so that read always failed with
  /// permission-denied. It has been removed. `authEmail` already
  /// holds the real email directly for every account registered
  /// since the synthetic-email architecture fix, so no additional
  /// read is needed here.
  Future<void> requestPasswordReset({required String identifier}) async {
    final trimmed = identifier.trim();
    final isEmail = trimmed.contains('@');
    final normalized = isEmail
        ? Validators.normalizeEmail(trimmed)
        : Validators.normalizePhone(trimmed);
    final collection = isEmail ? _emailIndexCollection : _phoneIndexCollection;

    DocumentSnapshot<Map<String, dynamic>> indexDoc;
    try {
      indexDoc = await _firestore.collection(collection).doc(normalized).get();
    } on FirebaseException catch (e) {
      developer.log(
        'requestPasswordReset indexDoc read FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoRecovery',
        error: e,
      );
      throw AuthException(_mapFirestoreError(e));
    }

    if (!indexDoc.exists) {
      return;
    }

    final indexData = indexDoc.data();
    final authEmail = indexData?['authEmail'] as String?;
    final provider = indexData?['provider'] as String?;

    if (authEmail == null || provider == 'google') {
      throw const AuthException(
        'This account uses Google Sign-In. Please continue with Google.',
      );
    }

    final hasRealEmail = !authEmail.endsWith('@$_syntheticEmailDomain');

    if (!hasRealEmail) {
      throw const AuthException(
        'No email is on file for this account, so a self-service reset '
        'link cannot be sent. Please contact an Amaudo administrator '
        'for account recovery assistance.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: authEmail);
    } on FirebaseAuthException catch (e) {
      developer.log(
        'sendPasswordResetEmail FirebaseAuthException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoRecovery',
        error: e,
      );
      if (e.code == 'network-request-failed' ||
          e.code == 'too-many-requests') {
        throw AuthException(_mapIdentifierAuthError(e));
      }
      return;
    } catch (e, st) {
      developer.log(
        'sendPasswordResetEmail UNEXPECTED exception -> '
        '${e.runtimeType}: $e',
        name: 'AmaudoRecovery',
        error: e,
        stackTrace: st,
      );
      throw const AuthException(
        'Could not process your request. Please try again.',
      );
    }
  }

  Future<UserModel?> findAccountForRecovery({
    required String identifier,
  }) async {
    final trimmed = identifier.trim();
    final isEmail = trimmed.contains('@');
    final normalized = isEmail
        ? Validators.normalizeEmail(trimmed)
        : Validators.normalizePhone(trimmed);
    final collection = isEmail ? _emailIndexCollection : _phoneIndexCollection;

    DocumentSnapshot<Map<String, dynamic>> indexDoc;
    try {
      indexDoc = await _firestore.collection(collection).doc(normalized).get();
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }

    if (!indexDoc.exists) return null;

    final uid = indexDoc.data()?['uid'] as String?;
    if (uid == null) return null;

    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(uid).get();
      if (!userDoc.exists) return null;
      return UserModel.fromSnapshot(userDoc);
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final tokenResult = await user.getIdTokenResult(true);
      return tokenResult.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // REMEMBER ME
  // ---------------------------------------------------------------------

  Future<void> applyRememberMePreference(bool rememberMe) async {
    if (kIsWeb) {
      try {
        await _auth.setPersistence(
          rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      } catch (_) {}
    } else {
      await SessionPreferences.instance.setRememberMe(rememberMe);
    }
  }

  // ---------------------------------------------------------------------
  // GOOGLE SIGN-IN
  // ---------------------------------------------------------------------

   Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    if (kIsWeb) {
      if (_webGoogleClientId.startsWith('REPLACE_WITH_')) {
        developer.log(
          'Web Google Sign-In is not configured: _webGoogleClientId in '
          'auth_service.dart still contains the placeholder value.',
          name: 'AmaudoGoogleAuth',
        );
        throw const AuthException(
          'Google Sign-In is not set up for the web yet. '
          'Please contact support.',
        );
      }
      await _googleSignIn.initialize(clientId: _webGoogleClientId);
    } else {
      // ANDROID/iOS: serverClientId (always the WEB client, never the
      // Android client) is what lets Google issue an ID token whose
      // audience Firebase Auth can verify. Without it, Credential
      // Manager can still let the user pick an account, but the
      // subsequent token exchange has no valid linked audience to
      // resolve against — which is what surfaces as
      // "Error 400: origin_mismatch" right after account selection.
      await _googleSignIn.initialize(serverClientId: _webGoogleClientId);
    }

    _googleSignInInitialized = true;
  }
    /// Public so the web-only rendered-button widget can make sure the
  /// GIS client is initialized (and the placeholder-client-ID guard
  /// above has run) before it renders the button or subscribes to
  /// authenticationEvents.
  Future<void> ensureGoogleSignInReady() => _ensureGoogleSignInInitialized();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

         return await _completeGoogleAuthentication(googleUser);
    } on GoogleLinkRequiredException {
      rethrow;
    } on GoogleSignInException catch (e) {
      developer.log(
        'GoogleSignInException -> code: ${e.code}, '
        'description: ${e.description}, details: ${e.details}',
        name: 'AmaudoGoogleAuth',
        error: e,
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      // Temporary: surface the real code/description in the message
      // itself while diagnosing the post-migration Android issue —
      // same technique that found the web UnimplementedError earlier.
      throw AuthException(
        'Google sign-in failed (${e.code}): '
        '${e.description ?? e.details ?? 'no further detail'}',
      );
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException during Google sign-in -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoGoogleAuth',
        error: e,
      );
      throw AuthException(
        'Google sign-in failed (${e.code}): ${e.message ?? _mapAuthError(e)}',
      );
    } on AuthException {
      rethrow;
    } catch (e, st) {
      developer.log(
        'UNEXPECTED exception during Google sign-in -> '
        '${e.runtimeType}: $e',
        name: 'AmaudoGoogleAuth',
        error: e,
        stackTrace: st,
      );
      throw AuthException('Google sign-in failed: ${e.runtimeType}: $e');
    }
  }
  /// WEB ONLY entry point. authenticate() is not implemented on web,
  /// so the web UI instead renders Google's own button and listens to
  /// GoogleSignIn.instance.authenticationEvents; once that stream
  /// delivers a signed-in GoogleSignInAccount, the login screen calls
  /// this to run it through the exact same completion logic (account
  /// linking included) that signInWithGoogle() uses for Android.
  Future<UserCredential?> completeGoogleSignInFromWebEvent(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      await _ensureGoogleSignInInitialized();
      return await _completeGoogleAuthentication(googleUser);
    } on GoogleLinkRequiredException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException during web Google sign-in -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoGoogleAuth',
        error: e,
      );
      // Web-only diagnostic detail — dart:developer.log doesn't
      // reliably show up on a deployed (non-debug) web build.
      throw AuthException(
        'Google sign-in failed (${e.code}): ${e.message ?? 'no message'}',
      );
    } on AuthException {
      rethrow;
    } catch (e, st) {
      developer.log(
        'UNEXPECTED exception during web Google sign-in -> '
        '${e.runtimeType}: $e',
        name: 'AmaudoGoogleAuth',
        error: e,
        stackTrace: st,
      );
      throw AuthException('Google sign-in failed: ${e.runtimeType}: $e');
    }
  }

  /// Shared by both signInWithGoogle() (Android) and
  /// completeGoogleSignInFromWebEvent() (web) once each has, by
  /// whichever platform-appropriate means, obtained a
  /// GoogleSignInAccount. Everything from here on — credential
  /// creation, account linking, and profile bootstrap — is identical
  /// for both platforms.
  Future<UserCredential> _completeGoogleAuthentication(
    GoogleSignInAccount googleUser,
  ) async {
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      developer.log(
        'Google authenticate() succeeded but idToken was null.',
        name: 'AmaudoGoogleAuth',
      );
      throw const AuthException(
        'Google sign-in failed. Please try again.',
      );
    }

    final googleCredential = GoogleAuthProvider.credential(idToken: idToken);

    UserCredential userCredential;

    if (!kIsWeb) {
      // ANDROID ONLY: try signing in with the Google credential
      // directly first. If this Google account was already linked
      // to an Amaudo account — whether that link happened moments
      // ago or long before — Firebase Auth authenticates straight
      // into that account here, with no password re-verification.
      // Only a genuine, not-yet-linked email collision reaches the
      // catch below, which is the one case that still needs the
      // existing "verify your Amaudo password to link" flow.
      try {
        userCredential = await _auth.signInWithCredential(googleCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'account-exists-with-different-credential') rethrow;

        final rawEmail = googleUser.email.trim();
        if (rawEmail.isEmpty) rethrow;

        final normalizedEmail = Validators.normalizeEmail(rawEmail);
        DocumentSnapshot<Map<String, dynamic>> emailDoc;
        try {
          emailDoc = await _firestore
              .collection(_emailIndexCollection)
              .doc(normalizedEmail)
              .get();
        } on FirebaseException catch (e2) {
          throw AuthException(_mapFirestoreError(e2));
        }

        final data = emailDoc.data();
        final existingAuthEmail = data?['authEmail'] as String?;
        if (emailDoc.exists && existingAuthEmail != null) {
          throw GoogleLinkRequiredException(
            pendingGoogleCredential: googleCredential,
            authEmail: existingAuthEmail,
          );
        }
        rethrow;
      }
       } else {
      // WEB: was a pre-check against emailIndex.provider — but that
      // field is never updated after linkGoogleToPasswordAccount()
      // succeeds (emailIndex docs are immutable by rules design), so
      // it always read 'password' and re-triggered the link flow on
      // every subsequent login. Now mirrors the Android fix exactly:
      // try signing in with the credential first, and only fall back
      // to the "verify your Amaudo password to link" flow on a
      // genuine, not-yet-linked email collision.
      try {
        userCredential = await _auth.signInWithCredential(googleCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'account-exists-with-different-credential') rethrow;

        final rawEmail = googleUser.email.trim();
        if (rawEmail.isEmpty) rethrow;

        final normalizedEmail = Validators.normalizeEmail(rawEmail);
        DocumentSnapshot<Map<String, dynamic>> emailDoc;
        try {
          emailDoc = await _firestore
              .collection(_emailIndexCollection)
              .doc(normalizedEmail)
              .get();
        } on FirebaseException catch (e2) {
          throw AuthException(_mapFirestoreError(e2));
        }

        final data = emailDoc.data();
        final existingAuthEmail = data?['authEmail'] as String?;
        if (emailDoc.exists && existingAuthEmail != null) {
          throw GoogleLinkRequiredException(
            pendingGoogleCredential: googleCredential,
            authEmail: existingAuthEmail,
          );
        }
        rethrow;
      }
    }

    await userCredential.user?.getIdToken(true);

    if (userCredential.user != null) {
      await _ensureUserProfileForGoogleUser(
        firebaseUser: userCredential.user!,
        googleUser: googleUser,
      );
    }

    return userCredential;
  }
  Future<UserCredential> linkGoogleToPasswordAccount({
    required String authEmail,
    required String password,
    required AuthCredential pendingGoogleCredential,
  }) async {
    UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapIdentifierAuthError(e));
    }

    try {
      await credential.user!.linkWithCredential(pendingGoogleCredential);
    } on FirebaseAuthException catch (e) {
      developer.log(
        'linkWithCredential FirebaseAuthException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoGoogleAuth',
        error: e,
      );
      throw AuthException(_mapAuthError(e));
    }

    try {
      await credential.user?.getIdToken(true);
    } catch (_) {}

    return credential;
  }

  Future<void> _ensureUserProfileForGoogleUser({
    required User firebaseUser,
    required GoogleSignInAccount googleUser,
  }) async {
    final uid = firebaseUser.uid;
    final userRef = _firestore.collection(_usersCollection).doc(uid);

    DocumentSnapshot<Map<String, dynamic>> existing;
    try {
      existing = await userRef.get();
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }

    if (existing.exists) {
      return;
    }

    final rawEmail = googleUser.email.trim();
    final normalizedEmail =
        rawEmail.isNotEmpty ? Validators.normalizeEmail(rawEmail) : null;

    final displayName = (googleUser.displayName?.trim().isNotEmpty ?? false)
        ? googleUser.displayName!.trim()
        : (firebaseUser.displayName?.trim().isNotEmpty ?? false)
            ? firebaseUser.displayName!.trim()
            : 'Amaudo User';

    final model = UserModel(
      uid: uid,
      fullName: displayName,
      email: normalizedEmail,
      phone: null,
      role: UserRole.other,
      customRole: 'Pending profile completion',
      authProvider: 'google',
    );

    try {
      await _firestore.runTransaction((transaction) async {
        transaction.set(userRef, model.toCreateMap());

        if (normalizedEmail != null) {
          final emailRef = _firestore
              .collection(_emailIndexCollection)
              .doc(normalizedEmail);
          final emailSnap = await transaction.get(emailRef);
          if (!emailSnap.exists) {
            transaction.set(emailRef, {
              'uid': uid,
              'authEmail': null,
              'provider': 'google',
            });
          }
        }
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }
  }

  // ---------------------------------------------------------------------
  // SHARED
  // ---------------------------------------------------------------------

  Future<UserModel?> fetchUserProfileByUid(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromSnapshot(doc);
    } on FirebaseException {
      return null;
    }
  }

     Future<void> signOut() async {
    // Best-effort: stop this device from receiving pushes for an
    // account it's no longer signed into. Never blocks sign-out.
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await removeFcmToken(token);
    } catch (_) {}

    await _auth.signOut();
    try {
      // Bounded with a timeout: google_sign_in's signOut() has been
      // observed to hang indefinitely (particularly on web, and for
      // accounts that never actually signed in via Google) — without
      // this, that hang would block the whole method forever, even
      // though _auth.signOut() above already completed.
      await _googleSignIn.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Registers this device's push token against the signed-in user.
  /// Cloud Functions read this array to know where to send pushes —
  /// see functions/notifications.js. Multiple tokens (multiple
  /// devices) are supported since this only ever adds, never
  /// replaces.
  Future<void> saveFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (_) {
      // Best-effort — must never block sign-in/app startup.
    }
  }

  Future<void> removeFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {}
  }

  Future<UserModel?> fetchCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    const maxAttempts = 4;
    const retryDelay = Duration(milliseconds: 350);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final doc =
            await _firestore.collection(_usersCollection).doc(uid).get();
        if (doc.exists) {
          return UserModel.fromSnapshot(doc);
        }
        return null;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' && attempt == maxAttempts) {
          throw AuthException(_mapFirestoreError(e));
        }
      }

      if (attempt < maxAttempts) {
        await Future.delayed(retryDelay);
      }
    }

    return null;
  }
    /// Lets a user (any role) set or change their own gender after
  /// registration — for accounts created before this field existed.
  /// Firestore rules already allow this: the update leaves 'role'
  /// and 'uid' untouched, which is all the users/{userId} update
  /// rule requires from a non-admin caller.
  Future<void> updateGender(Gender gender) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('You must be signed in to do this.');
    }
      
      try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'gender': gender.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print(
        'updateGender FirebaseException: code=${e.code} message=${e.message}',
      );
      throw AuthException(_mapFirestoreError(e));
    } catch (e, stack) {
      // Not a FirebaseException — surface the real cause instead of
      // letting the caller fall through to a generic message that
      // hides what actually happened.
      // ignore: avoid_print
      print('updateGender unexpected error: $e\n$stack');
      throw AuthException('Could not save gender: $e');
    }
  }
    /// Lets a user (any role) set or change their own age, mirroring
  /// updateGender exactly — same collection, same field-preserving
  /// update rule (only 'gender'/'age'/'updatedAt' are touched, so
  /// 'uid' and 'role' stay unchanged, which is all the users/{userId}
  /// update rule requires from a non-admin caller).
  Future<void> updateAge(int age) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('You must be signed in to do this.');
    }
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'age': age,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    } catch (e) {
      throw AuthException('Could not save age: $e');
    }
  }
  Future<int> countUsersByRole(UserRole role) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: role.storageValue)
          .count()
          .get();

      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }
  }
    Future<List<UserModel>> fetchUsersByRole(String role, {int limit = 200}) async {
    final snap = await _firestore.collection(_usersCollection).where('role', isEqualTo: role).limit(limit).get();
    return snap.docs.map(UserModel.fromSnapshot).toList();
  }

  Future<List<UserModel>> fetchAllUsersBounded({int limit = 200}) async {
    final snap = await _firestore.collection(_usersCollection).limit(limit).get();
    return snap.docs.map(UserModel.fromSnapshot).toList();
  }
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with these details.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists using a different sign-in method.';
      case 'credential-already-in-use':
        return 'This Google account is already linked to a different '
            'Amaudo account.';
      case 'provider-already-linked':
        return 'This Google account is already linked to your account.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String _mapIdentifierAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return 'Incorrect phone/email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to complete this action.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      default:
        return 'Could not save your profile. Please try again.';
    }
  }
}

