// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IngredientAdapter extends TypeAdapter<Ingredient> {
  @override
  final int typeId = 2;

  @override
  Ingredient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ingredient(
      name: fields[0] as String,
      quantity: fields[1] as double,
      unit: fields[2] as String,
      category: fields[3] as IngredientCategory,
      isChecked: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Ingredient obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.isChecked);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IngredientCategoryAdapter extends TypeAdapter<IngredientCategory> {
  @override
  final int typeId = 1;

  @override
  IngredientCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IngredientCategory.produce;
      case 1:
        return IngredientCategory.butcher;
      case 2:
        return IngredientCategory.dairy;
      case 3:
        return IngredientCategory.pantry;
      case 4:
        return IngredientCategory.bakery;
      case 5:
        return IngredientCategory.other;
      default:
        return IngredientCategory.produce;
    }
  }

  @override
  void write(BinaryWriter writer, IngredientCategory obj) {
    switch (obj) {
      case IngredientCategory.produce:
        writer.writeByte(0);
        break;
      case IngredientCategory.butcher:
        writer.writeByte(1);
        break;
      case IngredientCategory.dairy:
        writer.writeByte(2);
        break;
      case IngredientCategory.pantry:
        writer.writeByte(3);
        break;
      case IngredientCategory.bakery:
        writer.writeByte(4);
        break;
      case IngredientCategory.other:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
