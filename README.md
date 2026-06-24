# deltasend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Walkthrough

DeltaSend disusun sebagai aplikasi Flutter dengan pola `MVVM + Provider`: `views/` menangani UI per screen dan role, `viewmodels/` mengelola state serta alur proses UI, `services/` menangani integrasi Firebase, peta, lokasi, pricing, dan chat, sedangkan `models/` memetakan data aplikasi seperti user, order, dan message. Aplikasi memiliki tiga role utama, yaitu `Customer`, `Driver`, dan `Admin`, dengan routing role dipusatkan di flow autentikasi dan home masing-masing role.

- `users` - profil user, role, rating driver, dan `fcm_token`
- `orders` - data order, status pengiriman, tracking, proof of delivery, dan rating
- `pricing_config` - konfigurasi harga dasar seperti `cost_per_km`
- `weight_categories` - kategori berat dan biaya tambahan order
- `chats/{orderId}/messages` - ruang chat per order dan daftar pesan di dalamnya
- `driver_locations` - posisi driver untuk tracking dan monitoring admin

### Auth
**Alur:** Saat aplikasi dibuka, `SplashScreen` hanya menampilkan animasi lalu mengarahkan user ke `LoginScreen`. Dari sana user bisa login dengan email/password, login dengan Google, masuk ke flow sign up lewat `RoleSelectionScreen`, atau meminta reset password. Di balik layar, `AuthViewModel` menangani seluruh proses autentikasi: memanggil Firebase Auth, membaca/menulis dokumen `users/{uid}` di Firestore, menyimpan `currentUser`, lalu mendaftarkan `fcm_token` setelah login berhasil. Jika login Google berhasil tetapi dokumen user belum ada, app menyimpan user sementara dengan `role: ''`, lalu memaksa user memilih role agar dokumen `users/{uid}` bisa dibuat dengan role yang benar. Routing akhir ditentukan oleh `homeForRole()`, sehingga user diarahkan ke home `Customer`, `Driver`, atau `Admin` sesuai role yang tersimpan.
**Kode relevan:**
- `lib/views/auth/splash_screen.dart` - `_startSplashAnimation()`: splash saat ini hanya animasi dan redirect ke login, belum cek sesi auth.
```dart
Future<void> _startSplashAnimation() async {
  await _backgroundController.forward();
  await Future.delayed(const Duration(milliseconds: 300));
  await _logoController.forward();
  await Future.delayed(const Duration(seconds: 2));

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const LoginScreen()),
  );
}
```
- `lib/views/auth/login_screen.dart` - `_login()`: UI memvalidasi input, lalu menyerahkan login email/password ke `AuthViewModel`.
```dart
Future<void> _login() async {
  final AuthViewModel auth = context.read<AuthViewModel>();

  final bool success = await auth.signInWithEmailPassword(
    _emailCtrl.text.trim(),
    _passwordCtrl.text,
  );

  if (!mounted) return;

  if (success) {
    _goHome();
  } else {
    _showError();
  }
}
```
- `lib/views/auth/login_screen.dart` - `_loginGoogle()`: login Google memakai `AuthViewModel.signInWithGoogle()`, lalu redirect berdasarkan role hasil auth.
```dart
Future<void> _loginGoogle() async {
  final AuthViewModel auth = context.read<AuthViewModel>();
  final bool success = await auth.signInWithGoogle();

  if (!mounted) return;

  if (success) {
    _goHome();
  } else if (auth.errorMessage != null) {
    _showError();
  }
}
```
- `lib/viewmodels/auth_viewmodel.dart` - `signInWithEmailPassword()`: login ke Firebase Auth, load profil dari `users/{uid}`, lalu register token FCM.
```dart
Future<bool> signInWithEmailPassword(String email, String password) async {
  final cred = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  final user = await _loadUserDoc(cred.user!.uid);
  if (user == null) {
    _errorMessage = 'Data profil tidak ditemukan.';
    return false;
  }
  _currentUser = user;
  _registerFcmToken(user.uid);
  return true;
}
```
- `lib/views/auth/role_selection_screen.dart` - `_onRolePicked()`: untuk calon akun baru, role yang dipilih diteruskan ke `RegisterScreen(role)`.
```dart
if (!widget.isExistingAuthUser) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => RegisterScreen(role: role)));
  return;
}
```
- `lib/views/auth/register_screen.dart` - `_register()`: membuat akun email/password setelah role sudah dipilih.
```dart
final bool success = await auth.registerWithEmailPassword(
  _emailCtrl.text.trim(),
  _passwordCtrl.text,
  _nameCtrl.text.trim(),
  widget.role,
);
```
- `lib/viewmodels/auth_viewmodel.dart` - `registerWithEmailPassword()`: membuat akun Firebase Auth, lalu menulis dokumen `users/{uid}` dengan `name`, `email`, `role`, dan `created_at`.
```dart
await _db.collection('users').doc(uid).set({
  'uid': uid,
  'email': email,
  'name': name,
  'role': role,
  'created_at': FieldValue.serverTimestamp(),
});
_currentUser = UserModel(uid: uid, email: email, name: name, role: role);
_registerFcmToken(uid);
```
- `lib/viewmodels/auth_viewmodel.dart` - `signInWithGoogle()`: autentikasi Google, lalu cek apakah dokumen `users/{uid}` sudah ada atau masih perlu role selection.
```dart
if (!_googleInitialized) {
  await _googleSignIn.initialize(serverClientId: kGoogleServerClientId);
  _googleInitialized = true;
}

final googleUser = await _googleSignIn.authenticate();
final cred = await _auth.signInWithCredential(credential);

final existing = await _loadUserDoc(fbUser.uid);
if (existing != null) {
  _currentUser = existing;
  _registerFcmToken(existing.uid);
} else {
  _currentUser = UserModel(
    uid: fbUser.uid,
    email: fbUser.email ?? '',
    name: fbUser.displayName ?? '',
    role: '',
  );
}
```
- `lib/views/auth/role_selection_screen.dart` - `_onRolePicked()`: untuk user Google baru yang sudah authenticated, pilihan role langsung disimpan ke UID yang sama.
```dart
final auth = context.read<AuthViewModel>();
final bool ok = await auth.selectRole(role);
```
- `lib/viewmodels/auth_viewmodel.dart` - `selectRole()`: melengkapi dokumen `users/{uid}` dengan role final hasil pilihan user.
```dart
await _db.collection('users').doc(uid).set({
  'uid': uid,
  'email': _currentUser!.email,
  'name': _currentUser!.name,
  'role': role,
  'created_at': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
_currentUser = _currentUser!.copyWith(role: role);
_registerFcmToken(uid);
```
- `lib/views/auth/forgot_password_screen.dart` - `_sendResetEmail()`: UI forgot password hanya meneruskan email ke ViewModel setelah validasi form.
```dart
final success = await auth.sendPasswordResetEmail(_emailCtrl.text.trim());
```
- `lib/viewmodels/auth_viewmodel.dart` - `sendPasswordResetEmail()`: mengirim email reset lewat Firebase Auth dengan timeout dan mapping error yang eksplisit.
```dart
await _auth
    .sendPasswordResetEmail(email: email.trim())
    .timeout(const Duration(seconds: 15));
```
- `lib/views/auth/role_home.dart` - `homeForRole()`: satu pintu routing semua hasil login dan register.
```dart
Widget homeForRole(String role) {
  switch (role) {
    case 'driver':
      return const DriverHomeScreen();
    case 'admin':
      return const AdminHomeScreen();
    case 'customer':
      return const CustomerHomeScreen();
    default:
      return const RoleSelectionScreen(isExistingAuthUser: true);
  }
}
```
**Known Limitation:**
- `SplashScreen` di kode saat ini belum memanggil `loadCurrentUser()`, jadi sesi login persisten belum dihubungkan ke splash flow walau method-nya sudah ada di `AuthViewModel`.
- Role `admin` belum bisa dibuat dari UI register; admin masih harus diset manual di Firestore.
- Belum ada email verification.
- User Google baru yang masuk ke `RoleSelectionScreen(isExistingAuthUser: true)` belum punya opsi batal/keluar tanpa memilih role.

