import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Starts Stripe Checkout via the `create-checkout-session` Edge Function.
/// Never send card numbers or secret keys from the client.
abstract final class StripeCheckout {
  static Future<void> start({
    required String kind,
    int? quantity,
    String? notes,
  }) async {
    final origin = kIsWeb ? Uri.base.origin : 'http://localhost:8091';
    final response = await Supabase.instance.client.functions.invoke(
      'create-checkout-session',
      body: {
        'kind': kind,
        ?'quantity': quantity,
        'notes': ?notes?.trim(),
        'success_origin': origin,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Checkout did not return a payment URL');
    }
    final map = Map<String, dynamic>.from(data);
    final err = map['error']?.toString();
    if (err != null && err.isNotEmpty) {
      throw Exception(err);
    }
    final url = map['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('Stripe Checkout URL missing — check server secrets');
    }

    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Could not open Stripe Checkout');
    }
  }
}
