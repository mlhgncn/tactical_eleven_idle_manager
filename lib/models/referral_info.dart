class ReferralInfo {
  final String? referralCode;
  final int successfulReferrals;

  const ReferralInfo({this.referralCode, required this.successfulReferrals});

  factory ReferralInfo.fromMap(Map<String, dynamic> map) {
    return ReferralInfo(
      referralCode: map['referral_code'] as String?,
      successfulReferrals: (map['successful_referrals'] as num?)?.toInt() ?? 0,
    );
  }
}