### Customer - Create Order
**Alur:** Customer membuka `CustomerCreateOrderScreen` dari home customer. Saat screen dibuka, app lebih dulu memuat konfigurasi harga dari Firestore: `pricing_config/default` untuk `cost_per_km` dan koleksi `weight_categories` untuk dropdown kategori berat. User lalu mengisi detail barang dan memilih kategori berat, kemudian masuk ke langkah pemilihan lokasi. Di `CustomerMapPickerScreen`, user bisa mencari alamat dengan teks, memakai lokasi saat ini, atau langsung tap peta untuk menentukan pickup dan tujuan. Setelah dua titik valid, app menghitung jarak otomatis via OSRM dan menghitung total biaya dari rumus `distance_km * cost_per_km + additional_cost`. Saat user menekan tombol submit, `OrderService.createOrder()` membuat dokumen baru di `orders` dengan `status: pending`, `driver_id: null`, dan seluruh data order yang sudah dihitung. Setelah sukses, app tidak kembali ke form, tetapi langsung pindah ke `CustomerWaitingScreen` untuk menunggu driver menerima order.
**Kode relevan:**
- `lib/views/customer/customer_home_screen.dart` - `_openCreateOrder()`: entry point fitur dari home customer.
```dart
void _openCreateOrder() {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CustomerCreateOrderScreen()),
  );
}
```
- `lib/views/customer/customer_create_order_screen.dart` - `_loadPricingConfig()`: screen memuat `cost_per_km` dan `weight_categories` saat pertama kali dibuka.
```dart
Future<void> _loadPricingConfig() async {
  final results = await Future.wait([
    _pricingService.getCostPerKm(),
    _pricingService.getWeightCategories(),
  ]);

  if (!mounted) return;

  setState(() {
    _costPerKm = results[0] as double;
    _categories = results[1] as List<WeightCategory>;
  });
}
```
- `lib/services/pricing_service.dart` - `getCostPerKm()`: mengambil tarif per kilometer dari `pricing_config/default`.
```dart
Future<double> getCostPerKm() async {
  final doc = await _db.collection('pricing_config').doc('default').get();

  if (!doc.exists) {
    throw Exception('Dokumen pricing_config/default tidak ditemukan');
  }

  final data = doc.data() ?? {};
  final costPerKm = (data['cost_per_km'] as num?)?.toDouble();

  if (costPerKm == null) {
    throw Exception('Field cost_per_km tidak ada di pricing_config/default');
  }

  return costPerKm;
}
```
- `lib/services/pricing_service.dart` - `getWeightCategories()`: mengambil daftar kategori berat dari Firestore untuk dropdown form.
```dart
Future<List<WeightCategory>> getWeightCategories() async {
  final snapshot = await _db.collection('weight_categories').get();

  if (snapshot.docs.isEmpty) {
    throw Exception('Koleksi weight_categories kosong / tidak ada data');
  }

  return snapshot.docs.map((doc) => WeightCategory.fromDoc(doc)).toList();
}
```
- `lib/views/customer/customer_create_order_screen.dart` - `_continueToLocation()`: form detail barang harus valid sebelum user masuk ke map picker.
```dart
void _continueToLocation() {
  final bool valid = _formKey.currentState?.validate() ?? false;

  if (!valid) return;

  setState(() {
    _currentStep = 2;
  });

  _openMapPicker();
}
```
- `lib/views/customer/customer_create_order_screen.dart` - `_openMapPicker()`: membuka map picker, lalu menyimpan hasil pickup/tujuan kembali ke form.
```dart
Future<void> _openMapPicker() async {
  final Map<String, dynamic>? result = await Navigator.of(context)
      .push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => CustomerMapPickerScreen(
            initialPickup: _pickupLat == null || _pickupLng == null
                ? null
                : LatLng(_pickupLat!, _pickupLng!),
            initialDestination:
                _destinationLat == null || _destinationLng == null
                ? null
                : LatLng(_destinationLat!, _destinationLng!),
          ),
        ),
      );

  if (result == null || !mounted) return;

  setState(() {
    _pickupAddress = pickupAddress;
    _pickupLat = pickupLat;
    _pickupLng = pickupLng;
    _destinationAddress = destinationAddress;
    _destinationLat = destinationLat;
    _destinationLng = destinationLng;
    _currentStep = 2;
  });

  await _refreshDistanceAndCost();
}
```
- `lib/views/customer/customer_map_picker_screen.dart` - `_onSearchChanged()`: user bisa mencari alamat teks, lalu hasilnya di-resolve lewat Nominatim.
```dart
_debounceTimer = Timer(const Duration(milliseconds: 450), () async {
  setState(() {
    _isSearching = true;
    _searchError = null;
  });

  try {
    final results = await GeocodingService.searchAddress(query);

    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
      _searchError = results.isEmpty ? 'Alamat tidak ditemukan' : null;
    });
  } catch (error) {
    if (!mounted) return;

    setState(() {
      _searchResults = [];
      _isSearching = false;
      _searchError = 'Gagal mencari alamat';
    });
  }
});
```
- `lib/views/customer/customer_map_picker_screen.dart` - `_onMapTap()`: tap di peta menyimpan koordinat, lalu mencoba reverse geocode untuk mendapatkan label alamat.
```dart
Future<void> _onMapTap(LatLng point) async {
  setState(() {
    _selectedPoint = point;
    _searchResults = [];
    _searchController.clear();
    _searchError = null;
    _isLoadingAddress = true;
  });

  final String? address = await GeocodingService.reverseGeocode(
    point.latitude,
    point.longitude,
  );

  final String resolvedAddress = address?.trim().isNotEmpty == true
      ? address!.trim()
      : 'Lokasi dipilih';

  _syncSelection(
    address: resolvedAddress,
    latitude: point.latitude,
    longitude: point.longitude,
  );
}
```
- `lib/views/customer/customer_map_picker_screen.dart` - `_useCurrentLocation()`: user bisa memakai GPS perangkat sebagai pickup atau tujuan.
```dart
final Position position = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(
    timeLimit: Duration(seconds: 10),
  ),
);

final LatLng point = LatLng(position.latitude, position.longitude);

setState(() {
  if (_selectedType == _LocationType.pickup) {
    _pickupAddress = 'Lokasi saat ini';
    _pickupLat = point.latitude;
    _pickupLng = point.longitude;
  } else {
    _destinationAddress = 'Lokasi saat ini';
    _destinationLat = point.latitude;
    _destinationLng = point.longitude;
  }
});
```
- `lib/services/geocoding_service.dart` - `searchAddress()`: pencarian alamat teks memakai Nominatim.
```dart
final url = Uri.parse(
  'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=id',
);
```
- `lib/services/geocoding_service.dart` - `reverseGeocode()`: koordinat hasil tap peta diterjemahkan menjadi label alamat yang lebih ramah untuk user.
```dart
final url = Uri.parse(
  'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=id'
);
```
- `lib/views/customer/customer_map_picker_screen.dart` - `_confirm()`: pickup dan tujuan dikembalikan ke form sebagai payload hasil map picker.
```dart
void _confirm() {
  if (!_canConfirm) {
    _showSnack('Lengkapi lokasi pickup dan tujuan terlebih dahulu.');
    return;
  }

  Navigator.of(context).pop({
    'pickup_address': _pickupAddress,
    'pickup_lat': _pickupLat,
    'pickup_lng': _pickupLng,
    'dest_address': _destinationAddress,
    'dest_lat': _destinationLat,
    'dest_lng': _destinationLng,
  });
}
```
- `lib/views/customer/customer_create_order_screen.dart` - `_refreshDistanceAndCost()`: jarak dihitung dari OSRM setelah pickup dan tujuan lengkap.
```dart
Future<void> _refreshDistanceAndCost() async {
  final routeInfo = await _routingService.getRouteInfo(
    LatLng(_pickupLat!, _pickupLng!),
    LatLng(_destinationLat!, _destinationLng!),
  );

  if (!mounted) return;

  setState(() {
    _distanceKm = routeInfo.distanceMeters / 1000;
    _recalculateCost();
  });
}
```
- `lib/views/customer/customer_create_order_screen.dart` - `_recalculateCost()`: total biaya dihitung dari jarak dan biaya tambahan kategori berat.
```dart
void _recalculateCost() {
  if (_distanceKm != null &&
      _selectedCategory != null &&
      _costPerKm != null) {
    final double baseCost = _distanceKm! * _costPerKm!;
    _totalCost = baseCost + _selectedCategory!.additionalCost;
  } else {
    _totalCost = null;
  }
}
```
- `lib/services/routing_service.dart` - `getRouteInfo()`: sumber jarak tempuh berasal dari OSRM, bukan hitung manual garis lurus.
```dart
final Uri uri =
    Uri.parse(
      '$_baseUrl/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}',
    ).replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'alternatives': 'false',
      },
    );
```
- `lib/views/customer/customer_create_order_screen.dart` - `_submit()`: validasi final, ambil `customerId` dari user login, lalu buat order dan pindah ke waiting screen.
```dart
final String customerId =
    context.read<AuthViewModel>().currentUser?.uid ?? '';

if (customerId.isEmpty) {
  throw Exception('Customer tidak ditemukan.');
}

final String newOrderId = await _orderService.createOrder(
  customerId: customerId,
  pickupAddress: _pickupAddress!.trim(),
  pickupLat: _pickupLat!,
  pickupLng: _pickupLng!,
  destAddress: _destinationAddress!.trim(),
  destLat: _destinationLat!,
  destLng: _destinationLng!,
  itemDescription: _itemDescriptionCtrl.text.trim(),
  weightCategoryId: _selectedCategory!.id,
  weightCategoryName: _selectedCategory!.name,
  distanceKm: _distanceKm!,
  totalCost: _totalCost!,
);

Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (_) => CustomerWaitingScreen(orderId: newOrderId),
  ),
);
```
- `lib/services/order_service.dart` - `createOrder()`: order baru ditulis ke Firestore dengan status awal `pending`.
```dart
final docRef = await _db.collection('orders').add({
  'customer_id': customerId,
  'driver_id': null,
  'weight_category_id': weightCategoryId,
  'weight_category_name': weightCategoryName,
  'pickup_address': pickupAddress,
  'pickup_lat': pickupLat,
  'pickup_lng': pickupLng,
  'dest_address': destAddress,
  'dest_lat': destLat,
  'dest_lng': destLng,
  'item_description': itemDescription,
  'distance_km': distanceKm,
  'total_cost': totalCost,
  'status': OrderStatus.pending.name,
  'proof_photo_url': '',
  'created_at': FieldValue.serverTimestamp(),
  'updated_at': FieldValue.serverTimestamp(),
});

return docRef.id;
```
**Known Limitation:**
- Fitur ini bergantung pada data Firestore `pricing_config/default` dan `weight_categories`; jika data belum ada atau field salah, form tidak bisa dipakai.
- Perhitungan jarak bergantung pada OSRM, sedangkan search/reverse geocoding bergantung pada Nominatim; kalau koneksi bermasalah, alamat atau jarak bisa gagal dihitung.
- Jika reverse geocoding gagal, lokasi tetap tersimpan tetapi label alamat bisa fallback menjadi teks generik seperti `Lokasi dipilih` atau `Lokasi saat ini`.
- Submit order mensyaratkan user login; jika `currentUser` kosong, proses dihentikan dengan error `Customer tidak ditemukan`.

