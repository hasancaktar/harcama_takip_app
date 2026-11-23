import '../entities/vehicle.dart';

abstract class IVehicleRepository {
  /// Kullanıcının araçları (ada göre sıralı).
  Stream<List<Vehicle>> watchVehicles(String uid);
  Future<void> saveVehicle(Vehicle vehicle);

  /// Araç silinir; geçmiş yakıt kayıtları aracın adıyla kalır.
  Future<void> deleteVehicle(String vehicleId);
}
