import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';

enum CustomerOrderFlowState {
  waiting,
  driverAssigned,
  cancelled,
  timeout,
  error,
}

class CustomerOrderViewModel extends ChangeNotifier {
  CustomerOrderViewModel({required this.orderId}) {
    _startManualCancelTimer();
    _startSystemTimeoutTimer();
    _listenToOrderDocument();
  }

  final String orderId;
  final OrderService _orderService = OrderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _orderSubscription;
  Timer? _manualCancelTimer;
  Timer? _systemTimeoutTimer;

  OrderModel? _currentOrder;
  // OrderStatus? _lastKnownStatus;
  String? _lastKnownDriverId;
  bool _canCancel = true;
  int _cancelCountdown = 10;
  bool _isHandlingTerminalState = false;
  CustomerOrderFlowState _state = CustomerOrderFlowState.waiting;
  String? _message;

  Stream<OrderModel?> get orderStream => _firestore
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);

  OrderModel? get currentOrder => _currentOrder;
  bool get canCancel => _canCancel && _state == CustomerOrderFlowState.waiting;
  int get cancelCountdown => _cancelCountdown;
  CustomerOrderFlowState get state => _state;
  String? get message => _message;
  bool get hasDriverAssigned =>
      (_currentOrder?.driverId ?? '').trim().isNotEmpty;

  @override
  void dispose() {
    _stopTimers();
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _listenToOrderDocument() {
    _orderSubscription = _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen(
          _handleOrderSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Failed to listen order $orderId: $error');
            if (_state == CustomerOrderFlowState.waiting) {
              _state = CustomerOrderFlowState.error;
              _message = 'Gagal memantau order.';
              notifyListeners();
            }
          },
        );
  }

  void _handleOrderSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) {
      return;
    }

    final order = OrderModel.fromFirestore(doc);
    final previousDriverId = _lastKnownDriverId;
    final driverId = order.driverId?.trim();

    _currentOrder = order;
    // _lastKnownStatus = order.status;
    _lastKnownDriverId = driverId;

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

    if (order.status == OrderStatus.cancelled &&
        _state == CustomerOrderFlowState.waiting) {
      _state = CustomerOrderFlowState.cancelled;
      _message = 'Order dibatalkan.';
      _stopTimers();
    }

    notifyListeners();
  }

  void _startManualCancelTimer() {
    _manualCancelTimer?.cancel();
    _canCancel = true;
    _cancelCountdown = 10;
    notifyListeners();

    _manualCancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != CustomerOrderFlowState.waiting) {
        timer.cancel();
        return;
      }

      if (_cancelCountdown <= 1) {
        _cancelCountdown = 0;
        _canCancel = false;
        timer.cancel();
      } else {
        _cancelCountdown -= 1;
      }

      notifyListeners();
    });
  }

  void _startSystemTimeoutTimer() {
    _systemTimeoutTimer?.cancel();

    _systemTimeoutTimer = Timer(const Duration(seconds: 60), () async {
      if (_state != CustomerOrderFlowState.waiting || hasDriverAssigned) {
        return;
      }

      if (_isHandlingTerminalState) {
        return;
      }

      _isHandlingTerminalState = true;
      _state = CustomerOrderFlowState.timeout;
      _message = 'Tidak ada driver yang menerima order.';
      _stopTimers();

      try {
        await _orderService.updateOrderStatus(
          orderId: orderId,
          status: OrderStatus.cancelled.name,
        );
      } catch (error) {
        debugPrint('Failed to cancel order on timeout: $error');
      } finally {
        _isHandlingTerminalState = false;
        notifyListeners();
      }
    });
  }

  void _stopTimers() {
    _manualCancelTimer?.cancel();
    _manualCancelTimer = null;
    _systemTimeoutTimer?.cancel();
    _systemTimeoutTimer = null;
    _canCancel = false;
    _cancelCountdown = 0;
  }

  Future<void> cancelOrder() async {
    if (_state != CustomerOrderFlowState.waiting || _isHandlingTerminalState) {
      return;
    }

    _isHandlingTerminalState = true;
    _state = CustomerOrderFlowState.cancelled;
    _message = 'Pesanan dibatalkan.';
    _stopTimers();
    notifyListeners();

    try {
      await _orderService.updateOrderStatus(
        orderId: orderId,
        status: OrderStatus.cancelled.name,
      );
    } catch (error) {
      debugPrint('Failed to cancel order manually: $error');
    } finally {
      _isHandlingTerminalState = false;
      notifyListeners();
    }
  }
}