### Customer - Tracking & Chat
**Alur:** Setelah customer membuat order, app langsung masuk ke `CustomerWaitingScreen` untuk memantau apakah order sudah diambil driver. Di balik layar, `CustomerOrderViewModel` memasang listener realtime ke dokumen `orders/{orderId}`, menjalankan countdown cancel manual 10 detik, dan timeout sistem 60 detik. Begitu `driver_id` berubah dari kosong menjadi terisi, state berubah ke `driverAssigned` dan screen berpindah ke `CustomerTrackingScreen`. Di screen tracking, customer hanya membaca dokumen order secara realtime: posisi driver, status order, target pickup/tujuan, dan rute di peta. Rute dihitung ulang hanya jika driver bergerak lebih dari 50 meter agar tidak spam request OSRM. Dari screen ini customer juga bisa membuka chat per order. Chat memakai `orderId` sebagai room ID, membuat dokumen `chats/{orderId}` secara lazy saat pertama dibuka, lalu men-stream subcollection `messages` secara realtime. Pesan yang masuk ditandai terbaca saat screen chat dibuka, dan customer hanya bisa chat jika order sudah punya `driver_id`.
**Kode relevan:**
- `lib/views/customer/customer_create_order_screen.dart` - `_submit()`: setelah order dibuat, flow customer langsung diarahkan ke waiting screen.
```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (_) => CustomerWaitingScreen(orderId: newOrderId),
  ),
);
```
- `lib/viewmodels/customer_order_viewmodel.dart` - constructor: waiting flow dimulai dengan timer cancel, timer timeout, dan listener realtime ke order.
```dart
CustomerOrderViewModel({required this.orderId}) {
  _startButtonTimer();
  _startSystemTimeoutTimer();
  _listenToOrderDocument();
}
```
- `lib/viewmodels/customer_order_viewmodel.dart` - `_listenToOrderDocument()`: ViewModel memantau perubahan order secara realtime.
```dart
_orderSubscription = _firestore
    .collection('orders')
    .doc(orderId)
    .snapshots()
    .listen(_handleOrderSnapshot);
```
- `lib/viewmodels/customer_order_viewmodel.dart` - `_handleOrderSnapshot()`: perpindahan dari waiting ke tracking terjadi saat `driver_id` baru terisi.
```dart
final previousDriverId = _lastKnownDriverId;
final driverId = order.driverId?.trim();

final didDriverJustAccept =
    (previousDriverId == null || previousDriverId.isEmpty) &&
    driverId != null &&
    driverId.isNotEmpty;

if (didDriverJustAccept) {
  _state = CustomerOrderFlowState.driverAssigned;
  _message = 'Driver sudah menerima order.';
  _stopTimers();
  notifyListeners();
  return;
}
```
- `lib/viewmodels/customer_order_viewmodel.dart` - `_startButtonTimer()`: customer hanya bisa cancel manual dalam 10 detik pertama.
```dart
_manualCancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (_buttonCountdown <= 1) {
    _buttonCountdown = 0;
    _canCancel = false;
    timer.cancel();
  } else {
    _buttonCountdown -= 1;
  }

  notifyListeners();
});
```
- `lib/viewmodels/customer_order_viewmodel.dart` - `_startSystemTimeoutTimer()`: kalau tidak ada driver yang menerima dalam 60 detik, order otomatis di-cancel.
```dart
if (_systemCountdown <= 1) {
  _systemCountdown = 0;
  timer.cancel();

  _state = CustomerOrderFlowState.timeout;
  _message = 'Tidak ada driver yang menerima order.';
  _stopTimers();

  try {
    await _orderService.updateOrderStatus(
      orderId: orderId,
      status: OrderStatus.cancelled.name,
    );
  } finally {
    notifyListeners();
  }
  return;
}
```
- `lib/views/customer/customer_waiting_screen.dart` - `_handleViewModelUpdate()`: screen bereaksi ke state ViewModel, baik untuk pindah ke tracking maupun kembali ke home saat timeout/cancel.
```dart
if (state == CustomerOrderFlowState.driverAssigned) {
  _handledNavigation = true;

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => CustomerTrackingScreen(orderId: widget.orderId),
    ),
  );

  return;
}
```
```dart
if (state == CustomerOrderFlowState.timeout ||
    state == CustomerOrderFlowState.cancelled) {
  _handledNavigation = true;

  Navigator.of(context).popUntil((route) => route.isFirst);
}
```
- `lib/views/customer/customer_waiting_screen.dart` - `_cancelOrder()`: customer masih bisa cancel manual selama tombol cancel aktif.
```dart
if (confirmed != true) return;

await _viewModel.cancelOrder();
```
- `lib/services/order_service.dart` - `watchOrder()`: tracking customer memakai stream satu dokumen order, bukan GPS customer.
```dart
Stream<OrderModel?> watchOrder(String orderId) {
  return _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
}
```
- `lib/views/customer/customer_tracking_screen.dart` - `StreamBuilder` utama: UI tracking customer hanya membaca perubahan order realtime.
```dart
body: StreamBuilder<OrderModel?>(
  stream: _orderService.watchOrder(widget.orderId),
  builder: (context, snapshot) {
    final OrderModel? order = snapshot.data;
```
- `lib/views/customer/customer_tracking_screen.dart` - `_targetPosition()`: target rute berubah sesuai status order.
```dart
LatLng _targetPosition(OrderModel order) {
  if (order.status == OrderStatus.accepted ||
      order.status == OrderStatus.pickingUp) {
    return order.pickupLocation;
  }

  return order.destinationLocation;
}
```
- `lib/views/customer/customer_tracking_screen.dart` - `_maybeUpdateRoute()`: rute di-refresh hanya jika driver berpindah lebih dari 50 meter.
```dart
if (_lastRouteCalculationPosition != null && _routePoints.isNotEmpty) {
  final double movedDistance = _distance.as(
    LengthUnit.Meter,
    _lastRouteCalculationPosition!,
    driverPosition,
  );

  if (movedDistance <= 50) return;
}

_lastRouteCalculationPosition = driverPosition;
_calculateRoute(driverPosition, targetPosition);
```
- `lib/views/customer/customer_tracking_screen.dart` - `_calculateRoute()`: polyline customer dihitung dari posisi driver ke target aktif via `RoutingService`.
```dart
final List<LatLng> points = await _routingService.getRoute(
  start,
  destination,
);

if (!mounted) return;

setState(() {
  _routePoints = points;
});
```
- `lib/views/customer/customer_tracking_screen.dart` - `_openChat()`: chat hanya dibuka jika order sudah punya `driver_id`.
```dart
void _openChat(OrderModel order) {
  final String? driverId = order.driverId;

  if (driverId == null || driverId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat belum tersedia, menunggu driver.'),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        orderId: order.orderId,
        currentUserId: order.customerId,
        customerId: order.customerId,
        driverId: driverId,
      ),
    ),
  );
}
```
- `lib/views/chat/chat_screen.dart` - `_initializeChat()`: saat chat dibuka, room chat dipastikan ada lalu pesan lawan ditandai terbaca.
```dart
Future<void> _initializeChat() async {
  await _chatService.ensureChatExists(
    orderId: widget.orderId,
    customerId: widget.customerId,
    driverId: widget.driverId,
  );

  await _chatService.markMessagesAsRead(
    orderId: widget.orderId,
    currentUserId: widget.currentUserId,
  );
}
```
- `lib/services/chat_service.dart` - `ensureChatExists()`: dokumen `chats/{orderId}` dibuat lazy, hanya saat pertama kali chat dibuka.
```dart
final docRef = _db.collection('chats').doc(orderId);
final doc = await docRef.get();
if (doc.exists) return;

await docRef.set({
  'order_id': orderId,
  'customer_id': customerId,
  'driver_id': driverId,
  'created_at': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```
- `lib/views/chat/chat_screen.dart` - `_sendMessage()`: pesan dikirim lewat `ChatService`, lalu chat auto-scroll ke bawah.
```dart
await _chatService.sendMessage(
  orderId: widget.orderId,
  senderId: widget.currentUserId,
  content: message,
);

_scrollToBottom();
```
- `lib/services/chat_service.dart` - `sendMessage()`: pesan baru masuk ke subcollection `chats/{orderId}/messages`.
```dart
await _db.collection('chats').doc(orderId).collection('messages').add({
  'sender_id': senderId,
  'content': text,
  'sent_at': FieldValue.serverTimestamp(),
  'is_read': false,
});
```
- `lib/services/chat_service.dart` - `watchMessages()`: pesan di-stream realtime per order.
```dart
Stream<List<MessageModel>> watchMessages(String orderId) {
  return _db
      .collection('chats')
      .doc(orderId)
      .collection('messages')
      .orderBy('sent_at', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList());
}
```
- `lib/services/chat_service.dart` - `markMessagesAsRead()`: status baca diperbarui batch untuk pesan lawan yang belum dibaca.
```dart
final snapshot = await _db
    .collection('chats')
    .doc(orderId)
    .collection('messages')
    .where('is_read', isEqualTo: false)
    .get();

final batch = _db.batch();
for (final doc in snapshot.docs) {
  final senderId = doc.data()['sender_id'] as String? ?? '';
  if (senderId != currentUserId) {
    batch.update(doc.reference, {'is_read': true});
  }
}
await batch.commit();
```
**Known Limitation:**
- `CustomerTrackingScreen` bersifat read-only; kalau driver berhenti update lokasi, customer hanya melihat posisi terakhir dan belum ada indikator `driver offline`.
- Perhitungan polyline tracking tetap bergantung pada OSRM publik; kalau OSRM lambat/down, rute bisa tidak ter-update walau posisi driver masih berubah.
- Chat belum punya unread badge di tombol chat.
- `markMessagesAsRead()` hanya dipanggil saat screen chat dibuka, jadi pesan baru yang masuk saat screen masih terbuka tidak langsung ditandai terbaca otomatis.
- Chat hanya tersedia setelah `driver_id` terisi; order `pending` belum punya lawan chat.
- Belum ada attachment gambar, edit/hapus pesan, typing indicator, atau notifikasi FCM untuk pesan baru.

