/// 👤 User Profile Model - Represents a user's data from MongoDB
class UserProfile {
  final String uid;
  final String email;
  final String barangay;
  final String firstName;
  final String lastName;
  final String phone;
  final String houseNo;
  final String streetName;
  final String city;
  final String province;
  final String zipCode;
  final String country;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.barangay,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.houseNo,
    required this.streetName,
    required this.city,
    required this.province,
    required this.zipCode,
    required this.country,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    dynamic createdAtData = json['created_at'] ?? json['createdAt'];
    String dateString = '';

    if (createdAtData is Map && createdAtData.containsKey('\$date')) {
      dateString = createdAtData['\$date'];
    } else if (createdAtData is String) {
      dateString = createdAtData;
    }

    // Helper function to capitalize the first letter of each word
    String capitalize(String s) {
      if (s.isEmpty) return s;
      return s.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    return UserProfile(
      uid: json['uid'] ?? json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      barangay: json['barangay'] ?? 'Unknown',
      firstName: capitalize(json['firstName'] ?? json['first_name'] ?? ''),
      lastName: capitalize(json['lastName'] ?? json['last_name'] ?? ''),
      phone: json['phone'] ?? '',
      houseNo: json['houseNo'] ?? json['house_no'] ?? '',
      streetName: json['streetName'] ?? json['street_name'] ?? '',
      city: json['city'] ?? 'Marikina City',
      province: json['province'] ?? 'Metro Manila',
      zipCode: json['zipCode'] ?? json['zip_code'] ?? '1800',
      country: json['country'] ?? 'Philippines',
      createdAt: DateTime.tryParse(dateString) ?? DateTime.now(),
    );
  }
}
