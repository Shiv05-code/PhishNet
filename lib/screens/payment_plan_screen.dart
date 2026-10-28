import '../services/payment_backend_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/purchase_service.dart';
import 'package:flutter/material.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import 'app_colors.dart';
import 'package:flutter/foundation.dart';
import '../services/subscription_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_typography.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/aws_subscription_service.dart';

class PaymentPlanScreen extends StatefulWidget {
  const PaymentPlanScreen({super.key});

  @override
  State<PaymentPlanScreen> createState() => _PaymentPlanScreenState();
}

class _PaymentPlanScreenState extends State<PaymentPlanScreen> {
  bool _yearly = false;
  bool _hasPlus = false;
  StreamSubscription<Map<String, dynamic>?>? _plusListener;
  final PurchaseService _purchaseService = PurchaseService.instance;

  String? _purchaseMessage;

  @override
  void initState() {
    super.initState();
    if (_isLoggedIn) {
      _initializePurchases();
      _listenForPlus();
    }
  }

  @override
  void dispose() {
    _plusListener?.cancel();
    super.dispose();
  }

  void _listenForPlus() {
    _plusListener?.cancel();

    _plusListener = SubscriptionService.instance
        .watchEffectiveSubscription()
        .listen(
          (subscription) {
            if (!mounted) return;

            final plan = subscription?['plan'];
            final status = subscription?['status'];
            final environment = subscription?['environment'];
            final expiresAt = subscription?['expiresAt'];

            const useEmulators = bool.fromEnvironment(
              'USE_FIREBASE_EMULATORS',
              defaultValue: false,
            );

            final validEnvironment =
                environment == 'production' ||
                (kDebugMode && useEmulators && environment == 'local_test') ||
                (SubscriptionService.allowSandboxSubscriptions &&
                    environment == 'sandbox');

            final notExpired =
                expiresAt is Timestamp &&
                expiresAt.toDate().isAfter(DateTime.now());

            final hasPlus =
                plan == 'plus' &&
                status == 'active' &&
                validEnvironment &&
                notExpired;

            setState(() {
              _hasPlus = hasPlus;
            });

            debugPrint('SUBSCRIPTION UPDATE: Plan = $plan');
            debugPrint('SUBSCRIPTION UPDATE: Status = $status');
            debugPrint('SUBSCRIPTION UPDATE: Environment = $environment');
            debugPrint('SUBSCRIPTION UPDATE: Has Plus = $hasPlus');
          },
          onError: (Object error) {
            debugPrint('SUBSCRIPTION LISTENER ERROR: $error');
          },
        );
  }

