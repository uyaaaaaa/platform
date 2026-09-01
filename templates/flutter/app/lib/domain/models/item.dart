import 'package:json_annotation/json_annotation.dart';

part 'item.g.dart';

/// 機能横断で共有するドメインモデル。
///
/// API が返す形と画面が必要とする形が一致している間は、DTO を別に立てず
/// このモデルが両方を兼ねる。食い違いが生じた時点で DTO を分ける。
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
