class Spam {
  final int id;
  final String address;
  final String message;

  Spam({required this.id, required this.address, required this.message});

  factory Spam.fromJson(Map<String, dynamic> json) {
    return Spam(
      id: json['id'],
      address: json['address'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'address': address,
        'message': message,
      };
}
