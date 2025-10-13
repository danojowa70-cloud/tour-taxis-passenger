import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride.dart';
import '../models/payment.dart';

// Theme mode provider: true for dark, false for light (system default false)
class ThemeController extends StateNotifier<bool> {
  ThemeController(super.state);

  static const _key = 'theme_dark';

  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? false;
    return ThemeController(isDark);
  }

  Future<void> setDark(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final themeDarkProvider = StateNotifierProvider<ThemeController, bool>((ref) => ThemeController(false));

final ridesProvider = StateProvider<List<Ride>>((ref) => [
      Ride(
        id: 'r1',
        pickupLocation: 'Grand Place, Brussels',
        dropoffLocation: 'Brussels Airport',
        driverName: 'Alex Janssens',
        driverCar: 'Tesla Model 3 - 1ABC234',
        fare: 38.5,
        status: 'Completed',
        dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      ),
      Ride(
        id: 'r2',
        pickupLocation: 'Tour & Taxis',
        dropoffLocation: 'EU Parliament',
        driverName: 'Marie Dubois',
        driverCar: 'BMW i3 - 2XYZ567',
        fare: 18.0,
        status: 'Completed',
        dateTime: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      ),
    ]);

final paymentsProvider = StateProvider<List<PaymentRecord>>((ref) => [
      PaymentRecord(
        id: 'p1',
        method: 'Card',
        amount: 38.5,
        status: 'Paid',
        dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      ),
      PaymentRecord(
        id: 'p2',
        method: 'Wallet',
        amount: 18.0,
        status: 'Paid',
        dateTime: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      ),
    ]);