### Customer - Rating & Riwayat Order
**Alur:** Di sisi customer ada dua jalur yang saling terhubung. Pertama, riwayat order: `CustomerOrderHistoryScreen` menampilkan semua order milik customer secara realtime, lalu memberi filter `all/active/completed/cancelled`, pencarian teks, dan akses ke `CustomerOrderDetailScreen`. Dari detail ini customer bisa membuka tracking untuk order aktif, melihat proof of delivery jika order sudah selesai, dan melihat atau memberi rating. Kedua, rating: `CustomerHomeScreen` juga punya section khusus untuk order completed yang belum dirating. Saat customer membuka `RatingScreen`, app menampilkan ringkasan order, bukti pengantaran, profil driver, rating rata-rata driver, lalu customer memilih bintang 1 sampai 5 dan bisa menambahkan catatan teks. Saat submit, app menyimpan `rating` dan `rating_note` ke dokumen `orders/{orderId}`, lalu menghitung ulang `rating_avg` dan `rating_count` di dokumen `users/{driverId}`. Setelah sukses, user kembali ke home dan order itu hilang dari daftar “perlu dirating” karena stream realtime berubah.
**Kode relevan:**
- `lib/views/customer/customer_home_screen.dart` - `initState`: home customer menyiapkan dua stream terpisah, satu untuk semua order dan satu lagi khusus order completed yang belum dirating.
```dart
final String customerId =
    context.read<AuthViewModel>().currentUser?.uid ?? '';

_customerOrdersStream = _orderService.watchCustomerOrders(customerId);
_unratedStream = _orderService.watchCompletedUnratedOrders(customerId);
```
- `lib/services/order_service.dart` - `watchCompletedUnratedOrders()`: section rating di home hanya menampilkan order milik customer yang `completed` dan `rating == null`.
```dart
Stream<List<OrderModel>> watchCompletedUnratedOrders(String customerId) {
  return _db
      .collection('orders')
      .where('customer_id', isEqualTo: customerId)
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .where(
              (order) =>
                  order.status == OrderStatus.completed &&
                  order.rating == null,
            )
            .toList();

        orders.sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime(0);
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime(0);
          return bDate.compareTo(aDate);
        });

        return orders;
      });
}
```
- `lib/views/customer/customer_home_screen.dart` - `StreamBuilder` unrated: daftar “perlu dirating” hilang otomatis jika tidak ada order yang cocok.
```dart
StreamBuilder<List<OrderModel>>(
  stream: _unratedStream,
  builder: (context, unratedSnapshot) {
    final List<OrderModel> unratedOrders = unratedSnapshot.data ?? [];

    if (unratedOrders.isEmpty) {
      return const SizedBox.shrink();
    }
```
- `lib/views/customer/customer_home_screen.dart` - `_openRating()` dan `_openOrderDetail()`: customer bisa masuk ke rating screen atau detail order dari home.
```dart
void _openOrderDetail(OrderModel order) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CustomerOrderDetailScreen(orderId: order.orderId),
    ),
  );
}

void _openRating(OrderModel order) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => RatingScreen(order: order)));
}
```
- `lib/views/customer/customer_order_history_screen.dart` - `initState`: riwayat order diambil realtime dari Firestore.
```dart
final String customerId =
    context.read<AuthViewModel>().currentUser?.uid ?? '';

_orderStream = _orderService.watchCustomerOrders(customerId);
```
- `lib/views/customer/customer_order_history_screen.dart` - `_filterOrders()`: filter status dan search dilakukan di sisi client setelah stream order masuk.
```dart
switch (_selectedFilter) {
  case _OrderFilter.active:
    filteredOrders = filteredOrders.where(
      (order) =>
          order.status == OrderStatus.pending ||
          order.status == OrderStatus.accepted ||
          order.status == OrderStatus.pickingUp ||
          order.status == OrderStatus.delivering,
    );
    break;

  case _OrderFilter.completed:
    filteredOrders = filteredOrders.where(
      (order) => order.status == OrderStatus.completed,
    );
    break;

  case _OrderFilter.cancelled:
    filteredOrders = filteredOrders.where(
      (order) => order.status == OrderStatus.cancelled,
    );
    break;

  case _OrderFilter.all:
    break;
}
```
- `lib/services/order_service.dart` - `watchCustomerOrders()`: source utama data riwayat order customer.
```dart
Stream<List<OrderModel>> watchCustomerOrders(String customerId) {
  return _db
      .collection('orders')
      .where('customer_id', isEqualTo: customerId)
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs.map(OrderModel.fromFirestore).toList();

        orders.sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime(0);
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime(0);

          return bDate.compareTo(aDate);
        });

        return orders;
      });
}
```
- `lib/views/customer/customer_order_history_screen.dart` - `_openOrderDetail()`: setiap item riwayat diarahkan ke detail order.
```dart
void _openOrderDetail(OrderModel order) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CustomerOrderDetailScreen(orderId: order.orderId),
    ),
  );
}
```
- `lib/views/customer/customer_order_detail_screen.dart` - `StreamBuilder` detail: halaman detail order membaca satu order realtime dan menyesuaikan aksi berdasarkan status.
```dart
body: StreamBuilder<OrderModel?>(
  stream: _orderService.watchOrder(widget.orderId),
  builder: (context, snapshot) {
    final OrderModel? order = snapshot.data;

    if (order == null) {
      return _buildErrorState('Order tidak ditemukan.');
    }
```
- `lib/views/customer/customer_order_detail_screen.dart` - `_buildActionButton()`: dari detail, order aktif membuka tracking; order completed yang belum dirating membuka rating.
```dart
if (_isActiveOrder(order.status)) {
  return SizedBox(
    width: double.infinity,
    height: 51,
    child: ElevatedButton.icon(
      onPressed: () => _openTracking(order),
```
```dart
if (order.status == OrderStatus.completed && order.rating == null) {
  return SizedBox(
    width: double.infinity,
    height: 51,
    child: ElevatedButton.icon(
      onPressed: () => _openRating(order),
```
- `lib/views/customer/customer_order_detail_screen.dart` - order completed yang sudah dirating menampilkan hasil rating customer sendiri.
```dart
if (order.status == OrderStatus.completed && order.rating != null) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Text('Your Rating: ${order.rating}/5'),
```
- `lib/views/customer/customer_order_detail_screen.dart` - `_hasProofPhoto()`: proof of delivery ikut muncul di detail order jika order completed dan foto bukti tersedia.
```dart
bool _hasProofPhoto(OrderModel order) {
  return order.status == OrderStatus.completed &&
      order.proofPhotoUrl.trim().isNotEmpty;
}
```
- `lib/models/order_model.dart` - model order sudah memuat field yang dibutuhkan untuk rating dan histori detail.
```dart
final String proofPhotoUrl;
final int? rating;
final String ratingNote;
```
```dart
rating: data['rating'] as int?,
ratingNote: data['rating_note'] as String? ?? '',
proofPhotoUrl: data['proof_photo_url'] as String? ?? '',
```
- `lib/views/customer/rating_screen.dart` - `initState`: screen rating mendukung tampil ulang nilai rating dan catatan yang sudah ada.
```dart
@override
void initState() {
  super.initState();

  _rating = widget.order.rating ?? 0;
  _noteController.text = widget.order.ratingNote;
}
```
- `lib/views/customer/rating_screen.dart` - `_submit()`: submit rating memerlukan `driverId`, lalu menyimpan bintang dan catatan teks.
```dart
if (_rating == 0 || _isSubmitting) {
  return;
}

final String? driverId = widget.order.driverId;

if (driverId == null || driverId.trim().isEmpty) {
  _showSnack('Driver tidak ditemukan untuk order ini.');
  return;
}

await _orderService.submitRating(
  orderId: widget.order.orderId,
  driverId: driverId,
  rating: _rating,
  ratingNote: _noteController.text.trim(),
);
```
- `lib/services/order_service.dart` - `submitRating()`: rating disimpan ke order, lalu agregat driver dihitung ulang dari semua order completed yang sudah dirating.
```dart
await _db.collection('orders').doc(orderId).update({
  'rating': rating,
  'rating_note': ratingNote.trim(),
  'updated_at': FieldValue.serverTimestamp(),
});
```
```dart
final snapshot = await _db
    .collection('orders')
    .where('driver_id', isEqualTo: driverId)
    .get();

final ratings = snapshot.docs
    .map((doc) => OrderModel.fromFirestore(doc))
    .where(
      (order) =>
          order.status == OrderStatus.completed && order.rating != null,
    )
    .map((order) => order.rating!)
    .toList();

if (ratings.isEmpty) return;

final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

await _db.collection('users').doc(driverId).set({
  'rating_avg': averageRating,
  'rating_count': ratings.length,
}, SetOptions(merge: true));
```
- `lib/views/customer/rating_screen.dart` - proof photo di rating screen: customer bisa melihat bukti pengantaran sebelum memberi penilaian.
```dart
final String proofPhoto = order.proofPhotoUrl.trim();

child: proofPhoto.isEmpty
    ? ...
    : _buildProofImage(proofPhoto),
```
- `lib/views/customer/rating_screen.dart` dan `lib/views/customer/customer_order_detail_screen.dart` - rating rata-rata driver juga dibaca dari `users/{driverId}` untuk ditampilkan di UI.
```dart
final double rating =
    (data?['rating_avg'] as num?)?.toDouble() ?? 0;
final int ratingCount =
    (data?['rating_count'] as num?)?.toInt() ?? 0;
```
**Known Limitation:**
- Agregasi `rating_avg` dan `rating_count` masih dihitung ulang dengan membaca semua order driver saat submit rating, jadi kurang efisien jika volume order besar.
- Validasi kepemilikan rating masih bergantung pada alur aplikasi dan query customer; enforcement idealnya tetap di Firestore Security Rules.
- Riwayat order difilter dan dicari di sisi client setelah stream masuk, jadi belum ada server-side pagination atau query filter yang lebih efisien.
- `rating_note` sudah ada, tetapi belum ada moderasi, validasi panjang, atau pemisahan jelas antara rating baru vs edit rating lama.
- Proof photo hanya tampil jika field `proof_photo_url` tersedia; kalau driver tidak menyertakan foto atau formatnya rusak, customer hanya melihat fallback.

### Driver - Order List (Haversine)
**Alur:** Saat driver membuka daftar order, screen lebih dulu mencoba mengambil lokasi device dengan `Geolocator`. Jika GPS aktif dan izin lokasi tersedia, posisi driver disimpan di `_driverPosition`, lalu daftar `Order Tersedia` diurutkan berdasarkan jarak driver ke titik pickup memakai rumus Haversine manual, difilter ke radius maksimum 10 km, dan setiap card menampilkan badge jarak. Jika lokasi tidak bisa didapatkan karena GPS mati, izin ditolak, atau error lain, app tidak memblokir daftar order: semua order pending tetap ditampilkan, tetapi tanpa ranking/filter jarak, disertai banner status lokasi dan aksi retry/settings. Di bagian atas, driver juga melihat `Order Aktif Saya`, yaitu stream terpisah untuk order yang sudah diambil dan masih berstatus aktif. Driver tidak boleh mengambil order baru jika masih punya order aktif; tombol `Ambil Order` akan terkunci dan validasi yang sama juga ditegakkan di `OrderService.acceptOrder()` agar tidak hanya bergantung pada UI.
**Kode relevan:**
- `lib/views/driver_order_list_screen.dart` - `initState()`: saat screen dibuka, driver ID diambil dari `AuthViewModel` lalu lokasi driver langsung dicoba diinisialisasi.
```dart
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addObserver(this);

  _driverId = context.read<AuthViewModel>().currentUser?.uid ?? '';

  _initDriverLocation();
}
```
- `lib/views/driver_order_list_screen.dart` - `_initDriverLocation()`: lokasi driver diambil dari device, lengkap dengan handling GPS off, denied, denied forever, dan error umum.
```dart
final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

if (!serviceEnabled) {
  setState(() {
    _driverPosition = null;
    _locationState = _LocationState.serviceOff;
  });
  return;
}

LocationPermission permission = await Geolocator.checkPermission();

if (permission == LocationPermission.denied) {
  permission = await Geolocator.requestPermission();
}

if (permission == LocationPermission.deniedForever) {
  setState(() {
    _driverPosition = null;
    _locationState = _LocationState.deniedForever;
  });
  return;
}

final Position position = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(
    timeLimit: Duration(seconds: 10),
  ),
);

setState(() {
  _driverPosition = position;
  _locationState = _LocationState.ready;
});
```
- `lib/views/driver_order_list_screen.dart` - `didChangeAppLifecycleState()`: saat app kembali ke foreground, status lokasi dicek ulang otomatis.
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _initDriverLocation();
  }
}
```
- `lib/views/driver_order_list_screen.dart` - `build()`: screen selalu memuat `Order Aktif Saya` dulu, lalu `Order Tersedia`, dan keduanya dibungkus `RefreshIndicator`.
```dart
return StreamBuilder<List<OrderModel>>(
  stream: _orderService.watchActiveOrdersForDriver(_driverId),
  builder: (context, activeSnapshot) {
    final List<OrderModel> activeOrders = activeSnapshot.data ?? [];
    final bool hasActive = activeOrders.isNotEmpty;
```
```dart
return RefreshIndicator(
  onRefresh: _initDriverLocation,
  color: _primaryBlue,
  child: ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
    children: [content],
  ),
);
```
- `lib/services/order_service.dart` - `watchActiveOrdersForDriver()`: daftar order aktif driver dibaca dari Firestore lalu difilter di memory ke status aktif.
```dart
Stream<List<OrderModel>> watchActiveOrdersForDriver(String driverId) {
  return _db
      .collection('orders')
      .where('driver_id', isEqualTo: driverId)
      .snapshots()
      .map((snapshot) {
        const activeStatuses = {
          OrderStatus.pickingUp,
          OrderStatus.delivering,
        };

        final orders = snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .where((order) => activeStatuses.contains(order.status))
            .toList();

        orders.sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime(0);
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime(0);
          return bDate.compareTo(aDate);
        });

        return orders;
      });
}
```
- `lib/views/driver_order_list_screen.dart` - `_buildPendingOrdersSection()`: jika posisi driver tersedia, order pending diranking dengan Haversine; jika tidak, semua order tetap tampil dengan banner fallback.
```dart
if (_driverPosition != null) {
  final rankedOrders = _orderService.sortAndFilterByDistance(
    orders: orders,
    driverPosition: _driverPosition!,
  );

  if (rankedOrders.isEmpty) {
    return _buildEmptyState(
      icon: Icons.location_off_outlined,
      title: 'Tidak ada order terdekat',
      description:
          'Tidak ada order dalam radius '
          '${kMaxOrderRadiusKm.toStringAsFixed(0)} km.',
    );
  }

  return Column(
    children: rankedOrders.map(
      (item) => _buildOrderCard(
        order: item.order,
        driverDistanceKm: item.distanceKm,
```
```dart
return Column(
  children: [
    if (_locationState != _LocationState.loading)
      _buildLocationBanner(),

    ...orders.map(
      (order) => _buildOrderCard(
        order: order,
        showStatus: false,
        buttonText: buttonText,
        isProcessing: _processingOrderId == order.orderId,
        onPressed: isLocked ? null : () => _takeOrder(order),
      ),
    ),
  ],
);
```
- `lib/services/order_service.dart` - `watchPendingOrders()`: query Firestore untuk order tersedia tetap hanya mengambil status `pending`.
```dart
Stream<List<OrderModel>> watchPendingOrders() {
  return _db
      .collection('orders')
      .where('status', isEqualTo: OrderStatus.pending.name)
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs.map((doc) {
          return OrderModel.fromFirestore(doc);
        }).toList();

        orders.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(0);
          final bDate = b.createdAt ?? DateTime(0);
          return bDate.compareTo(aDate);
        });

        return orders;
      });
}
```
- `lib/services/order_service.dart` - `sortAndFilterByDistance()`: ranking jarak dilakukan client-side setelah snapshot pending order diterima.
```dart
List<OrderWithDistance> sortAndFilterByDistance({
  required List<OrderModel> orders,
  required Position driverPosition,
  double maxRadiusKm = kMaxOrderRadiusKm,
}) {
  final result =
      orders
          .map((order) {
            final distanceKm = calculateHaversineDistance(
              driverPosition.latitude,
              driverPosition.longitude,
              order.pickupLocation.latitude,
              order.pickupLocation.longitude,
            );
            return OrderWithDistance(order: order, distanceKm: distanceKm);
          })
          .where((item) => item.distanceKm <= maxRadiusKm)
          .toList();

  result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  return result;
}
```
- `lib/utils/distance_helper.dart` - `calculateHaversineDistance()`: jarak dihitung dengan formula Haversine manual, bukan `Geolocator.distanceBetween()`.
```dart
const double kMaxOrderRadiusKm = 10.0;

double calculateHaversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadiusKm = 6371.0;

  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);

  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusKm * c;
}
```
- `lib/views/driver_order_list_screen.dart` - lock UI jika driver masih punya order aktif atau sedang memproses order lain.
```dart
final bool isLocked = hasActive || _processingOrderId != null;

final String buttonText = hasActive
    ? 'Selesaikan Order Aktif'
    : 'Ambil Order';
```
- `lib/views/driver_order_list_screen.dart` - `_takeOrder()`: saat driver mengambil order, service dipanggil dulu; kalau sukses baru pindah ke map driver.
```dart
await _orderService.acceptOrder(
  orderId: order.orderId,
  driverId: _driverId,
);

if (!mounted) return;

_openMap(order.orderId);
```
- `lib/services/order_service.dart` - `hasActiveOrderForDriver()` dan `acceptOrder()`: backend guard tetap ada walau tombol UI sudah di-lock.
```dart
Future<bool> hasActiveOrderForDriver(String driverId) async {
  final snapshot = await _db
      .collection('orders')
      .where('driver_id', isEqualTo: driverId)
      .get();

  const activeStatuses = {OrderStatus.pickingUp, OrderStatus.delivering};

  return snapshot.docs
      .map((doc) => OrderModel.fromFirestore(doc))
      .any((order) => activeStatuses.contains(order.status));
}
```
```dart
final hasActive = await hasActiveOrderForDriver(driverId);
if (hasActive) {
  throw Exception(
    'Driver masih memiliki order aktif. Selesaikan order tersebut terlebih dahulu.',
  );
}

final docRef = _db.collection('orders').doc(orderId);
final doc = await docRef.get();

if (!doc.exists) {
  throw Exception('Order sudah tidak tersedia.');
}

final order = OrderModel.fromFirestore(doc);
if (order.status != OrderStatus.pending) {
  throw Exception('Order sudah tidak tersedia.');
}

await docRef.update({
  'driver_id': driverId,
  'status': OrderStatus.pickingUp.name,
  'updated_at': FieldValue.serverTimestamp(),
});
```
- `lib/widgets/location_status_banner.dart` - `LocationStatusBanner`: fallback lokasi punya aksi berbeda tergantung state, mis. retry, buka settings app, atau buka settings GPS.
```dart
switch (state) {
  case LocationBannerState.deniedForever:
    message =
        'Izin lokasi diblokir permanen. Aktifkan lewat Settings lalu coba lagi.';
    actionLabel = 'Settings';
    action = Geolocator.openAppSettings;
    break;
  case LocationBannerState.serviceOff:
    message = 'GPS tidak aktif.';
    actionLabel = 'Aktifkan';
    action = Geolocator.openLocationSettings;
    break;
  case LocationBannerState.denied:
    message = 'Izin lokasi ditolak.';
    actionLabel = 'Coba Lagi';
    action = onRetry;
    break;
```
**Known Limitation:**
- Lokasi driver diambil secara snapshot saat screen dibuka, saat app resume, atau saat pull-to-refresh; belum ada stream lokasi realtime untuk reranking otomatis.
- Ranking/filter jarak tetap client-side, jadi semua order pending tetap diunduh dulu dari Firestore sebelum dipilah di device.
- Radius maksimum masih fixed di `kMaxOrderRadiusKm = 10.0`, belum bisa diatur driver atau admin.
- Jarak Haversine adalah jarak garis lurus geografis, bukan jarak rute jalan; hasil badge jarak bisa berbeda dari jarak tempuh OSRM saat navigasi.
- Fallback tanpa lokasi memang aman, tetapi berarti driver tetap bisa melihat semua order pending tanpa filter radius jika GPS/permission bermasalah.
- Fitur ini membantu driver memilih order, tetapi belum ada auto-assign driver terdekat dari sisi server.

### Driver - Map & Proof of Delivery
**Alur:** Setelah driver mengambil order dari daftar, app membuka `MapDriverScreen(orderId)` dan menyerahkan orkestrasi map/tracking ke `MapViewModel`. Screen ini memuat detail order dari Firestore, mulai tracking lokasi driver, menggambar marker driver dan target, lalu menghitung polyline rute via OSRM. Selama status order masih `pickingUp`, target map adalah titik pickup dan tombol aksi hanya aktif jika driver sudah berada dekat lokasi pickup. Saat tombol ditekan, status order diubah ke `delivering`, target berpindah ke tujuan, dan rute dihitung ulang. Ketika driver sudah mendekati tujuan dalam radius 50 meter, flow proof of delivery dimulai: tombol berubah menjadi aksi ambil foto, kamera dibuka lewat `image_picker`, hasil foto dibaca sebagai bytes lalu di-encode ke base64 di memory. Setelah foto ada, tombol berubah menjadi `Selesaikan Pesanan`; saat ditekan, app menyimpan base64 itu ke `orders/{orderId}.proof_photo_url`, sekaligus mengubah status order menjadi `completed`, membersihkan route state, lalu mengembalikan driver ke home. Di layar ini driver juga bisa membuka chat dengan customer, dan screen menampilkan banner masalah lokasi jika GPS/permission bermasalah.
**Kode relevan:**
- `lib/views/driver_order_list_screen.dart` - `_takeOrder()`: flow map driver dimulai setelah order berhasil di-accept.
```dart
await _orderService.acceptOrder(
  orderId: order.orderId,
  driverId: _driverId,
);

if (!mounted) return;

_openMap(order.orderId);
```
- `lib/views/map_driver_screen.dart` - `initState()`: screen menyerahkan setup ke `MapViewModel`, termasuk fetch order dan mulai tracking lokasi.
```dart
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addObserver(this);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final MapViewModel viewModel = context.read<MapViewModel>();

    viewModel.setTickerProvider(this);
    viewModel.fetchOrderData(widget.orderId);
    viewModel.initLocation();

    _refreshLocationState();
  });
}
```
- `lib/viewmodels/map_viewmodel.dart` - `fetchOrderData()`: order diambil dari Firestore berdasarkan `orderId`, lalu disimpan ke state ViewModel.
```dart
Future<void> fetchOrderData(String orderId) async {
  try {
    final order = await _orderService.fetchOrderById(orderId);

    if (order == null) {
      debugPrint('Order dengan ID $orderId tidak ditemukan');
      return;
    }

    setOrder(order);
  } catch (e) {
    debugPrint("Gagal fetch order: $e");
  }
}
```
- `lib/viewmodels/map_viewmodel.dart` - `initLocation()` dan `startTracking()`: setelah izin lokasi lolos, app mulai stream posisi driver dan terus menulis `driver_lat/driver_lng` ke order.
```dart
Future<void> initLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return;

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
  }

  startTracking();
}
```
```dart
_positionStream =
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      LatLng newPos = LatLng(position.latitude, position.longitude);

      _currentLocation = newPos;
      notifyListeners();

      _orderService.updateDriverLocation(
        orderId: _currentOrder!.orderId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
```
- `lib/viewmodels/map_viewmodel.dart` - route dan proximity logic: route dihitung ulang saat driver bergerak lebih dari 50 meter, dan `_isAtLocation` menentukan apakah tombol pickup bisa diaktifkan.
```dart
if (_lastRouteUpdatePos == null) {
  loadRoute(newPos);
  _lastRouteUpdatePos = newPos;
  updateCameraBounds();
} else {
  double distance = Geolocator.distanceBetween(
    _lastRouteUpdatePos!.latitude,
    _lastRouteUpdatePos!.longitude,
    position.latitude,
    position.longitude,
  );

  if (distance > 50) {
    loadRoute(newPos);
    _lastRouteUpdatePos = newPos;
    updateCameraBounds();
  }
}
```
```dart
double distanceToTarget = Geolocator.distanceBetween(
  position.latitude,
  position.longitude,
  target.latitude,
  target.longitude,
);

_isAtLocation = distanceToTarget < 50;
notifyListeners();
```
- `lib/viewmodels/map_viewmodel.dart` - `loadRoute()`: target route berubah sesuai status order, pickup dulu lalu destination.
```dart
Future<void> loadRoute(LatLng start) async {
  if (_currentOrder == null) return;

  LatLng? target;

  if (_currentOrder!.status == OrderStatus.pickingUp) {
    target = _currentOrder!.pickupLocation;
  } else if (_currentOrder!.status == OrderStatus.delivering) {
    target = _currentOrder!.destinationLocation;
  }

  if (target == null) {
    _routePoints.clear();
    notifyListeners();
    return;
  }

  _routePoints = await _routingService.getRoute(start, target);
  notifyListeners();
}
```
- `lib/views/map_driver_screen.dart` - logika tombol utama di `build()`: screen menentukan mode pickup, delivery, atau completed berdasarkan status order dan jarak.
```dart
if (currentOrder.status == OrderStatus.pickingUp ||
    currentOrder.status == OrderStatus.accepted) {
  targetPoint = currentOrder.pickupLocation;
  buttonText = 'Pick Up Pesanan';

  buttonEnabled = viewModel.isAtLocation;
  buttonOnPressed = buttonEnabled ? () => viewModel.updateStatus() : null;
} else if (currentOrder.status == OrderStatus.delivering) {
  targetPoint = currentOrder.destinationLocation;

  if (viewModel.distanceInMeters > 50) {
    buttonText = 'Menuju Lokasi Tujuan';
    buttonEnabled = false;
    buttonOnPressed = null;
  } else if (_base64Photo.isEmpty) {
    buttonText = 'Ambil Foto Bukti';
    buttonEnabled = true;
    buttonOnPressed = _captureProofPhoto;
  } else {
    buttonText = 'Selesaikan Pesanan';
    buttonEnabled = !_isLoading;
    buttonOnPressed = _isLoading ? null : _completeOrderWithPhoto;
  }
}
```
- `lib/viewmodels/map_viewmodel.dart` - `updateStatus()`: saat pickup berhasil, status order maju ke `delivering` dan target route diperbarui.
```dart
if (_currentOrder!.status == OrderStatus.pickingUp) {
  nextStatus = OrderStatus.delivering;
} else if (_currentOrder!.status == OrderStatus.delivering) {
  nextStatus = OrderStatus.completed;
}

await _orderService.updateOrderStatus(
  orderId: _currentOrder!.orderId,
  status: nextStatus.name,
);

_currentOrder!.status = nextStatus;
```
- `lib/views/map_driver_screen.dart` - `_captureProofPhoto()`: kamera dibuka lewat `image_picker`, lalu hasilnya diubah menjadi base64 di memory.
```dart
final ImagePicker picker = ImagePicker();

final XFile? photo = await picker.pickImage(
  source: ImageSource.camera,
  imageQuality: 25,
  maxWidth: 700,
  maxHeight: 700,
);

if (photo == null) return;

final Uint8List bytes = await photo.readAsBytes();

setState(() {
  _base64Photo = base64Encode(bytes);
});
```
- `lib/views/map_driver_screen.dart` - `_completeOrderWithPhoto()`: jika foto sudah ada, screen meminta ViewModel menyelesaikan order lalu mengembalikan driver ke home.
```dart
if (_base64Photo.isEmpty || widget.orderId.isEmpty || _isLoading) {
  return;
}

setState(() {
  _isLoading = true;
});

final MapViewModel viewModel = context.read<MapViewModel>();

await viewModel.completeOrderWithPhoto(
  orderId: widget.orderId,
  base64Photo: _base64Photo,
);

Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(
    builder: (_) => const DriverHomeScreen(initialIndex: 1),
  ),
  (route) => false,
);
```
- `lib/viewmodels/map_viewmodel.dart` - `completeOrderWithPhoto()`: ViewModel menyimpan proof photo ke Firestore, mengubah status lokal jadi `completed`, lalu membersihkan state route.
```dart
Future<void> completeOrderWithPhoto({
  required String orderId,
  required String base64Photo,
}) async {
  if (_currentOrder == null) return;

  await _orderService.updateOrderWithProofPhoto(
    orderId: orderId,
    proofPhotoUrl: base64Photo,
  );

  _currentOrder!.status = OrderStatus.completed;
  _isAtLocation = false;
  _routePoints.clear();

  notifyListeners();
}
```
- `lib/services/order_service.dart` - `updateOrderWithProofPhoto()`: proof photo dan status completed ditulis dalam satu update Firestore.
```dart
Future<void> updateOrderWithProofPhoto({
  required String orderId,
  required String proofPhotoUrl,
}) async {
  await _db.collection('orders').doc(orderId).update({
    'proof_photo_url': proofPhotoUrl,
    'status': OrderStatus.completed.name,
    'updated_at': FieldValue.serverTimestamp(),
  });
}
```
- `lib/views/map_driver_screen.dart` - `_openChat()`: driver bisa membuka chat dari map screen selama `driverId` pada order valid.
```dart
void _openChat(OrderModel order) {
  final String? driverId = order.driverId;

  if (driverId == null || driverId.trim().isEmpty) {
    _showSnackBar('Data driver belum tersedia.');
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        orderId: order.orderId,
        currentUserId: driverId,
        customerId: order.customerId,
        driverId: driverId,
      ),
    ),
  );
}
```
- `lib/views/map_driver_screen.dart` - `_refreshLocationState()`: screen ini juga punya banner lokasi read-only untuk memberi tahu driver kalau GPS atau permission bermasalah.
```dart
Future<void> _refreshLocationState() async {
  final bool serviceOn = await Geolocator.isLocationServiceEnabled();
  if (!serviceOn) {
    setState(() => _locationProblem = LocationBannerState.serviceOff);
    return;
  }

  final LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.deniedForever) {
    setState(() => _locationProblem = LocationBannerState.deniedForever);
    return;
  }
  if (permission == LocationPermission.denied) {
    setState(() => _locationProblem = LocationBannerState.denied);
    return;
  }

  setState(() => _locationProblem = null);
}
```
**Known Limitation:**
- Proof photo masih disimpan sebagai string base64 langsung di dokumen Firestore `orders/{orderId}.proof_photo_url`, jadi ada risiko mendekati limit ukuran dokumen jika foto membesar.
- `firebase_storage` sudah ada di dependency, tetapi belum dipakai; saat ini belum ada upload file ke Storage.
- Belum ada preview, retake flow yang terstruktur, atau konfirmasi sebelum foto final dipakai untuk menyelesaikan order.
- `MapViewModel.startTracking()` menulis lokasi driver ke dokumen order, bukan ke koleksi terpisah seperti `driver_locations`; ini sederhana, tapi mencampur tracking dengan data order aktif.
- Screen map memakai banyak keputusan UI langsung di `build()`, terutama switching tombol pickup/delivery/proof, sehingga logikanya cukup padat di satu tempat.
- Status `accepted` masih diperlakukan setara dengan `pickingUp` pada beberapa percabangan, walau flow accept saat ini langsung mengubah status ke `pickingUp`.
- Parameter kompresi foto di kode saat ini (`imageQuality: 25`, `maxWidth/maxHeight: 700`) berbeda dari yang tertulis di `docs/milestone_7_proof_of_delivery.md` (`20` dan `500`); kemungkinan berubah saat merge UI rework dan dokumentasi milestone perlu disinkronkan di lain waktu.

### Profile Edit (customer & driver)
**Alur:** Baik customer maupun driver punya tab/profile section yang menampilkan nama, role, dan email dari `AuthViewModel.currentUser`. Saat user menekan ikon edit di card profile, app membuka `EditNameDialog`, yaitu dialog kecil yang hanya mengelola input teks dan mengembalikan nama baru lewat `Navigator.pop()`. Setelah dialog tertutup, caller di screen profile memanggil `AuthViewModel.updateUserName(newName)` untuk meng-update field `users/{uid}.name` di Firestore, lalu memperbarui `currentUser` di memory dengan `copyWith(name: trimmed)`. Karena UI profile membaca `AuthViewModel` lewat `context.watch`, nama baru langsung muncul tanpa restart screen. Pola ini dipakai sama di customer dan driver, jadi implementasi edit nama sekarang konsisten di dua role, walau milestone dokumentasi lama hanya menyebut customer.

**Kode relevan:**
- `lib/widgets/edit_name_dialog.dart` - `EditNameDialog`: dialog hanya mengelola `TextEditingController` sendiri dan mengembalikan string nama baru, tanpa async/Firestore di dalam dialog.
```dart
class EditNameDialog extends StatefulWidget {
  final String initialName;

