import 'package:json_annotation/json_annotation.dart';

part 'item.g.dart';

@JsonSerializable()
class Item {
  const Item({
    required this.id,
    required this.title,
    required this.done,
    required this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);

  final String id;
  final String title;
  final bool done;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$ItemToJson(this);

  Item copyWith({String? title, bool? done}) => Item(
    id: id,
    title: title ?? this.title,
    done: done ?? this.done,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Item &&
      other.id == id &&
      other.title == title &&
      other.done == done &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, title, done, updatedAt);
}