  Future<void> _initializePurchases() async {
    try {
      await _purchaseService
          .initialize(
            onChanged: () {
              if (mounted) {
                setState(() {});
              }
            },
            onVerifiedPurchase: _handleVerifiedPurchase,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('STOREKIT DEBUG: Initialization failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to connect to the App Store. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleVerifiedPurchase(PurchaseDetails purchase) async {
    final transactionId = purchase.purchaseID;

    if (transactionId == null || transactionId.isEmpty) {
      if (mounted) {
        setState(() {
          _purchaseMessage =
              'Unable to verify this purchase. Missing transaction ID.';
        });
      }
      return;
    }

    try {
      final result = await AwsSubscriptionService.instance.verifyPurchase(
        transactionId,
      );

      if (!mounted) return;

      final entitlementGranted = result['entitlementGranted'] == true;

      setState(() {
        _purchaseMessage = entitlementGranted
            ? 'Subscription verified. Updating your plan...'
            : 'Purchase received. Subscription activation is pending.';
      });
    } catch (e) {
      debugPrint('AWS SUBSCRIPTION VERIFICATION ERROR: ${e.runtimeType}');

      if (!mounted) return;

      setState(() {
        _purchaseMessage =
            'Unable to verify your subscription. Please try again.';
      });
    }
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

  Future<void> _testDemoUpgrade() async {
    try {
      final result = await PaymentBackendService.instance
          .demoUpgradeSubscription('com.phishnet.plus.monthly');

      debugPrint('DEMO UPGRADE RESULT: $result');
    } catch (e) {
      debugPrint('DEMO UPGRADE ERROR: $e');
    }
  }

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;
  bool get _onPlus => _hasPlus;
  bool get _onFreeNoAccount => !_isLoggedIn;
  bool get _onFreeWithAccount => _isLoggedIn && !_onPlus;

  Future<void> _goToLogin() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _goToSignup() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  String get _plusActionLabel {
    if (!_isLoggedIn) return 'Create an Account to Upgrade';
    return _yearly ? 'Start Plus Yearly' : 'Start Plus Monthly';
  }

  Future<void> _onPlusPressed() async {
    if (!_isLoggedIn) {
      _goToSignup();
      return;
    }

    final product = _selectedProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plans are still loading. Try again.')),
      );
      return;
    }
    if (_purchaseService.purchasePending) return;
    await _purchaseService.purchase(product);
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
                  fontSize: AppTypography.title,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isLoggedIn
                    ? 'Get the protection you need.'
                    : "You're browsing as a guest. Create a free account to unlock more.",
                style: TextStyle(fontSize: 15, color: AppColors.text),
              ),
              const SizedBox(height: 18),
              if (_isLoggedIn)
                StreamBuilder<Map<String, dynamic>?>(
                  stream: SubscriptionService.instance
                      .watchEffectiveSubscription(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Unable to load subscription status.');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final subscription = snapshot.data;

                    final plan = subscription?['plan'] ?? 'free';
                    final status = subscription?['status'] ?? 'inactive';
                    final environment = subscription?['environment'] ?? 'none';
                    final expiresAt = subscription?['expiresAt'];

                    final isExpired =
                        expiresAt is Timestamp &&
                        !expiresAt.toDate().isAfter(DateTime.now());

                    final isDemo =
                        environment == 'local_test' || environment == 'sandbox';

                    final isActivePlus =
                        plan == 'plus' &&
                        status == 'active' &&
                        expiresAt is Timestamp &&
                        !isExpired &&
                        (environment == 'production' ||
                            (kDebugMode &&
                                const bool.fromEnvironment(
                                  'USE_FIREBASE_EMULATORS',
                                ) &&
                                environment == 'local_test') ||
                            (SubscriptionService.allowSandboxSubscriptions &&
                                environment == 'sandbox'));

                    final displayPlan = isActivePlus ? 'Plus' : 'Free';

                    final displayStatus = isExpired
                        ? 'Expired'
                        : isActivePlus
                        ? 'Active'
                        : 'Inactive';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Plan: $displayPlan'
                            '${isActivePlus && isDemo ? (environment == "sandbox" ? " (Sandbox)" : " (Demo)") : ""}',
                            style: const TextStyle(
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),
                          Text(
                            'Status: $displayStatus',
                            style: const TextStyle(
                              fontSize: AppTypography.label,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              _BillingToggle(
                yearly: _yearly,
                onChanged: (value) => setState(() => _yearly = value),
              ),
              const SizedBox(height: 14),
              if (!_isLoggedIn) ...[
                _PlanCard(
                  name: 'Free: No Account',
                  price: '\$0/month',
                  isCurrent: _onFreeNoAccount,
                  features: const ['Manual Scans', 'Basic Results'],
                ),
              ],
              const SizedBox(height: 14),
              _PlanCard(
                name: 'Free: With Account',
                price: '\$0/month',
                isCurrent: _onFreeWithAccount,
                features: const [
                  'Everything in Free: No Account',
                  'Limited AI Chat Access',
                  'Priority Support',
                ],
                actionLabel: _isLoggedIn ? null : 'Log In or Sign Up',
                onAction: _isLoggedIn ? null : _goToLogin,
              ),
              const SizedBox(height: 14),
              _PlanCard(
                name: 'Plus',
                price: _plusPrice,
                isCurrent: _onPlus,
                features: const [
                  'Everything in Free',
                  'Live Email Monitoring',
                  'Full AI Chat Access',
                  'Family/Social Features',
                  'Priority Support',
                ],
                actionLabel: _onPlus ? null : _plusActionLabel,
                onAction: _onPlus ? null : _onPlusPressed,
              ),
              const SizedBox(height: 20),

              if (_isLoggedIn)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await _purchaseService.restorePurchases();
                    },
                    child: const Text('Restore Purchases'),
                  ),
                ),

              if (_isLoggedIn &&
                  kDebugMode &&
                  const bool.fromEnvironment('USE_FIREBASE_EMULATORS'))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton(
                    onPressed: _testDemoUpgrade,
                    child: const Text('TEST: Upgrade to Plus'),
                  ),
                ),
              if (_purchaseMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _purchaseMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              if (_purchaseService.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _purchaseService.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: AppTypography.caption,
                  ),
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
            fontSize: AppTypography.label,
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
              'Save 16%',
              style: TextStyle(
                fontSize: AppTypography.caption,
                fontWeight: FontWeight.w700,
              ),
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
          style: const TextStyle(
            fontSize: AppTypography.caption,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final bool isCurrent;
  final bool highlighted;
  final List<String> features;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.isCurrent,
    required this.features,
    this.actionLabel,
    this.onAction,
  }) : highlighted = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
      decoration: BoxDecoration(
        color: isCurrent || highlighted
            ? const Color(0xBFE0F6FC)
            : const Color(0xD9FDFCF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? AppColors.primaryBlue : Colors.white70,
          width: isCurrent ? 2 : 1.2,
        ),
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
              if (isCurrent) const _CurrentPlanChip(),
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentPlanChip extends StatelessWidget {
  const _CurrentPlanChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Current Plan',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
