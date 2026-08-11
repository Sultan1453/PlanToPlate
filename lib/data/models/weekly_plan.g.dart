// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlannedMealAdapter extends TypeAdapter<PlannedMeal> {
  @override
  final int typeId = 7;

  @override
  PlannedMeal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedMeal(
      day: fields[0] as DayOfWeek,
      mealType: fields[1] as MealType,
      recipe: fields[2] as Recipe?,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedMeal obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.day)
      ..writeByte(1)
      ..write(obj.mealType)
      ..writeByte(2)
      ..write(obj.recipe);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedMealAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeeklyPlanAdapter extends TypeAdapter<WeeklyPlan> {
  @override
  final int typeId = 8;

  @override
  WeeklyPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyPlan(
      id: fields[0] as String,
      weekStartDate: fields[1] as DateTime,
      meals: (fields[2] as List?)?.cast<PlannedMeal>(),
      checkedAutoItemKeys: (fields[3] as List?)?.cast<String>(),
      manualItems: (fields[4] as List?)?.cast<Ingredient>(),
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyPlan obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weekStartDate)
      ..writeByte(2)
      ..write(obj.meals)
      ..writeByte(3)
      ..write(obj.checkedAutoItemKeys)
      ..writeByte(4)
      ..write(obj.manualItems);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayOfWeekAdapter extends TypeAdapter<DayOfWeek> {
  @override
  final int typeId = 6;

  @override
  DayOfWeek read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DayOfWeek.monday;
      case 1:
        return DayOfWeek.tuesday;
      case 2:
        return DayOfWeek.wednesday;
      case 3:
        return DayOfWeek.thursday;
      case 4:
        return DayOfWeek.friday;
      case 5:
        return DayOfWeek.saturday;
      case 6:
        return DayOfWeek.sunday;
      default:
        return DayOfWeek.monday;
    }
  }

  @override
  void write(BinaryWriter writer, DayOfWeek obj) {
    switch (obj) {
      case DayOfWeek.monday:
        writer.writeByte(0);
        break;
      case DayOfWeek.tuesday:
        writer.writeByte(1);
        break;
      case DayOfWeek.wednesday:
        writer.writeByte(2);
        break;
      case DayOfWeek.thursday:
        writer.writeByte(3);
        break;
      case DayOfWeek.friday:
        writer.writeByte(4);
        break;
      case DayOfWeek.saturday:
        writer.writeByte(5);
        break;
      case DayOfWeek.sunday:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayOfWeekAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