  const EditNameDialog({super.key, required this.initialName});

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}
```

```dart
@override
void initState() {
  super.initState();
  _controller = TextEditingController(text: widget.initialName);
}

@override
void dispose() {
  _controller.dispose();
  super.dispose();
}

void _submit() => Navigator.of(context).pop(_controller.text.trim());
```
- `lib/viewmodels/auth_viewmodel.dart` - `updateUserName()`: perubahan nama ditulis ke Firestore lalu disinkronkan ke `currentUser` agar UI langsung rebuild.
```dart
Future<bool> updateUserName(String name) async {
  final user = _currentUser;
  if (user == null) return false;

  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    _errorMessage = 'Nama tidak boleh kosong.';
    return false;
  }

  _errorMessage = null;
  _setLoading(true);
  try {
    await _db.collection('users').doc(user.uid).update({'name': trimmed});
    _currentUser = user.copyWith(name: trimmed);
    return true;
  } catch (e) {
    _errorMessage = 'Gagal memperbarui nama: $e';
    return false;
  } finally {
    _setLoading(false);
  }
}
```
- `lib/views/customer/customer_home_screen.dart` - `_showEditNameDialog()`: profile customer membuka dialog, lalu baru menjalankan async update setelah dialog sudah tertutup.
```dart
Future<void> _showEditNameDialog(String currentName) async {
  final String? newName = await showDialog<String>(
    context: context,
    builder: (_) => EditNameDialog(initialName: currentName),
  );

  if (!mounted) return;
  if (newName == null || newName.isEmpty || newName == currentName) return;

  final auth = context.read<AuthViewModel>();
  final bool ok = await auth.updateUserName(newName);
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Nama berhasil diperbarui'
            : (auth.errorMessage ?? 'Gagal memperbarui nama'),
      ),
    ),
  );
}
```
- `lib/views/customer/customer_home_screen.dart` - `_buildProfilePage(auth)`: profile customer mengambil data dari `currentUser` dan menyediakan tombol edit nama.
```dart
final user = auth.currentUser;

final String name = user?.name.trim().isNotEmpty == true
    ? user!.name.trim()
    : 'Customer';

final String email = user?.email.trim().isNotEmpty == true
    ? user!.email.trim()
    : 'Email tidak tersedia';
