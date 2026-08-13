class User {
  final String id;
  final String username;
  final String mobileNumber; // Now a string
  final String email;
  final String vehicleNumber;
  final String imageUrl;

  User({
    required this.id,
    required this.username,
    required this.mobileNumber,
    required this.email,
    required this.vehicleNumber,
    required this.imageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      username: json['userName'] ?? '', // Provide a default value for null
      mobileNumber: json['userMobile'] ?? '', // Provide a default value for null
      email: json['userEmail'] ?? '', // Provide a default value for null
      imageUrl: json['image'],
      vehicleNumber: json['vehicleNo'] ?? '', // Provide a default value for null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userName': username,
      'userMobile': mobileNumber,
      'userEmail': email,
      'vehicleNo': vehicleNumber,
    };
  }
}
