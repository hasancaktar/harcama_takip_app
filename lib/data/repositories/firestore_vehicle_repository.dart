import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/i_vehicle_repository.dart';

class FirestoreVehicleRepository implements IVehicleRepository {
  final FirebaseFirestore _firestore;

  FirestoreVehicleRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('vehicles');

  static Vehicle _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return Vehicle.fromMap(data);
  }

  @override
  Stream<List<Vehicle>> watchVehicles(String uid) => _col
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs.map(_fromDoc).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      );

  @override
  Future<void> saveVehicle(Vehicle vehicle) =>
      _col.doc(vehicle.id).set(vehicle.toMap());

  @override
  Future<void> deleteVehicle(String vehicleId) => _col.doc(vehicleId).delete();
}
