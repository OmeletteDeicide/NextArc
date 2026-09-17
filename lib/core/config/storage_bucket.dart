import 'package:firebase_storage/firebase_storage.dart';

/// Bucket Cloud Storage des photos et bannières, hébergé dans l'Union
/// européenne (multi-région EU). Le bucket par défaut du projet
/// (`nextarc-fdbde.firebasestorage.app`, US-EAST1) n'est plus utilisé.
const String storageBucket = 'gs://nextarc-fdbde';

/// Instance Storage à utiliser partout dans l'app.
FirebaseStorage get appStorage =>
    FirebaseStorage.instanceFor(bucket: storageBucket);
