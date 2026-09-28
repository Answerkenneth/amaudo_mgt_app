import 'package:cloud_firestore/cloud_firestore.dart';


enum Gender { male, female, preferNotToSay }

extension GenderX on Gender {
  String get label {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  String get storageValue => name;

  static Gender? fromStorageValue(String? value) {
    if (value == null) return null;
    return Gender.values
        .where((g) => g.storageValue == value)
        .cast<Gender?>()
        .firstWhere((_) => true, orElse: () => null);
  }
}
enum UserRole {
  patient,
  nurse,
  doctor,
  staff,
  director,
  ceo,
  admin,
  cmhpCoordinator,
  chp,
  other,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.patient:
        return 'Patient';
      case UserRole.nurse:
        return 'Nurse';
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.staff:
        return 'Staff';
      case UserRole.director:
        return 'Director';
      case UserRole.ceo:
        return 'CEO';
      case UserRole.admin:
        return 'Admin';
      case UserRole.cmhpCoordinator:
        return 'CMHP Coordinator';
      case UserRole.chp:
        return 'Chief Health Practitioner';
      case UserRole.other:
        return 'Other';
    }
  }

  String get storageValue => name;

  static UserRole fromStorageValue(String value) {
    return UserRole.values.firstWhere(
      (r) => r.storageValue == value,
      orElse: () => UserRole.other,
    );
  }
}

/// Represents a user document stored at `users/{uid}`.
class UserModel {
  final String uid;
  final String fullName;
  final String? email;
  final String? phone;
  final Gender? gender;
   final int? age;
  final UserRole role;
  final String? customRole;
  final bool isActive;
  final bool mustChangePassword;
  final String authProvider;
  final String? country;
  final String? state;
  final String? localGovernmentArea;
  final String? address;
  final String? workplace;
  final String? workLocation;
  final String? hearAboutAmaudo;
  final String? hearAboutAmaudoOther;
  final String? chpClinicalRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    this.email,
    this.phone,
    this.gender,
    this.age,
    required this.role,
    this.customRole,
    this.isActive = true,
    this.mustChangePassword = false,
    this.authProvider = 'password',
    this.country,
    this.state,
    this.localGovernmentArea,
    this.address,
    this.workplace,
    this.workLocation,
    this.hearAboutAmaudo,
    this.hearAboutAmaudoOther,
    this.chpClinicalRole,
    this.createdAt,
    this.updatedAt,
  });

  String get displayRole {
    if (role == UserRole.other && (customRole?.trim().isNotEmpty ?? false)) {
      return customRole!.trim();
    }
    return role.label;
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'fullName': fullName.trim(),
      'email': email,
      'phone': phone,
      'gender': gender?.storageValue,
      'age': age,
      'role': role.storageValue,
      'customRole': role == UserRole.other ? (customRole?.trim() ?? '') : null,
      'isActive': isActive,
      'mustChangePassword': false,
      'authProvider': authProvider,
      'country': country,
      'state': state,
      'localGovernmentArea': localGovernmentArea,
      'address': address,
      'workplace': workplace,
      'workLocation': workLocation,
      'chpClinicalRole': chpClinicalRole,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
            gender: GenderX.fromStorageValue(map['gender'] as String?),
      // Nullable and default-safe: older documents have no 'age' key,
      // and Firestore numeric fields can come back as int or num
      // depending on platform, hence the (num?).toInt().
      age: (map['age'] as num?)?.toInt(),
      role: UserRoleX.fromStorageValue(map['role'] as String? ?? 'other'),
      customRole: map['customRole'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
      authProvider: map['authProvider'] as String? ?? 'password',
      country: map['country'] as String?,
      state: map['state'] as String?,
      localGovernmentArea: map['localGovernmentArea'] as String?,
      address: map['address'] as String?,
      workplace: map['workplace'] as String?,
      workLocation: map['workLocation'] as String?,
      chpClinicalRole: map['chpClinicalRole'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User document ${doc.id} has no data.');
    }
    return UserModel.fromMap({...data, 'uid': data['uid'] as String? ?? doc.id});
  }
}