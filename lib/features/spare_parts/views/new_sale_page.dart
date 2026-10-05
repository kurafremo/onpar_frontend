import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import '../providers/spare_part_provider.dart';
import '../models/spare_part_model.dart';
import '../models/sale_record_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart'; // YENİ EKLENEN GLOBAL SEPET
import 'add_part_page.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/dio_error_handler.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';

// DİKKAT: Yerel CartItem sınıfını sildik, artık cart_provider.dart'tan geliyor.

class NewSalePage extends ConsumerStatefulWidget {
  final SaleRecord? editRecord;
  final String? initialBarcode;

  const NewSalePage({super.key, this.editRecord, this.initialBarcode});

  @override
  ConsumerState<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends ConsumerState<NewSalePage> {
  final _buyerNameCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _vehicleBrandModelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  
  TextEditingController? _searchFieldController;
  
  String _selectedPaymentMethod = 'Nakit';
  bool _isLoading = false;
  int? _selectedCustomerId; 

  // Dinamik Fiyat Hesaplayıcıları (Global sepetten okur)
  double get _totalPrice => ref.read(cartProvider).fold(0, (sum, item) => sum + (item.part.sellPrice * item.quantity));
  double get _totalCost => ref.read(cartProvider).fold(0, (sum, item) => sum + (item.part.buyPrice * item.quantity));
  double get _netProfit => _totalPrice - _totalCost;

  @override
  void initState() {
    super.initState();
    if (widget.editRecord != null) {
      _loadEditData();
    }
    
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processScannedBarcode(widget.initialBarcode!);
      });
    }
  }

  void _loadEditData() {
    _buyerNameCtrl.text = widget.editRecord!.buyerName ?? '';
    _companyNameCtrl.text = widget.editRecord!.companyName ?? '';
    _vehiclePlateCtrl.text = widget.editRecord!.vehiclePlate ?? '';
    _vehicleBrandModelCtrl.text = widget.editRecord!.vehicleBrandModel ?? '';
    _notesCtrl.text = widget.editRecord!.notes ?? '';
    
    if (['Nakit', 'Kredi Kartı', 'Havale'].contains(widget.editRecord!.paymentMethod)) {
      _selectedPaymentMethod = widget.editRecord!.paymentMethod;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final parts = ref.read(sparePartsProvider).value ?? [];
      ref.read(cartProvider.notifier).clearCart(); // Eski sepeti temizle
      
      try {
        final realPart = parts.firstWhere(
          (p) => p.id.toString() == widget.editRecord!.partId.toString(),
        );
        ref.read(cartProvider.notifier).addToCart(realPart, quantity: widget.editRecord!.quantity);
      } catch (e) {
        final dummyPart = SparePart(
          id: widget.editRecord!.partId.toString(),
          name: widget.editRecord!.partName ?? 'Katalogdan Silinmiş Parça',
          buyPrice: 0.0,
          sellPrice: widget.editRecord!.unitPrice,
          stockQuantity: 9999,
        );
        ref.read(cartProvider.notifier).addToCart(dummyPart, quantity: widget.editRecord!.quantity);
      }
    });
  }

  @override
  void dispose() {
    _buyerNameCtrl.dispose();
    _companyNameCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _vehicleBrandModelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcodeWithCamera() async {
    String? barcode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
    );

    if (barcode != null && barcode != '-1' && barcode.isNotEmpty) {
      _processScannedBarcode(barcode.trim());
    }
  }

  void _processScannedBarcode(String barcode) {
    final parts = ref.read(sparePartsProvider).value ?? [];
    try {
      final match = parts.firstWhere((p) => p.barcode == barcode || p.oemCode == barcode);
      _addToCart(match);
      _clearSearchField();
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple),
              SizedBox(width: 8),
              Text('Barkod Bulunamadı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '"$barcode" barkodlu ürün stokta kayıtlı değil.\n\nYapay Zeka (Gemini) ile bu parçayı otomatik analiz edip stoklara eklemek ister misiniz?',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddPartPage(initialBarcode: barcode)),
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI ile Tanımla & Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _clearSearchField() {
    _searchFieldController?.clear();
    FocusScope.of(context).unfocus();
  }

  void _addToCart(SparePart part) {
    final cart = ref.read(cartProvider);
    final existingItem = cart.where((item) => item.part.id == part.id).firstOrNull;
    final currentQty = existingItem?.quantity ?? 0;

    if (part.stockQuantity <= 0) {
      AppSnackBar.showError(context, 'Bu ürünün stoğu TÜKENDİ!');
    } else if (currentQty < part.stockQuantity) {
      ref.read(cartProvider.notifier).addToCart(part);
      _clearSearchField();
    } else {
      AppSnackBar.showWarning(context, 'Stokta daha fazla ürün yok!');
    }
  }

  void _updateCartItem(String partId, int currentQty, int delta, int maxStock) {
    final newQty = currentQty + delta;
    if (newQty > maxStock) {
      AppSnackBar.showWarning(context, 'Stokta daha fazla ürün yok!');
      return;
    }
    ref.read(cartProvider.notifier).updateQuantity(partId, newQty);
  }

  void _showCheckoutDialog() {
    FocusScope.of(context).unfocus(); 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final customersAsync = ref.watch(customerProvider);

            if (_selectedCustomerId == null && _selectedPaymentMethod == 'Açık Hesap') {
              _selectedPaymentMethod = 'Nakit';
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Satışı Tamamla',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.corporateNavy),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    customersAsync.when(
                      data: (customers) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: _selectedCustomerId,
                                decoration: InputDecoration(
                                  labelText: 'Kayıtlı Müşteri (Cari)',
                                  labelStyle: const TextStyle(color: AppColors.textDark),
                                  prefixIcon: const Icon(Icons.people_alt_rounded, color: AppColors.corporateNavy),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.corporateNavy),
                                  ),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('Peşin Müşteri', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...customers.map((c) => DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(
                                          '${c.name} ${c.companyName != null && c.companyName!.isNotEmpty ? "(${c.companyName})" : ""}',
                                        ),
                                      ))
                                ],
                                onChanged: (val) {
                                  setDialogState(() {
                                    _selectedCustomerId = val;
                                    if (val != null) {
                                      _selectedPaymentMethod = 'Açık Hesap';
                                    } else {
                                      _selectedPaymentMethod = 'Nakit';
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.corporateNavy,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                                onPressed: () {
                                  _showQuickAddCustomerDialog(setDialogState);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(color: AppColors.corporateNavy),
                      error: (err, stack) => const Text('Müşteriler Yüklenemedi'),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(_buyerNameCtrl, 'Şoför / Teslim Alan', Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    _buildDialogTextField(_vehiclePlateCtrl, 'Araç Plakası', Icons.pin_drop_outlined),
                    const SizedBox(height: 12),
                    _buildDialogTextField(_notesCtrl, 'Satış Notu', Icons.note_alt_outlined),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedPaymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Ödeme Yöntemi',
                        labelStyle: const TextStyle(color: AppColors.textDark),
                        prefixIcon: const Icon(Icons.payment_rounded, color: AppColors.corporateNavy),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.corporateNavy),
                        ),
                        isDense: true,
                      ),
                      items: [
                        'Nakit', 
                        'Kredi Kartı', 
                        'Havale', 
                        if (_selectedCustomerId != null) 'Açık Hesap'
                      ].map((String method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(
                            method,
                            style: TextStyle(
                              color: method == 'Açık Hesap' ? AppColors.dangerRed : AppColors.textDark,
                              fontWeight: method == 'Açık Hesap' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => _selectedPaymentMethod = val);
                      },
                    ),

                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'Açık Hesap'
                            ? AppColors.dangerRed.withValues(alpha: 0.08)
                            : AppColors.successGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'Açık Hesap'
                              ? AppColors.dangerRed.withValues(alpha: 0.3)
                              : AppColors.successGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedPaymentMethod == 'Açık Hesap' ? 'VERESİYE YAZILACAK:' : 'TAHSİLAT:', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedPaymentMethod == 'Açık Hesap'
                                    ? AppColors.dangerRed
                                    : AppColors.successGreen,
                              ),
                            ),
                          ),
                          Text(
                            '₺${_totalPrice.toStringAsFixed(2)}', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: _selectedPaymentMethod == 'Açık Hesap'
                                  ? AppColors.dangerRed
                                  : AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İPTAL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _processSale();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedPaymentMethod == 'Açık Hesap'
                        ? AppColors.dangerRed
                        : AppColors.successGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _selectedPaymentMethod == 'Açık Hesap' ? 'HESABA YAZ' : 'ONAYLA',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showQuickAddCustomerDialog(StateSetter setDialogState) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hızlı Cari Ekle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.corporateNavy),
        ),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Firma / Usta Adı',
            labelStyle: const TextStyle(color: AppColors.textDark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.corporateNavy),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.corporateNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final newCust = Customer(name: nameCtrl.text.trim());
              await ref.read(customerProvider.notifier).addCustomer(newCust);
              
              final updatedCustomers = ref.read(customerProvider).value ?? [];
              final created = updatedCustomers.firstWhere(
                (c) => c.name.toLowerCase() == nameCtrl.text.trim().toLowerCase(),
                orElse: () => newCust,
              );
              
              setDialogState(() {
                if (created.id != null) {
                  _selectedCustomerId = created.id;
                  _selectedPaymentMethod = 'Açık Hesap';
                }
              });
              AppSnackBar.showSuccess(context, 'Müşteri eklendi ve seçildi.');
            },
            child: const Text('Ekle'),
          )
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textDark),
        prefixIcon: Icon(icon, size: 20, color: AppColors.corporateNavy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.corporateNavy),
        ),
        isDense: true,
      ),
    );
  }

  Future<void> _processSale() async {
    setState(() => _isLoading = true);
    final cart = ref.read(cartProvider);

    try {
      final List<SaleRecord> records = cart.map((item) {
        final brandPrefix = (item.part.brand != null && item.part.brand!.isNotEmpty)
            ? "${item.part.brand} - " : "";
        return SaleRecord(
          partId: item.part.id!,
          partName: '$brandPrefix${item.part.name}',
          quantity: item.quantity,
          unitPrice: item.part.sellPrice,
          totalPrice: item.part.sellPrice * item.quantity,
          buyerName: _buyerNameCtrl.text.trim(),
          companyName: _companyNameCtrl.text.trim(),
          vehiclePlate: _vehiclePlateCtrl.text.trim(),
          vehicleBrandModel: _vehicleBrandModelCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          paymentMethod: _selectedPaymentMethod,
          customerId: _selectedCustomerId,
        );
      }).toList();

      await ref.read(sparePartsProvider.notifier).recordBulkSale(records);

      if (mounted) {
        // Satış başarılıysa Global Sepeti Boşalt
        ref.read(cartProvider.notifier).clearCart();
        
        setState(() {
          _buyerNameCtrl.clear();
          _companyNameCtrl.clear();
          _vehiclePlateCtrl.clear();
          _vehicleBrandModelCtrl.clear();
          _notesCtrl.clear();
          _selectedPaymentMethod = 'Nakit';
          _selectedCustomerId = null;
          _clearSearchField(); 
        });

        if (Navigator.canPop(context)) Navigator.pop(context);
        AppSnackBar.showSuccess(context, 'Satış başarıyla tamamlandı!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Satış tamamlanamadı: ${DioErrorHandler.getErrorMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partsAsync = ref.watch(sparePartsProvider);
    final cart = ref.watch(cartProvider); // GLOBAL SEPETİ DİNLİYORUZ
    final userRole = ref.watch(userRoleProvider).value;
    final isAdmin = userRole == 'admin' || userRole == 'patron';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Hızlı Satış (Sepet)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.corporateNavy, size: 26),
            onPressed: _scanBarcodeWithCamera,
            tooltip: 'Kamera ile Okut',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: partsAsync.when(
              data: (parts) {
                return Autocomplete<SparePart>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<SparePart>.empty();
                    }
                    return parts.where((SparePart part) {
                      final query = textEditingValue.text.toLowerCase();
                      return part.name.toLowerCase().contains(query) ||
                          (part.barcode?.contains(query) ?? false) ||
                          (part.oemCode?.toLowerCase().contains(query) ?? false) ||
                          (part.brand?.toLowerCase().contains(query) ?? false);
                    });
                  },
                  displayStringForOption: (SparePart option) => option.name,
                  onSelected: (SparePart selection) {
                    _addToCart(selection);
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    _searchFieldController = textEditingController;

                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Parça, Marka veya OEM yazın...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.corporateNavy),
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 250,
                            maxWidth: MediaQuery.of(context).size.width - 32,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              final isOutOfStock = option.stockQuantity <= 0;
                              return ListTile(
                                leading: const Icon(Icons.settings_suggest_rounded, color: AppColors.corporateNavy),
                                title: Text(
                                  option.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOutOfStock ? Colors.grey : AppColors.corporateNavy,
                                  ),
                                ),
                                subtitle: Text('₺${option.sellPrice} - Stok: ${option.stockQuantity}'),
                                trailing: isOutOfStock
                                    ? const Text('TÜKENDİ', style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold))
                                    : const Icon(Icons.add_shopping_cart_rounded, color: AppColors.energeticOrange),
                                onTap: isOutOfStock ? null : () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: LinearProgressIndicator(color: AppColors.corporateNavy)),
              error: (err, stack) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.energeticOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.energeticOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: AppColors.energeticOrange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Katalog senkronize edilemedi: ${DioErrorHandler.getErrorMessage(err)}',
                        style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref.refresh(sparePartsProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Yenile'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.corporateNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Sepetiniz Boş\nYukarıdan arayın veya barkod okutun',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.part.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.corporateNavy,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Birim: ₺${item.part.sellPrice} | Toplam: ₺${(item.part.sellPrice * item.quantity).toStringAsFixed(2)}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.corporateNavy.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_rounded, color: AppColors.dangerRed),
                                      onPressed: () => _updateCartItem(item.part.id!, item.quantity, -1, item.part.stockQuantity),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.corporateNavy,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_rounded, color: AppColors.corporateNavy),
                                      onPressed: () => _updateCartItem(item.part.id!, item.quantity, 1, item.part.stockQuantity),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.corporateNavy.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin && cart.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Kâr (Tahmini)',
                            style: TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₺${_netProfit.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.corporateNavy, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GENEL TOPLAM', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
                          Text(
                            '₺${_totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: (cart.isEmpty || _isLoading) ? null : _showCheckoutDialog,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.payments_outlined),
                        label: const Text('ÖDEME AL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}