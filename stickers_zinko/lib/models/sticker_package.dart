class StickerPackage {
  final String name;
  final String author;
  final List<String> imagePaths;

  StickerPackage({
    required this.name,
    required this.author,
    required this.imagePaths,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'author': author,
      'imagePaths': imagePaths,
    };
  }

  factory StickerPackage.fromJson(Map<String, dynamic> json) {
    return StickerPackage(
      name: json['name'] as String,
      author: json['author'] as String,
      imagePaths: List<String>.from(json['imagePaths'] as List),
    );
  }
}