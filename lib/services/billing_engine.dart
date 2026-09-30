class BillingEngine {
  static Map<String, dynamic> calculateBill(double units, String connectionType) {
    double amount = 0;
    double fixedCharges = 0;
    List<String> breakdown = [];

    // ---------------- DOMESTIC (LT Tariff IA) ----------------
    if (connectionType == "Domestic") {
      fixedCharges = 0; // Confirmed: No fixed charges for domestic in TN

      if (units <= 100) {
        amount = 0;
        breakdown.add("First 100 Units: Free (Subsidy)");
      }
      // If consumption is between 101 and 500 units
      else if (units <= 500) {
        amount = 0; // First 100 still free
        breakdown.add("0-100 Units: Free");

        if (units <= 200) {
          double u = units - 100;
          double slabAmount = u * 2.35;
          amount += slabAmount;
          breakdown.add("101-200 Units: $u x ₹2.35 = ₹${slabAmount.toStringAsFixed(2)}");
        } else {
          // First 200 units at lower rate, then remaining up to 500
          double slab1 = 100 * 2.35;
          double u2 = units - 200;
          double slab2 = u2 * 4.70;
          amount = slab1 + slab2;
          breakdown.add("101-200 Units: 100 x ₹2.35 = ₹235.00");
          breakdown.add("201-$units Units: $u2 x ₹4.70 = ₹${slab2.toStringAsFixed(2)}");
        }
      }
      // High Usage: If consumption crosses 500 units (TNEB Non-Telescopic logic)
      else {
        amount = 0;
        breakdown.add("0-100 Units: Free");

        // 101-400 Units
        double slab1 = 300 * 4.70;
        amount += slab1;
        breakdown.add("101-400 Units: 300 x ₹4.70 = ₹1410.00");

        // 401-500 Units
        double slab2 = 100 * 6.30;
        amount += slab2;
        breakdown.add("401-500 Units: 100 x ₹6.30 = ₹630.00");

        // 501+ Units
        double u3 = units - 500;
        double slab3 = u3 * 8.40;
        amount += slab3;
        breakdown.add("501-$units Units: $u3 x ₹8.40 = ₹${slab3.toStringAsFixed(2)}");
      }
    }

    // ---------------- COMMERCIAL (LT Tariff V) ----------------
    else if (connectionType == "Commercial") {
      // Rates approx ₹8.50 per unit + Fixed Charges per kW
      amount = units * 8.50;
      fixedCharges = 100; // Simplified flat fixed charge
      breakdown.add("Consumption: $units units x ₹8.50 = ₹${amount.toStringAsFixed(2)}");
      breakdown.add("Fixed Monthly Charges: ₹$fixedCharges");
    }

    // ---------------- INDUSTRIAL (LT Tariff III-B) ----------------
    else if (connectionType == "Industrial") {
      amount = units * 6.75;
      fixedCharges = 150;
      breakdown.add("Consumption: $units units x ₹6.75 = ₹${amount.toStringAsFixed(2)}");
      breakdown.add("Fixed Monthly Charges: ₹$fixedCharges");
    }

    double total = amount + fixedCharges;

    return {
      "total": total,
      "breakdown": breakdown,
    };
  }
}