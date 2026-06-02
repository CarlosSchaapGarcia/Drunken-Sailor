import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/bar.dart';

// Firestore-specific conversion. Domain Bar has no Firebase imports.
class BarDto {
  static Bar fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Bar.fromJson({...data, 'id': doc.id});
  }

  static Map<String, dynamic> toFirestore(Bar bar) => bar.toJson()..remove('id');
}
