import '../conditions/condition.dart';
import '../core/json_utils.dart';
import '../effects/effect.dart';

class ShopCategory {
  const ShopCategory._();

  static const phone = 'phone';
  static const gadget = 'gadget';
  static const vehicle = 'vehicle';
  static const fashion = 'fashion';
  static const property = 'property';
  static const subscription = 'subscription';

  static const all = [phone, gadget, vehicle, fashion, property, subscription];

  static const labels = {
    phone: 'Phones',
    gadget: 'Gadgets',
    vehicle: 'Vehicles',
    fashion: 'Fashion & jewellery',
    property: 'Property',
    subscription: 'Memberships',
  };
}

/// Something the player can buy: a phone, a car, a flat, a gym membership.
///
/// Ownership is persistent: items cost upkeep every month, lose (or gain)
/// value over time, and can be sold. Behaviour beyond that is declarative
/// ([onBuy], [monthlyEffects]) so new items need no engine changes.
class ShopItem {
  ShopItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.description,
    required this.price,
    required this.monthlyUpkeep,
    required this.upkeepLabel,
    required this.annualDepreciationPct,
    required this.slot,
    required this.loanProductId,
    required this.downPaymentPct,
    required this.commuteHoursSaved,
    required this.creatorQuality,
    required this.requires,
    required this.onBuy,
    required this.onSell,
    required this.monthlyEffects,
    required this.perks,
  });

  factory ShopItem.fromJson(Json j) => ShopItem(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        brand: j['brand'] as String? ?? '',
        category: req<String>(j, 'category'),
        description: req<String>(j, 'description'),
        price: req<num>(j, 'price').toInt(),
        monthlyUpkeep: optInt(j, 'monthlyUpkeep', 0),
        upkeepLabel: j['upkeepLabel'] as String? ?? 'Upkeep',
        annualDepreciationPct: optNum(j, 'annualDepreciationPct', 15),
        slot: j['slot'] as String?,
        loanProductId: j['loanProduct'] as String?,
        downPaymentPct: optNum(j, 'downPaymentPct', 0.2),
        commuteHoursSaved: optNum(j, 'commuteHoursSaved', 0),
        creatorQuality: optNum(j, 'creatorQuality', 0),
        requires: j['requires'] == null ? Condition.always : Condition.fromJson((j['requires'] as Map).cast()),
        onBuy: jsonList(j['onBuy']).map(Effect.fromJson).toList(),
        onSell: jsonList(j['onSell']).map(Effect.fromJson).toList(),
        monthlyEffects: jsonList(j['monthlyEffects']).map(Effect.fromJson).toList(),
        perks: stringList(j['perks']),
      );

  final String id;
  final String name;

  /// Fictional maker, shown on the shop card.
  final String brand;
  final String category;
  final String description;
  final int price;
  final int monthlyUpkeep;

  /// Ledger label for the upkeep ("Fuel & insurance", "Membership").
  final String upkeepLabel;

  /// Yearly loss of value in percent. Negative values appreciate (gold,
  /// property).
  final double annualDepreciationPct;

  /// Items sharing a slot replace each other: buying a new phone trades in
  /// the old one. Null means the item can sit alongside anything.
  final String? slot;

  /// Loan product that can finance this purchase, if any.
  final String? loanProductId;

  /// Share of the price paid upfront when financing (0..1).
  final double downPaymentPct;

  /// Weekly commute hours a vehicle saves.
  final double commuteHoursSaved;

  /// 0..1 contribution to video production quality for creators.
  final double creatorQuality;
  final Condition requires;
  final List<Effect> onBuy;
  final List<Effect> onSell;

  /// Applied every month while owned.
  final List<Effect> monthlyEffects;

  /// Short player-facing benefit lines for the shop card.
  final List<String> perks;

  bool get financeable => loanProductId != null;

  /// Subscriptions are cancelled, not sold.
  bool get isSubscription => category == ShopCategory.subscription;
}

class OwnedItem {
  OwnedItem({
    required this.uid,
    required this.itemId,
    required this.boughtDay,
    required this.pricePaid,
    this.loanId,
  });

  factory OwnedItem.fromJson(Json j) => OwnedItem(
        uid: j['uid'] as String,
        itemId: j['itemId'] as String,
        boughtDay: j['boughtDay'] as int,
        pricePaid: j['pricePaid'] as int,
        loanId: j['loanId'] as String?,
      );

  final String uid;
  final String itemId;
  final int boughtDay;
  final int pricePaid;

  /// The loan that financed the purchase; it must be settled on sale.
  final String? loanId;

  Json toJson() => {
        'uid': uid,
        'itemId': itemId,
        'boughtDay': boughtDay,
        'pricePaid': pricePaid,
        'loanId': loanId,
      };
}
