// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 10;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String,
      subscriptionPlan: fields[1] as SubscriptionPlan,
      premiumExpiryDate: fields[2] as DateTime?,
      weeklyRecipeGenerationCount: fields[3] as int,
      weeklyPhotoUploadCount: fields[4] as int,
      bonusRecipeCredits: fields[5] as int,
      currentWeekStartDate: fields[6] as DateTime?,
      shoppingReminderEnabled: fields[7] as bool,
      shoppingReminderDay: fields[8] as DayOfWeek?,
      shoppingReminderHour: fields[9] as int?,
      shoppingReminderMinute: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subscriptionPlan)
      ..writeByte(2)
      ..write(obj.premiumExpiryDate)
      ..writeByte(3)
      ..write(obj.weeklyRecipeGenerationCount)
      ..writeByte(4)
      ..write(obj.weeklyPhotoUploadCount)
      ..writeByte(5)
      ..write(obj.bonusRecipeCredits)
      ..writeByte(6)
      ..write(obj.currentWeekStartDate)
      ..writeByte(7)
      ..write(obj.shoppingReminderEnabled)
      ..writeByte(8)
      ..write(obj.shoppingReminderDay)
      ..writeByte(9)
      ..write(obj.shoppingReminderHour)
      ..writeByte(10)
      ..write(obj.shoppingReminderMinute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubscriptionPlanAdapter extends TypeAdapter<SubscriptionPlan> {
  @override
  final int typeId = 9;

  @override
  SubscriptionPlan read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SubscriptionPlan.free;
      case 1:
        return SubscriptionPlan.monthly;
      case 2:
        return SubscriptionPlan.yearly;
      default:
        return SubscriptionPlan.free;
    }
  }

  @override
  void write(BinaryWriter writer, SubscriptionPlan obj) {
    switch (obj) {
      case SubscriptionPlan.free:
        writer.writeByte(0);
        break;
      case SubscriptionPlan.monthly:
        writer.writeByte(1);
        break;
      case SubscriptionPlan.yearly:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