```

```dart
Positioned(
  child: IconButton(
    tooltip: 'Edit nama',
    onPressed: () => _showEditNameDialog(name),
  ),
),
```
- `lib/views/driver/driver_home_screen.dart` - `_showEditNameDialog()`: flow edit nama driver sekarang sama dengan customer, memakai dialog dan ViewModel yang sama.
```dart
Future<void> _showEditNameDialog(String currentName) async {
  final String? newName = await showDialog<String>(
    context: context,
    builder: (_) => EditNameDialog(initialName: currentName),
  );

  if (!mounted) return;
  if (newName == null || newName.isEmpty || newName == currentName) return;

  final auth = context.read<AuthViewModel>();
  final bool ok = await auth.updateUserName(newName);
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Nama berhasil diperbarui'
            : (auth.errorMessage ?? 'Gagal memperbarui nama'),
      ),
    ),
  );
}
```
- `lib/views/driver/driver_home_screen.dart` - `_buildProfilePage(...)`: driver profile juga menampilkan role/email dan menaruh ikon edit di card nama.
```dart
Widget _buildProfilePage({
  required AuthViewModel auth,
  required String name,
  required String email,
}) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 115),
    children: [
      Text('Profile'),
```

```dart
const _ProfileInformationRow(
  icon: Icons.badge_outlined,
  label: 'Role',
  value: 'Driver',
),
_ProfileInformationRow(
  icon: Icons.email_outlined,
  label: 'Email',
  value: email,
),
```

```dart
Positioned(
  child: IconButton(
    tooltip: 'Edit nama',
    onPressed: () => _showEditNameDialog(name),
  ),
),
```
- `lib/views/customer/customer_home_screen.dart` dan `lib/views/driver/driver_home_screen.dart` - kedua profile page membaca data dari `context.watch<AuthViewModel>()`, jadi update nama langsung tercermin di UI.
```dart
final AuthViewModel auth = context.watch<AuthViewModel>();
final user = auth.currentUser;
```

**Known Limitation:**
- Yang bisa diedit saat ini baru `name`; `email`, `role`, dan foto profil belum bisa diubah dari app.
- Validasi nama masih minimal: hanya trim dan cek tidak kosong, belum ada validasi panjang maksimum, karakter, atau sanitasi lebih lanjut.
- Implementasi milestone lama di `docs/milestone_10_profile_edit_role_consolidation.md` sudah outdated untuk bagian scope profile, karena kode sekarang juga mendukung edit nama di sisi driver.
- Belum ada loading indicator khusus di dialog; feedback edit masih berupa `SnackBar` setelah dialog tertutup.
- Jika dokumen `users/{uid}` bermasalah atau update Firestore gagal, UI hanya menampilkan pesan error generik dari `AuthViewModel`.

### Admin Dashboard
**Alur:** Setelah admin login, bottom navigation mengarahkan role ini ke area admin yang terdiri dari lima tab: `Dashboard`, `Users`, `Orders`, `Tracking`, dan `Profile`. `AdminViewModel` sudah diinisialisasi sejak app start, lalu memasang empat stream dashboard untuk menghitung total order, active drivers, ongoing orders, dan completed orders. Di tab `Dashboard`, admin melihat kartu ringkasan dan recent activity order terbaru. Dari tab `Users`, admin bisa beralih antara daftar driver dan customer, lalu mencari nama, email, atau nomor telepon sebelum membuka detail user. Dari tab `Orders`, admin bisa melihat semua order, memfilter status, mencari ID/alamat/barang, lalu membuka detail order yang memuat customer, driver, lokasi, biaya, dan proof of delivery. Dari tab `Tracking`, admin melihat daftar order aktif, membuka detail tracking, lalu masuk ke live tracking untuk memantau posisi driver di peta secara realtime lewat `driver_locations`. Tab `Profile` menampilkan informasi akun admin dan menyediakan sign out, tetapi belum ada edit profile dari sisi admin.

**Kode relevan:**
- `lib/main.dart` - provider admin diinisialisasi sekali saat app start, bukan per-screen.
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => MapViewModel()),
    ChangeNotifierProvider(create: (_) => AuthViewModel()),
    ChangeNotifierProvider(
      create: (_) => AdminViewModel()..initAdminDashboard(),
    ),
  ],
  child: const MyApp(),
)
```
- `lib/views/admin/admin_bottom_bar.dart` - `_openPage()`: semua tab admin dipindah via bottom bar dengan `pushAndRemoveUntil`.
```dart
switch (index) {
  case 0:
    destination = const AdminHomeScreen();
    break;
  case 1:
    destination = const AdminUsersScreen();
    break;
  case 2:
    destination = const AdminOrdersScreen();
    break;
  case 3:
    destination = const AdminTrackingListScreen();
    break;
  case 4:
    destination = const AdminProfileScreen();
    break;
}
```
- `lib/viewmodels/admin_viewmodel.dart` - `initAdminDashboard()`: empat stream utama dashboard dipasang dan hasilnya disimpan ke state ViewModel.
```dart
void initAdminDashboard() {
  if (_dashboardInitialized) return;

  _dashboardInitialized = true;
  isLoading = true;
  dashboardError = null;
  notifyListeners();

  _totalOrdersSubscription = _adminService.watchTotalOrders().listen((value) {
    totalOrders = value;
    markStreamLoaded();
    notifyListeners();
  }, onError: handleError);

  _activeDriversSubscription = _adminService.watchActiveDrivers().listen((
    value,
  ) {
    activeDrivers = value;
    markStreamLoaded();
    notifyListeners();
  }, onError: handleError);
```

```dart
  _ongoingOrdersSubscription = _adminService.watchOngoingOrders().listen((
    value,
  ) {
    ongoingOrders = value;
    markStreamLoaded();
    notifyListeners();
  }, onError: handleError);

  _completedOrdersSubscription = _adminService.watchCompletedOrders().listen((
    value,
  ) {
    completedOrders = value;
    markStreamLoaded();
    notifyListeners();
  }, onError: handleError);
}
```
- `lib/services/admin_service.dart` - sumber angka dashboard berasal dari koleksi `orders` dan `driver_locations`.
```dart
Stream<int> watchTotalOrders() {
  return _firestore
      .collection('orders')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

Stream<int> watchActiveDrivers() {
  return _firestore
      .collection('driver_locations')
      .where('is_online', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}
```

```dart
Stream<int> watchOngoingOrders() {
  return _firestore
      .collection('orders')
      .where(
        'status',
        whereIn: const [
          'pending',
          'accepted',
          'pickingUp',
          'delivering',
          'onDelivery',
        ],
      )
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

Stream<int> watchCompletedOrders() {
  return _firestore
      .collection('orders')
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}
```
- `lib/views/admin/admin_home_screen.dart` - overview dashboard menampilkan empat kartu ringkasan realtime.
```dart
_DashboardCard(
  title: 'Total Orders',
  value: admin.totalOrders,
  icon: Icons.inventory_2_outlined,
  onTap: _openOrders,
),
_DashboardCard(
  title: 'Active Drivers',
  value: admin.activeDrivers,
  icon: Icons.delivery_dining_rounded,
),
_DashboardCard(
  title: 'Ongoing Orders',
  value: admin.ongoingOrders,
  icon: Icons.access_time_rounded,
  onTap: _openOrders,
),
_DashboardCard(
  title: 'Completed',
  value: admin.completedOrders,
  icon: Icons.check_circle_outline_rounded,
  onTap: _openOrders,
),
```
- `lib/views/admin/admin_home_screen.dart` - recent activity mengambil stream order terbaru dan hanya menampilkan empat item pertama.
```dart
return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
  stream: admin.watchOrders(),
  builder: (context, snapshot) {
    final documents = snapshot.data!.docs.take(4).toList();
```
- `lib/views/admin/admin_users_screen.dart` - filter role dan search user dikelola di `AdminViewModel`.
```dart
_RoleButton(
  label: 'Driver',
  selected: admin.selectedUserRole == 'driver',
  onTap: () {
    admin.changeUserRole('driver');
  },
),
_RoleButton(
  label: 'Customer',
  selected: admin.selectedUserRole == 'customer',
  onTap: () {
    admin.changeUserRole('customer');
  },
),
```

```dart
onChanged: (value) {
  admin.changeUserSearchQuery(value);
  setState(() {});
},
```
- `lib/viewmodels/admin_viewmodel.dart` - `watchSelectedUsers()` dan `isUserMatchSearch()`: query Firestore hanya per-role, lalu search dilakukan client-side.
```dart
Stream<QuerySnapshot<Map<String, dynamic>>> watchSelectedUsers() {
  return _adminService.watchUsersByRole(selectedUserRole);
}
```

```dart
bool isUserMatchSearch(Map<String, dynamic> data) {
  if (userSearchQuery.isEmpty) return true;

  final String email = data['email']?.toString().toLowerCase() ?? '';
  final String name = data['name']?.toString().toLowerCase() ?? '';
  final String phone = data['phone']?.toString().toLowerCase() ?? '';

  return email.contains(userSearchQuery) ||
      name.contains(userSearchQuery) ||
      phone.contains(userSearchQuery);
}
```
- `lib/views/admin/admin_user_detail_screen.dart` - detail user dibaca realtime dari `users/{uid}` dan menampilkan status online khusus role driver.
```dart
stream: admin.watchUserDetail(uid),
builder: (context, snapshot) {
  final Map<String, dynamic> data = snapshot.data!.data() ?? {};
  final String role = data['role']?.toString() ?? '-';
  final bool isOnline =
      data['is_online'] == true ||
      data['isOnline'] == true;
```
- `lib/views/admin/admin_order_list_screen.dart` - order list mendukung search dan filter status.
```dart
_OrderFilterChip(
  label: 'All',
  selected: admin.selectedOrderStatus == 'all',
  onTap: () {
    admin.changeOrderStatus('all');
  },
),
_OrderFilterChip(
  label: 'On Delivery',
  selected: admin.selectedOrderStatus == 'onDelivery',
  onTap: () {
    admin.changeOrderStatus('onDelivery');
  },
),
```

```dart
final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders =
    (snapshot.data?.docs ?? []).where((document) {
      final Map<String, dynamic> data = document.data();
      final String status = data['status']?.toString() ?? '';

      return admin.isOrderMatchStatus(status) &&
          admin.isOrderMatchSearch(document.id, data);
    }).toList();
```
- `lib/viewmodels/admin_viewmodel.dart` - status filter dan search order juga diproses di sisi client.
```dart
bool isOrderMatchStatus(String status) {
  final String normalized = status.trim();

  if (selectedOrderStatus == 'all') {
    return true;
  }

  if (selectedOrderStatus == 'onDelivery') {
    return normalized == 'pickingUp' ||
        normalized == 'delivering' ||
        normalized == 'onDelivery';
  }

  if (selectedOrderStatus == 'cancelled') {
    return normalized == 'cancelled' || normalized == 'cancel';
  }

  return normalized == selectedOrderStatus;
}
```

```dart
bool isOrderMatchSearch(String documentId, Map<String, dynamic> data) {
  if (orderSearchQuery.isEmpty) return true;

  final String orderId = documentId.toLowerCase();
  final String pickup =
      data['pickup_address']?.toString().toLowerCase() ?? '';
  final String destination =
      (data['dest_address'] ?? data['destination_address'])
          ?.toString()
          .toLowerCase() ??
      '';
  final String item =
      data['item_description']?.toString().toLowerCase() ?? '';

  return orderId.contains(orderSearchQuery) ||
      pickup.contains(orderSearchQuery) ||
      destination.contains(orderSearchQuery) ||
      item.contains(orderSearchQuery);
}
```
- `lib/views/admin/admin_order_detail_screen.dart` - detail order merangkum biaya, lokasi, customer, driver, dan proof of delivery.
```dart
final String proofValue =
    (data['proof_photo_url'] ??
            data['proof_url'] ??
            data['proof_photo_base64'] ??
            data['delivery_proof'] ??
            '')
        .toString();
```

```dart
_UserInformationCard(
  title: 'Customer Information',
  userId: customerId,
  icon: Icons.person_outline_rounded,
),
_UserInformationCard(
  title: 'Driver Information',
  userId: driverId,
  icon: Icons.delivery_dining_rounded,
),
if (proofValue.trim().isNotEmpty) ...[
  _buildProofCard(proofValue),
],
```
- `lib/views/admin/admin_tracking_list_screen.dart` - tracking list hanya menampilkan order aktif, lalu membuka detail tracking.
```dart
final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders =
    (snapshot.data?.docs ?? []).where((document) {
      final String status = document.data()['status']?.toString() ?? '';

      return status == 'accepted' ||
          status == 'pickingUp' ||
          status == 'delivering' ||
          status == 'onDelivery';
    }).toList();
```
- `lib/views/admin/admin_tracking_detail_screen.dart` - detail tracking menggabungkan data `orders/{orderId}` dan `driver_locations/{driverId}` untuk menghitung jarak sisa dan membuka live tracking.
```dart
stream: admin.watchOrderDetail(orderId),
builder: (context, snapshot) {
  final Map<String, dynamic> orderData = snapshot.data!.data() ?? {};
  final String driverId = orderData['driver_id']?.toString() ?? '';

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: driverId.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection('driver_locations')
              .doc(driverId)
              .snapshots(),
```

```dart
final String remainingDistance = hasDriverLocation && hasDestination
    ? admin.formatRemainingDistance(
        driverLat: driverLat,
        driverLng: driverLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      )
    : '-';
```
- `lib/views/admin/admin_live_tracking_screen.dart` - live tracking menampilkan peta realtime driver dengan marker pickup-driver-destination.
```dart
return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseFirestore.instance
      .collection('driver_locations')
      .doc(driverId)
      .snapshots(),
```

```dart
final List<LatLng> routePoints = [
  if (pickupPosition != null) pickupPosition,
  driverPosition,
  if (destinationPosition != null) destinationPosition,
];
```
- `lib/views/admin/admin_profile_screen.dart` - profile admin saat ini bersifat read-only dan hanya punya flow sign out.
```dart
await context.read<AuthViewModel>().signOut();

Navigator.of(context).pushAndRemoveUntil(
  PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) {
      return const LoginScreen();
    },
```

**Known Limitation:**
- Sumber data `activeDrivers` di dashboard memakai `driver_locations.is_online`, tetapi list/detail user driver membaca `users.is_online` atau `users.isOnline`; dua sumber ini bisa tidak sinkron.
- Flow driver yang aktif sekarang menulis lokasi ke dokumen order (`driver_lat/driver_lng`) dan tidak terlihat ada updater `driver_locations` di flow map driver, jadi dashboard/tracking admin bisa bergantung pada data legacy atau listener terpisah.
- Search user dan search/filter order dilakukan client-side setelah snapshot penuh diterima; belum ada pagination atau query Firestore yang lebih sempit.
- `AdminHomeScreen` punya helper `watchRecentOrders(limit: 4)` di service/viewmodel, tetapi implementasi screen saat ini memakai `admin.watchOrders().take(4)` langsung.
- `AdminTrackingDetailScreen` dan `AdminLiveTrackingScreen` menggambar garis lurus antar titik, bukan rute jalan OSRM seperti screen driver/customer.
- ETA di tracking detail hanya membaca field seperti `estimated_time`, `eta`, atau `duration_text`; jika field itu tidak pernah ditulis oleh flow operasional, nilainya akan tampil `-`.
- `AdminProfileScreen` belum mendukung edit nama/email/profile, hanya display akun dan sign out.

### FCM Push Notification (client + VPS listener)
**Alur:** Implementasi notifikasi di project ini dibagi dua sisi. Di sisi client Flutter, setiap user yang berhasil login, register, memilih role, atau restore sesi akan mendaftarkan token FCM ke `users/{uid}.fcm_token`. Saat app sedang `foreground`, pesan FCM tidak dibiarkan hanya lewat diam-diam; `NotificationService` menangkap `FirebaseMessaging.onMessage` lalu menampilkan notif lokal dengan `flutter_local_notifications`. Saat app `background` atau `terminated`, `main.dart` mendaftarkan background handler dan payload notifikasi dikirim dalam format `notification + data`, sehingga sistem operasi bisa menampilkan push notification secara otomatis. Di sisi server, project ini tidak memakai Cloud Functions; arsitekturnya memakai proses Node.js di VPS pribadi yang listen koleksi `orders` memakai `firebase-admin`. Alasan praktisnya adalah constraint proyek untuk menghindari ketergantungan ke Blaze plan, sehingga listener dijalankan sebagai service terpisah di VPS. Listener ini meng-cache snapshot awal agar tidak spam saat boot, lalu mengirim notif ke semua driver ketika ada order baru `pending`, dan mengirim notif ke customer saat status order berubah ke `pickingUp`, `delivering`, atau `completed`. Setup ini sudah diverifikasi manual pada tiga state aplikasi: `foreground`, `background`, dan `terminated`, termasuk saat app di-swipe-close total dari recent apps; notifikasi tetap diterima karena trigger berasal dari server VPS, bukan proses Flutter yang masih hidup.

**Kode relevan:**
- `lib/viewmodels/auth_viewmodel.dart` - `_registerFcmToken()`: token registration dipanggil secara fire-and-forget setelah auth berhasil, agar flow login tidak tertahan dialog izin/notifikasi.
```dart
void _registerFcmToken(String uid) {
  unawaited(NotificationService().registerTokenForUser(uid));
}
```
- `lib/viewmodels/auth_viewmodel.dart` - token didaftarkan di semua entry point sesi aktif: login email, register, Google existing user, select role, dan restore session.
```dart
_currentUser = user;
_registerFcmToken(user.uid);
```

```dart
_currentUser = UserModel(uid: uid, email: email, name: name, role: role);
_registerFcmToken(uid);
```

```dart
if (existing != null) {
  _currentUser = existing;
  _registerFcmToken(existing.uid);
}
```

```dart
_currentUser = _currentUser!.copyWith(role: role);
_registerFcmToken(uid);
```

```dart
if (user != null) {
  _currentUser = user;
  _registerFcmToken(user.uid);
}
```
- `lib/services/notification_service.dart` - `registerTokenForUser()`: client meminta permission, mengambil token FCM, menyimpan ke `users/{uid}.fcm_token`, lalu memasang listener refresh token.
```dart
Future<void> registerTokenForUser(String uid) async {
  if (uid.isEmpty) return;
  _activeUid = uid;

  try {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    if (token != null) {
      await _writeToken(uid, token);
    }

    if (!_tokenRefreshAttached) {
      _tokenRefreshAttached = true;
      _messaging.onTokenRefresh.listen((newToken) {
        final current = _activeUid;
        if (current != null && current.isNotEmpty) {
          _writeToken(current, newToken);
        }
      });
    }
  } catch (e) {
    debugPrint('registerTokenForUser gagal: $e');
  }
}
```
- `lib/services/notification_service.dart` - `_writeToken()` dan `clearTokenForUser()`: token ditulis saat login dan dihapus saat logout supaya notif tidak nyasar ke akun/device session lama.
```dart
Future<void> _writeToken(String uid, String token) async {
  await _db.collection('users').doc(uid).set({
    'fcm_token': token,
  }, SetOptions(merge: true));
}
```

```dart
Future<void> clearTokenForUser(String uid) async {
  _activeUid = null;
  if (uid.isEmpty) return;
  try {
    await _db.collection('users').doc(uid).set({
      'fcm_token': FieldValue.delete(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('clearTokenForUser gagal: $e');
  }
}
```
- `lib/viewmodels/auth_viewmodel.dart` - `signOut()`: logout membersihkan token sebelum `FirebaseAuth.signOut()`.
```dart
Future<void> signOut() async {
  final uid = _currentUser?.uid;
  if (uid != null && uid.isNotEmpty) {
    await NotificationService().clearTokenForUser(uid);
  }
  await _auth.signOut();
  try {
    await _googleSignIn.signOut();
  } catch (_) {}
  _currentUser = null;
  notifyListeners();
}
```
- `lib/main.dart` - inisialisasi FCM di app startup: background handler didaftarkan, local notifications diinisialisasi, lalu listener foreground dipasang.
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
await NotificationService().initLocalNotifications();
NotificationService().setupForegroundListener();
```
- `lib/main.dart` - handler untuk `background/terminated`: payload tetap diterima saat app tidak sedang aktif di depan.
```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('FCM background message: ${message.messageId}');
}
```
- `lib/services/notification_service.dart` - `setupForegroundListener()`: saat app `foreground`, notif sistem ditampilkan manual lewat `flutter_local_notifications`.
```dart
void setupForegroundListener() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  });
}
```
- `server/fcm-notifier/index.js` - notifier VPS memakai `firebase-admin` dan service account, lalu listen langsung ke Firestore dari proses Node.js terpisah.
```js
const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, 'service-account.json'));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
```
- `server/fcm-notifier/index.js` - `sendNotification()`: server mengambil `users/{uid}.fcm_token` sebelum mengirim push.
```js
async function sendNotification(uid, title, body, data = {}) {
  if (!uid) return;
  const userDoc = await db.collection('users').doc(uid).get();
  const token = userDoc.data()?.fcm_token;
  if (!token) {
    console.log(`[skip] uid=${uid} belum punya fcm_token (mungkin belum login ulang setelah Fase 1)`);
    return;
  }
  try {
    await admin.messaging().send({ token, notification: { title, body }, data });
    console.log(`[sent] uid=${uid} title="${title}"`);
  } catch (err) {
    console.error(`[error] gagal kirim ke uid=${uid}:`, err.message);
  }
}
```
- `server/fcm-notifier/index.js` - `notifyAllDrivers()`: order baru `pending` mem-broadcast notif ke semua user dengan role `driver`.
```js
async function notifyAllDrivers(orderId, order) {
  const drivers = await db.collection('users').where('role', '==', 'driver').get();
  drivers.forEach((doc) => {
    sendNotification(
      doc.id,
      'Order Baru Tersedia',
      `${order.item_description ?? 'Barang'} menunggu driver`,
      { orderId, type: 'new_order' }
    );
  });
}
```
- `server/fcm-notifier/index.js` - `statusCopy` dan listener `orders.onSnapshot()`: perubahan status tertentu diterjemahkan jadi notif ke customer.
```js
const statusCopy = {
  pickingUp: 'Driver sedang menjemput barangmu',
  delivering: 'Barang sedang diantar ke tujuan',
  completed: 'Pesanan selesai! Yuk beri rating ke driver',
};
```

```js
db.collection('orders').onSnapshot(
  (snapshot) => {
    if (isFirstSnapshot) {
      snapshot.docs.forEach((doc) => lastKnownStatus.set(doc.id, doc.data().status));
      isFirstSnapshot = false;
      console.log(`[init] ${snapshot.size} order ter-cache, siap listen perubahan baru`);
      return;
    }

    snapshot.docChanges().forEach((change) => {
      const order = change.doc.data();
      const orderId = change.doc.id;

      if (change.type === 'added' && order.status === 'pending') {
        console.log(`[event] order baru pending: ${orderId}`);
        notifyAllDrivers(orderId, order);
      }

      if (change.type === 'modified') {
        const prevStatus = lastKnownStatus.get(orderId);
        if (prevStatus && prevStatus !== order.status && statusCopy[order.status]) {
          console.log(`[event] order ${orderId} status ${prevStatus} -> ${order.status}`);
          sendNotification(order.customer_id, 'Update Pesanan', statusCopy[order.status], {
            orderId,
            type: 'status_update',
          });
        }
      }

      lastKnownStatus.set(orderId, order.status);
    });
  },
```
- `docs/milestone_5_customer_tracking.md` dan `docs/milestone_8_chat_customer_driver.md` - milestone sebelumnya memang sudah menandai push notification sebagai fase lanjutan dan chat notif belum tersedia.
```text
Push Notification — notifikasi order diterima, status berubah.
```

```text
Belum ada notifikasi (FCM) saat pesan baru — perlu Milestone notifikasi.
```

**Known Limitation:**
- Arsitektur VPS ini bergantung pada proses Node.js yang harus hidup terus; belum ada deployment manifest, `package.json`, atau config process manager di `server/fcm-notifier/`, jadi operasional server belum terdokumentasi penuh di repo.
- Listener saat ini hanya mengirim dua kategori event: `new_order` ke semua driver dan `status_update` ke customer; belum ada notif FCM untuk chat baru, rating, admin event, atau notif terfilter radius driver.
- `notifyAllDrivers()` masih broadcast ke semua driver, belum digabung dengan logika Haversine/radius dari sisi server.
- Token yang disimpan hanya satu field `fcm_token` per user, jadi skenario multi-device per akun belum ditangani.
- Belum ada handler `onMessageOpenedApp` atau `getInitialMessage()`, jadi tap notifikasi belum diarahkan ke screen spesifik seperti tracking/chat.
- Notifier VPS memakai `service-account.json` lokal, tetapi file credential dan prosedur secret management tidak ada di repo.
- Alasan memakai VPS pribadi, bukan Cloud Functions, berasal dari constraint biaya/plan proyek untuk menghindari Blaze plan; konsekuensinya semua reliability, restart process, dan monitoring listener harus diurus sendiri di VPS.
