// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NutrientAdapter extends TypeAdapter<Nutrient> {
  @override
  final int typeId = 0;

  @override
  Nutrient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Nutrient(
      calories: fields[0] as double,
      protein: fields[1] as double,
      carbs: fields[2] as double,
      fat: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Nutrient obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.calories)
      ..writeByte(1)
      ..write(obj.protein)
      ..writeByte(2)
      ..write(obj.carbs)
      ..writeByte(3)
      ..write(obj.fat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutrientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
