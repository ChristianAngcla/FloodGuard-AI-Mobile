class User {
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phoneNumber;
  final String password;
  final String barangay;

  User({
    this.firstName = '',
    this.lastName = '',
    required this.username,
    required this.email,
    this.phoneNumber = '',
    required this.password,
    required this.barangay,
  });
}
