import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/purchase_service.dart';
import 'package:flutter/material.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import 'app_colors.dart';

class PaymentPlanScreen extends StatefulWidget {
  const PaymentPlanScreen({super.key});

  @override
  State<PaymentPlanScreen> createState() => _PaymentPlanScreenState();
}

class _PaymentPlanScreenState extends State<PaymentPlanScreen> {
  bool _yearly = false;
  bool _plusSelected = true;
  final PurchaseService _purchaseService = PurchaseService.instance;

  bool _loadingStore = true;
  String? _purchaseMessage;

  @override
  void initState() {
    super.initState();
    _initializePurchases();
  }

  Future<void> _initializePurchases() async {
    await _purchaseService.initialize(
      onChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
      onVerifiedPurchase: _handleVerifiedPurchase,
    );

    if (mounted) {
      setState(() {
        _loadingStore = false;
      });
    }
  }

  Future<void> _handleVerifiedPurchase(PurchaseDetails purchase) async {
    if (!mounted) return;

    setState(() {
      _purchaseMessage = 'Plus subscription activated!';
    });
  }

  ProductDetails? get _selectedProduct {
    final productId = _yearly
        ? PurchaseService.yearlyProductId
        : PurchaseService.monthlyProductId;

    return _purchaseService.productFor(productId);
  }

  String get _plusPrice {
    final product = _selectedProduct;

    if (product == null) {
      return _yearly ? 'Yearly' : 'Monthly';
    }

    return _yearly ? '${product.price}/year' : '${product.price}/month';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'Payment Plan', showBackButton: true),
      body: FigmaGradientBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              const _PlanIdentity(),
              const SizedBox(height: 22),
              const Text(
                'Choose a Plan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Get the protection you need.',
                style: TextStyle(fontSize: 15, color: AppColors.text),
              ),
              const SizedBox(height: 18),
              _BillingToggle(
                yearly: _yearly,
                onChanged: (value) => setState(() => _yearly = value),
              ),
              const SizedBox(height: 14),
              _PlanCard(
                name: 'Free',
                price: '\$0/month',
                selected: !_plusSelected,
                features: const ['Manual Scans', 'Basic Results'],
                onTap: () => setState(() => _plusSelected = false),
              ),
              const SizedBox(height: 14),
              _PlanCard(
                name: 'Plus',
                price: _plusPrice,
                selected: _plusSelected,
                features: const [
                  'Everything in Free',
                  'Live Email Monitoring',
                  'Full AI Chat Access',
                  'Family/Social Features',
                  'Priority Support',
                ],
                onTap: () => setState(() => _plusSelected = true),
              ),
              const SizedBox(height: 20),

              if (_loadingStore)
                const Center(child: CircularProgressIndicator())
              else if (_plusSelected) ...[
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        _purchaseService.purchasePending ||
                            _selectedProduct == null
                        ? null
                        : () async {
                            await _purchaseService.purchase(_selectedProduct!);
                          },
                    child: _purchaseService.purchasePending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _yearly
                                ? 'Start Plus Yearly'
                                : 'Start Plus Monthly',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: () async {
                    await _purchaseService.restorePurchases();
                  },
                  child: const Text('Restore Purchases'),
                ),
              ],

              if (_purchaseMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _purchaseMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              if (_purchaseService.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _purchaseService.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanIdentity extends StatelessWidget {
  const _PlanIdentity();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF101D27),
            border: Border.all(color: AppColors.primaryBlue, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 38,
            color: AppColors.lightCyan,
          ),
        ),
        const SizedBox(width: 16),
        const Text(
          'Your Shield\nAgainst Scams',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final bool yearly;
  final ValueChanged<bool> onChanged;

  const _BillingToggle({required this.yearly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleOption(
            label: 'Monthly',
            selected: !yearly,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ToggleOption(
            label: 'Yearly',
            selected: yearly,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xB8BFE9D4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Save 20%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xB3A9DCF0) : const Color(0xB8FDFCF9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x300B718E),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final bool selected;
  final List<String> features;
  final VoidCallback onTap;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.selected,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xBFE0F6FC) : const Color(0xD9FDFCF9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white70, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x300B718E),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$name\n$price',
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                _SelectionCircle(selected: selected),
              ],
            ),
            const SizedBox(height: 10),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check,
                      size: 21,
                      color: AppColors.accentGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  final bool selected;

  const _SelectionCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primaryBlue : Colors.transparent,
        border: Border.all(color: AppColors.text, width: 2),
      ),
    );
  }
}
