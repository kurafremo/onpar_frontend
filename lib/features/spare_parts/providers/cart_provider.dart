import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spare_part_model.dart';

// Sepetteki her bir ürünü ve miktarını tutacak sınıf
class CartItem {
  final SparePart part;
  final int quantity;

  CartItem({required this.part, this.quantity = 1});

  CartItem copyWith({SparePart? part, int? quantity}) {
    return CartItem(
      part: part ?? this.part,
      quantity: quantity ?? this.quantity,
    );
  }
}

// Sepet State Yöneticisi (Riverpod Notifier)
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => []; // Başlangıçta sepet boş

  // Sepete ürün ekle (Eğer ürün zaten varsa miktarını artırır)
  void addToCart(SparePart part, {int quantity = 1}) {
    final existingIndex = state.indexWhere((item) => item.part.id == part.id);
    
    if (existingIndex >= 0) {
      // Ürün zaten sepette var, miktarını güncelle
      final updatedItem = state[existingIndex].copyWith(
        quantity: state[existingIndex].quantity + quantity,
      );
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // Ürün sepette yok, yeni ekle
      state = [...state, CartItem(part: part, quantity: quantity)];
    }
  }

  // Sepetten ürün çıkar
  void removeFromCart(String partId) {
    state = state.where((item) => item.part.id != partId).toList();
  }

  // Ürün miktarını doğrudan güncelle (+ / - butonları için)
  void updateQuantity(String partId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(partId);
      return;
    }
    
    final existingIndex = state.indexWhere((item) => item.part.id == partId);
    if (existingIndex >= 0) {
      final updatedItem = state[existingIndex].copyWith(quantity: quantity);
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    }
  }

  // Sepeti tamamen boşalt
  void clearCart() {
    state = [];
  }

  // Sepetin genel toplam tutarını hesapla
  double get totalPrice {
    return state.fold(0, (sum, item) => sum + (item.part.sellPrice * item.quantity));
  }
}

// Tüm uygulamadan erişilecek Global Provider
final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(() {
  return CartNotifier();
});