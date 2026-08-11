// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 5;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      id: fields[0] as String,
      title: fields[1] as String,
      mealType: fields[2] as MealType,
      ingredients: (fields[3] as List).cast<Ingredient>(),
      steps: (fields[4] as List).cast<String>(),
      nutrient: fields[5] as Nutrient,
      cookingMethod: fields[6] as CookingMethod,
      servings: fields[7] as int,
      prepTimeMinutes: fields[8] as int,
      cookTimeMinutes: fields[9] as int,
      createdAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.mealType)
      ..writeByte(3)
      ..write(obj.ingredients)
      ..writeByte(4)
      ..write(obj.steps)
      ..writeByte(5)
      ..write(obj.nutrient)
      ..writeByte(6)
      ..write(obj.cookingMethod)
      ..writeByte(7)
      ..write(obj.servings)
      ..writeByte(8)
      ..write(obj.prepTimeMinutes)
      ..writeByte(9)
      ..write(obj.cookTimeMinutes)
      ..writeByte(10)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CookingMethodAdapter extends TypeAdapter<CookingMethod> {
  @override
  final int typeId = 3;

  @override
  CookingMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CookingMethod.airFryer;
      case 1:
        return CookingMethod.oven;
      case 2:
        return CookingMethod.stovetop;
      case 3:
        return CookingMethod.grill;
      case 4:
        return CookingMethod.noCook;
      case 5:
        return CookingMethod.other;
      default:
        return CookingMethod.airFryer;
    }
  }

  @override
  void write(BinaryWriter writer, CookingMethod obj) {
    switch (obj) {
      case CookingMethod.airFryer:
        writer.writeByte(0);
        break;
      case CookingMethod.oven:
        writer.writeByte(1);
        break;
      case CookingMethod.stovetop:
        writer.writeByte(2);
        break;
      case CookingMethod.grill:
        writer.writeByte(3);
        break;
      case CookingMethod.noCook:
        writer.writeByte(4);
        break;
      case CookingMethod.other:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookingMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealTypeAdapter extends TypeAdapter<MealType> {
  @override
  final int typeId = 4;

  @override
  MealType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MealType.breakfast;
      case 1:
        return MealType.lunch;
      case 2:
        return MealType.dinner;
      default:
        return MealType.breakfast;
    }
  }

  @override
  void write(BinaryWriter writer, MealType obj) {
    switch (obj) {
      case MealType.breakfast:
        writer.writeByte(0);
        break;
      case MealType.lunch:
        writer.writeByte(1);
        break;
      case MealType.dinner:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
