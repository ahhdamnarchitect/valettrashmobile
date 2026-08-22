/// Property occupancy + billable-door rules (85% minimum for PM contracts).
abstract final class PropertyBilling {
  static const double defaultMinimumBillablePercent = 0.85;

  /// What the PROPERTY pays us per billable door, month to month. Not the
  /// resident-facing $25-35 -- the property bills its residents itself and keeps
  /// the spread. Fallback only; the real rate lives on `properties`.
  /// Mirrors the DB default set in migration 20260516000032.
  static const double defaultMonthlyFeePerDoor = 18.0;

  /// Doors the property pays for: at least [minPercent] of total units, or
  /// actual occupied count if higher.
  static int billableDoors({
    required int totalUnits,
    required int occupiedUnits,
    double minPercent = defaultMinimumBillablePercent,
  }) {
    if (totalUnits <= 0) return 0;
    final minimum = (totalUnits * minPercent).ceil();
    return occupiedUnits > minimum ? occupiedUnits : minimum;
  }

  static double occupancyPercent(int totalUnits, int occupiedUnits) {
    if (totalUnits <= 0) return 0;
    return occupiedUnits / totalUnits;
  }

  static double monthlyContractAmount({
    required int billableDoors,
    required double feePerDoor,
  }) =>
      billableDoors * feePerDoor;

  static double revenuePerBillableDoor({
    required double totalRevenue,
    required int billableDoors,
  }) {
    if (billableDoors <= 0) return 0;
    return totalRevenue / billableDoors;
  }

  static double readFeePerDoor(Map<String, dynamic> property) {
    final v = property['monthly_fee_per_door'];
    if (v is num) return v.toDouble();
    return defaultMonthlyFeePerDoor;
  }

  static double readMinBillablePercent(Map<String, dynamic> property) {
    final v = property['minimum_billable_occupancy_percent'];
    if (v is num) return v.toDouble();
    return defaultMinimumBillablePercent;
  }

  /// Prefer [billing_total_doors] on property; else [countedUnits] from units table.
  static int totalDoors(
    Map<String, dynamic> property, {
    required int countedUnits,
  }) {
    final v = property['billing_total_doors'];
    if (v is int && v > 0) return v;
    if (v is num && v.toInt() > 0) return v.toInt();
    return countedUnits;
  }

  /// Prefer [billing_occupied_doors] when set; else [countedOccupied] from resident_units.
  static int occupiedDoors(
    Map<String, dynamic> property, {
    required int countedOccupied,
  }) {
    if (property['billing_occupied_doors'] != null) {
      final v = property['billing_occupied_doors'];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return countedOccupied;
  }

  static int minimumBillableDoors(int totalUnits, double minPercent) {
    if (totalUnits <= 0) return 0;
    return (totalUnits * minPercent).ceil();
  }

  /// Summary for dashboards and admin UI.
  static Map<String, dynamic> snapshot({
    required Map<String, dynamic> property,
    required int countedUnits,
    required int countedOccupied,
  }) {
    final total = totalDoors(property, countedUnits: countedUnits);
    final occupied = occupiedDoors(property, countedOccupied: countedOccupied);
    final minPct = readMinBillablePercent(property);
    final minDoors = minimumBillableDoors(total, minPct);
    final billable = billableDoors(
      totalUnits: total,
      occupiedUnits: occupied,
      minPercent: minPct,
    );
    final fee = readFeePerDoor(property);
    final monthly = monthlyContractAmount(billableDoors: billable, feePerDoor: fee);
    return {
      'total_doors': total,
      'occupied_doors': occupied,
      'occupancy_percent': occupancyPercent(total, occupied),
      'min_billable_percent': minPct,
      'minimum_billable_doors': minDoors,
      'billable_doors': billable,
      'fee_per_door': fee,
      'monthly_amount': monthly,
    };
  }
}
